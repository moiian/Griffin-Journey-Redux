-- Griffin Journey Redux: callbacks
return function(ctx)
local _ENV=ctx
local function phase(fn)
    return function(...)
        local previous=validation_epoch
        validation_epoch={}
        local ok,err=pcall(fn,...)
        validation_epoch=previous
        if not ok then error(err) end
    end
end
re.on_frame(phase(function()
    if not alive then return end
    menu.tick_photo_camera()
    menu.tick_save()
    tick_cleanup_departures()
    shop_item:tick()
    anti_jitter:tick()
    local c = core()
    if not c then return end
    if menu.gameplay_paused() then
        tick_driver() -- Keep pause timing current even when behavior updates stop.
        summon:tick()
        flush()
        return
    end
    for i=#state.spawns,1,-1 do
        local r = state.spawns[i]
        if r.owner ~= c.properties.player then r.friend = false end
        if r.deleted then table.remove(state.spawns,i)
        elseif r.delete_requested then delete_one(r)
        elseif r.result and r.result.go and r.result.chara and not r.ready then
            r.ready = true
            run_once(function()
                if not alive or r.deleted or r.delete_requested then return end
                if core() and menu.gameplay_paused() then r.ready=false;return end
                local ok, err = pcall(function()
                    install_hooks()
                    local ch = validate_spawn(r)
                    local info = ch:call("get_GenerateInfo()")
                    local container = info and info:call("get_Container()")
                    local data = container and container._CharaInfo
                    assert(data, "Spawn ThinkStop interface unavailable")
                    local before=data:call("get_IsThinkStop()")
                    if before then data:call("set_IsThinkStop(System.Boolean)",false) end
                    r.spawn_think_stop=data:call("get_IsThinkStop()")
                    if event then event("spawn_think_stop",{before=before,after=r.spawn_think_stop}) end
                    status = "狮鹫已生成并设为队伍友方，可以开始驾驶。"
                    if event then event("spawn_ready", "Friend bound; spawn ThinkStop released when true") end
                    set_skip_think(true)
                    if r.summon_facing then
                        local facing_ok,facing_err=pcall(apply_spawn_facing,r,ch)
                        if not facing_ok then failed("狮鹫已生成，但初始朝向设置失败",facing_err) end
                    end
                end)
                if not ok then failed("狮鹫初始化失败",err) end
            end)
        end
    end
end))
re.on_application_entry("UpdateHID",phase(function()
    if not alive then return end
    local ok,result=pcall(read_pad)
    if not ok then
        controls.hold_actions({},true)
        if core() and menu.gameplay_paused() then return end
        if active then stop_driver("输入读取失败");failed("输入读取失败",result) end
        return
    end
    input=result
    if core() and menu.gameplay_paused() then
        controls.hold_actions(result,true)
        if active then active.previous_buttons=result.buttons end
        return -- menu navigation must not invoke gameplay hotkeys
    end
    if active and active.menu_paused then
        controls.hold_actions(result,true)
        active.previous_buttons=result.buttons
        return -- seed menu-held inputs before the first resumed behavior update
    end
    local hold_action=controls.hold_actions(result,not core() or controls.capture or controls.release_gate)
    if controls.capture or controls.release_gate then return end
    if hold_action then
        if hold_action=="start" then hotkey_start_driver() else menu.stop() end
        return
    end
    for _,name in ipairs({"delete","spawn","preset_next"}) do
        if result.edges[name] then
            if name=="spawn" then spawn()
            elseif name=="delete" then menu.delete()
            elseif name=="preset_next" then menu.next_preset() end
            break
        end
    end
end))

re.on_pre_application_entry("UpdateBehavior",phase(function()
    if not alive then return end
    menu.tick_photo_camera()
    menu.apply_edits()
    consumables:tick()
    spawn_watch:tick()
    tick_exit_landing()
    passengers.frame=passengers.frame+1
    if menu.apply_pending_preset then menu.apply_pending_preset() end
    passengers.refresh();tick_skip_think()
    if driver_extension then driver_extension:tick(active) end
    tick_driver();passengers.tick_held();tick_camera_follow()

end))
re.on_application_entry("UpdateBehavior",phase(function()
    summon:tick()
    hover_motion:after_behavior()
end))
menu.player_visual_pre=function()
    local d=active
    if not d or not alive or not d.bones_applied or not menu.visual_allowed() then return end
    local ok,err=pcall(function()
        assert(owned_player(d,true),"Player binding changed")
        restore_bone(d)
        passengers.orient(d,passengers.player_config())
    end)
    if not ok then menu.visual_error("骨骼恢复失败",err) end
end
menu.player_visual_post=function()
    local d,c=active,core()
    if not d or not alive or not menu.visual_allowed() or not d.anchor_target then return end
    if d.anchor_mode=="full" or not d.neutral_anchor then return end
    local ok,err=pcall(function()
        assert(owned_player(d,true),"Player binding changed")
        restore_bone(d)
        local actor=vector(d.transform:call("get_Position()"))
        local seat,head
        if d.anchor_mode=="rider" then seat,head=rider_seat(d) end
        local items={}
        -- Same capture/write/restore ordering as the user-validated Hip stick mode.
        for _,spec in ipairs({{joint=d.root_joint,key="root_bone"},{joint=d.hip_joint,key="hip"}}) do
            local joint=spec.joint
            if joint and joint:get_Valid() then
                local original=vector(joint:call("get_Position()"))
                local anchor=d.neutral_anchor
                if seat and spec.key=="hip" then anchor=seat end
                local target={x=anchor.x+original.x-actor.x,y=anchor.y+original.y-actor.y,z=anchor.z+original.z-actor.z}
                items[#items+1]={joint=joint,key=spec.key,original=original,written=target}
            end
        end
        d.bones_applied=items -- retain recovery if a later native setter fails
        for _,a in ipairs(items) do
            a.joint:call("set_Position(via.vec3)",Vector3f.new(a.written.x,a.written.y,a.written.z))
            if d.anchor_plan then d.anchor_plan[a.key]=a.written end
        end

    end)
    if not ok then menu.visual_error("座位显示更新失败",err) end
end
menu.visual_error=function(label,err)
    -- A paused render callback must not release actors or invoke gameplay cleanup.
    if menu.gameplay_paused() or menu.rendering_visual then
        local message=label..": "..tostring(err)
        if menu.visual_last_error~=message then menu.visual_last_error=message;failed(label,err) end
    else stop_driver(label);failed(label,err) end
end
re.on_pre_application_entry("UpdateJointExpression",phase(function()
    passengers.pre();menu.player_visual_pre()
end))
re.on_application_entry("UpdateJointExpression",phase(function()

    passengers.post();menu.player_visual_post()

end))
re.on_pre_application_entry("PrepareRendering",phase(function()

    menu.tick_photo_camera()
    if not menu.visual_allowed() and not passengers.visual_allowed() then return end
    -- Menu transitions can replace the pose before NickCore reports pause. Keep
    -- this fallback active every rendered frame, using the same Hip restore path.
    -- No physics, AI, input or FSM updates here; normal menu preset changes wait.
    menu.apply_pending_preset()
    menu.apply_edits(true)
    menu.rendering_visual=true
    passengers.pre();menu.player_visual_pre()
    passengers.post();menu.player_visual_post()
    menu.rendering_visual=false

end))
re.on_application_entry("PrepareRendering",phase(function()

    if not core() or menu.gameplay_paused() then return end
    local d = active
    if not d or d.camera_failed then return end
    local ok, err = pcall(function()
        local manager, camera = sdk.get_managed_singleton("app.CameraManager"), sdk.get_primary_camera()
        assert(manager and camera, "Camera unavailable")
        if camera_state and (camera_state.manager ~= manager or camera_state.camera ~= camera) then
            restore_camera(); d.camera_failed = true; return
        end
        if not camera_state then
            local distance,fov = manager._DistanceOffset,camera:call("get_FOV")
            assert(finite(distance) and finite(fov), "Camera values unavailable")
            camera_state = {manager=manager,camera=camera,distance=distance,fov=fov,
                last_distance=distance,last_fov=fov}
        end
        camera_state.last_distance=settings.distance; camera_state.last_fov=settings.fov
        if manager._DistanceOffset~=settings.distance then manager._DistanceOffset=settings.distance end
        if camera:call("get_FOV")~=settings.fov then camera:call("set_FOV",settings.fov) end
    end)
    if not ok then restore_camera(); d.camera_failed=true; if event then event("camera_error",tostring(err)) end end
end))
-- Runtime bridge: only retained Beta instances; never resolve by character ID/address.
bridge = {}
external_serial = 0
function bridge.get_instance()
    if not alive or state.generation ~= generation then return nil end
    local r = active and active.spawn or state.spawns[#state.spawns]
    if r and r.ready and not r.delete_requested then return r.result end
end
-- Public item-use API: snapshot the current menu settings through the same request path.
function bridge.summon_performance()
    if not alive or state.generation~=generation then return false,"脚本已重载" end
    return summon:request()
end
-- Only native item-use callers supply the exact current player; the menu API stays unchanged.
function bridge.summon_performance_from_item(user)
    local c=core()
    if not alive or state.generation~=generation then return false,"脚本已重载" end
    if not c or not user or user~=c.properties.player then return false,"召唤道具仅允许当前玩家使用" end
    local accepted,reason=summon:request(true)
    if accepted then summon.current.give_pizza=true end
    return accepted,reason
end
function bridge.dismiss_from_item(user) return consumables:request(user) end
function bridge.set_skip_think(enabled) return set_skip_think(enabled) end
function bridge.get_skip_think() return skip_think_enabled,skip_think_status end
function bridge.is_driving() return alive and (active ~= nil or state.recovery ~= nil or queued) end
function bridge.request_action(node, allow_cross, phase)
    if not bridge.get_instance() or type(node) ~= "string" or node == "" then return false, "Beta 实例尚未就绪" end
    if not allow_cross then
        local ch = bridge.get_instance().chara
        local flying, ground = ch:call("get_IsFlight()"), ch:call("get_IsGround()")
        if not (phase == "air" and flying or phase == "ground" and ground and not flying) then
            return false, "阶段不符；请开启跨阶段测试"
        end
    end
    external_serial = external_serial + 1
    local serial = external_serial
    if active then
        -- Replacing the intent cancels already queued requests. External actions also
        -- cancel automatic takeoff-to-hover; only a new controller press replaces them.
        hover_motion:release(active)
        active.mode = "external"
        active.external_control = true
        active.control_node = nil
        active.auto_hover = false
        set_intent(active, node, "external")
        if event then event("external_action_queued", node) end
    else
        local r = state.spawns[#state.spawns]
        run_once(function()
            if not alive or state.generation ~= generation or serial ~= external_serial or active
                or r.delete_requested or state.spawns[#state.spawns] ~= r then return end
            local ok, err = pcall(function()
                local ch = validate_spawn(r)
                local manager = ch:call("get_ActionManager()")
                assert(manager and manager:call("get_GameObject()") == r.result.go, "ActionManager mismatch")
                if event then event("action_request", {node=node, mode="external"}) end
                manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)", 10, node, 0)
                if event then event("action_returned", node) end
            end)
            if not ok then failed("实验工具动作请求失败", err) end
        end)
    end
    return true
end
_G.GriffinFlightBetaBridge = bridge
_G.GriffinJourneyReduxBridge = bridge

re.on_script_reset(phase(function()
    menu.flush_settings()
    shop_item:shutdown()
    summon:cancel("脚本重置")
    stop_driver("脚本重置",true)
    anti_jitter:shutdown()
    alive = false
    skip_think_enabled=false;skip_think_expected=nil;block_player_fall=false
    if rawget(_G, "GriffinFlightBetaBridge") == bridge then _G.GriffinFlightBetaBridge = nil end
    if rawget(_G,"GriffinJourneyReduxBridge")==bridge then _G.GriffinJourneyReduxBridge=nil end
    for _, r in ipairs(state.spawns) do r.friend = false; r.ready = false; r.destroy_queued = false end
    flush()
end))

-- Rebind only when this global table survives a same-Lua-state reload. A full Lua reset
-- may discard all references; never reconstruct native objects from addresses/IDs.
for _, r in ipairs(state.spawns) do r.friend = true; r.ready = false; r.destroy_queued = false end
end
