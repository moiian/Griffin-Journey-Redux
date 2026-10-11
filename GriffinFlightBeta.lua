-- Griffin Flight Beta 0.1.19. Requires installed NickCore + EnemySpawner + run_once.
-- Separate from GriffinMountExperiment; no OJR/LMD/NickCore files are changed.
local VERSION = "0.1.19-beta"
local state = rawget(_G, "GriffinFlightBetaState") or {spawns = {}}
_G.GriffinFlightBetaState = state
state.spawns = state.spawns or {}
local generation = {}
state.generation = generation
local alive, queued = true, false
local operation = nil
local active, camera_state = nil, nil
local camera_mode, follow_state = "original", nil
local camera_follow_status = "镜头实验：原跟随"
local status = "先生成狮鹫，再开始驾驶。"
local hooks_ready, hooks_tried, friend_value = false, false, nil
local yaw_state, yaw_hook_ready = nil, false
local yaw_status = "自动转向镜头：未开启"
local controls,menu = {},{}
local masks = nil
local input = {x = 0, y = 0, buttons = 0}
local settings = {distance = 30, fov = 90, player_distance = 20, player_height = 0, freeze_player = true, rider_height=1.0, rider_forward=0, rider_side=0, camera_x=0, camera_y=0, camera_z=0, sphere_navigation=true, navigation_radius=4.019, steering_yaw=50.276, steering_pitch=22.018, navigation_height=0.991, bumper_pitch=59, controls_revision=1, camera_auto_yaw=false, camera_yaw_speed=120, camera_manual_threshold=0.55}
local loaded_settings=nil
local settings_path = "GriffinFlightBeta_Settings.json"
local log_id = os.date("!%Y%m%dT%H%M%SZ") .. "_" .. math.floor(os.clock() * 1000)
local part, last_flush, next_sample = 1, -math.huge, 0
local journal = {version = VERSION, events = {}, samples = {}}
local stop_driver, delete_one
local skip_think_enabled, skip_think_expected = false, nil
local skip_think_status = "跳过思考：默认开启，等待狮鹫就绪"

local function core()
    local c = rawget(_G, "NickCore")
    if c and c.properties and c.object and c.enemySpawner and type(run_once) == "function" then return c end
end
local function now()
    local c = core()
    return c and c.properties.gameTime or 0
end
local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function vector(v)
    assert(v and finite(v.x) and finite(v.y) and finite(v.z), "Invalid position")
    return {x = v.x, y = v.y, z = v.z}
end
local function flush()
    local ok, result = pcall(json.dump_file, "GriffinFlightBeta_" .. log_id .. "_" .. part .. ".json", journal)
    last_flush = now()
    if not ok or result == false then log.error("[GriffinFlightBeta] Log save failed") end
    return ok and result ~= false
end
local function rotate()
    if #journal.events < 400 and #journal.samples < 600 then return end
    if flush() then
        part = part + 1
        journal = {version = VERSION, events = {}, samples = {}}
    end
end
local function event(name, detail)
    rotate()
    if #journal.events < 450 then
        journal.events[#journal.events + 1] = {name = name, detail = detail, time = now()}
    end
    flush()
end
local function failed(label, err)
    status = label .. "：" .. tostring(err)
    event("error", status)
    log.error("[GriffinFlightBeta] " .. status)
end
if type(json.load_file) == "function" then
    local ok, saved = pcall(json.load_file, settings_path)
    if ok and type(saved) == "table" then
        loaded_settings=saved
        if type(saved.camera_auto_yaw)=="boolean" then settings.camera_auto_yaw=saved.camera_auto_yaw end
        if finite(saved.camera_manual_threshold) then settings.camera_manual_threshold=math.max(0.25,math.min(0.95,saved.camera_manual_threshold)) end
        if finite(saved.camera_yaw_speed) then settings.camera_yaw_speed=math.max(15,math.min(360,saved.camera_yaw_speed)) end
        if type(saved.freeze_player) == "boolean" then settings.freeze_player = saved.freeze_player end
        if type(saved.sphere_navigation)=="boolean" then settings.sphere_navigation=saved.sphere_navigation end
        if finite(saved.navigation_radius) then settings.navigation_radius=math.max(2,math.min(30,saved.navigation_radius)) end
        if finite(saved.navigation_height) then settings.navigation_height=math.max(-27,math.min(27,saved.navigation_height)) end
        if finite(saved.steering_yaw) then settings.steering_yaw=math.max(1,math.min(85,saved.steering_yaw)) end
        -- First controls migration adopts the user's screenshot, not an older cached pitch.
        if saved.controls_revision == 1 and finite(saved.steering_pitch) then settings.steering_pitch=math.max(1,math.min(80,saved.steering_pitch)) end
        if finite(saved.bumper_pitch) then settings.bumper_pitch=math.max(1,math.min(59,saved.bumper_pitch)) end
        if finite(saved.player_height) then settings.player_height = math.max(-80, math.min(80, saved.player_height)) end
        if finite(saved.player_distance) then settings.player_distance = math.max(2, math.min(80, saved.player_distance)) end
        if finite(saved.distance) then settings.distance = math.max(0, math.min(80, saved.distance)) end
        if finite(saved.fov) then settings.fov = math.max(40, math.min(120, saved.fov)) end
        if finite(saved.rider_height) then settings.rider_height=math.max(-5,math.min(15,saved.rider_height)) end
        if finite(saved.rider_forward) then settings.rider_forward=math.max(-15,math.min(15,saved.rider_forward)) end
        if finite(saved.rider_side) then settings.rider_side=math.max(-10,math.min(10,saved.rider_side)) end
        for _,key in ipairs({"camera_x","camera_y","camera_z"}) do
            if finite(saved[key]) then settings[key]=math.max(-80,math.min(80,saved[key])) end
        end
    end
end

local function aggro_clear()
    local cfg = package.loaded["NicksDevtools/Config"]
    return not (type(cfg) == "table" and (cfg.disableAggro or cfg.forceAggro))
end
local function pair_is_owned(a, b)
    if not alive or state.generation ~= generation then return false end
    for _, r in ipairs(state.spawns) do
        local ch = r.result and r.result.chara
        if r.friend and ch then
            for _, p in ipairs(r.party or {}) do
                if (a == ch and b == p) or (b == ch and a == p) then return true end
            end
        end
    end
    return false
end
local function install_hooks()
    if hooks_ready then return end
    assert(not hooks_tried, "Friend hook initialization failed; reset scripts")
    local enum = sdk.find_type_definition("app.Character.BattleRelationship")
    friend_value = assert(enum and enum:get_field("Friend"), "Friend enum unavailable"):get_data()
    assert(finite(friend_value), "Invalid Friend enum")
    local ptr = sdk.to_ptr(friend_value)
    local c = sdk.find_type_definition("app.Character")
    local h = sdk.find_type_definition("app.BattleRelationshipHolder")
    local cm = c and c:get_method("getBattleRelationshipTo(app.Character)")
    local hm = h and h:get_method("getRelationshipFromTo(app.Character, app.Character)")
    assert(cm and hm, "Friend methods unavailable")
    hooks_tried = true
    local function attach(method, i, j)
        sdk.hook(method, function(args)
            thread.get_hook_storage().griffin_flight_beta_friend = pair_is_owned(
                sdk.to_managed_object(args[i]), sdk.to_managed_object(args[j]))
        end, function(ret)
            if alive and thread.get_hook_storage().griffin_flight_beta_friend then return ptr end
            return ret
        end)
    end
    attach(cm, 2, 3)
    attach(hm, 3, 4)
    hooks_ready = true
end
local function capture_party(c, player)
    assert(aggro_clear(), "请关闭 NicksDevtools 的 Disable Aggro / Force Aggro")
    local party = c.object.get_party()
    assert(type(party) == "table" and party[1] == player, "Party unavailable")
    return party
end
local function validate_spawn(r)
    local c = assert(core(), "NickCore unavailable")
    assert(c.properties.player == r.owner and not c.properties.isPaused, "Player changed or game paused")
    local result = r.result
    assert(result and result.go and result.chara, "等待狮鹫生成完成")
    assert(result.go:get_Valid() and result.chara:get_Valid(), "Griffin no longer valid")
    assert(result.chara:get_CharaIDString() == "ch253000_00"
        and result.chara:call("get_GameObject()") == result.go, "Griffin reference mismatch")
    assert(r.friend and aggro_clear(), "Friend override unavailable")
    assert(r.owner:get_Valid(), "Player no longer valid")
    local unavailable = 0
    for _, member in ipairs(r.party) do
        -- A distant pawn may leave the loaded scene. Never pass an invalid reference
        -- to native relationship calls, and do not end the player's flight for it.
        if member:get_Valid() then
            assert(result.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
                and member:call("getBattleRelationshipTo(app.Character)", result.chara) == friend_value,
                "Party relationship changed")
        else
            unavailable = unavailable + 1
        end
    end
    if unavailable ~= (r.unavailable_party or 0) then
        r.unavailable_party = unavailable
        event("party_reference_availability", {unavailable=unavailable, ignored_for_driver=true})
    end
    return result.chara
end
local function owned_player(d, require_current)
    if require_current and (not core() or core().properties.player ~= d.player) then return false end
    if not d.player:get_Valid() or not d.player_go:get_Valid() then return false end
    return d.player:call("get_GameObject()") == d.player_go
        and d.player:call("get_Transform()") == d.transform
        and d.player:get_field("<PosRotContext>k__BackingField") == d.context
        and d.player:get_field("<AdjustTerrain>k__BackingField") == d.terrain
        and d.terrain.MainCharacterController == d.controller
        and d.player:get_field("<FallInfo>k__BackingField") == d.fall
end
local function player_fsm(player)
    local manager = player:call("get_ActionManager()")
    return manager and manager.Fsm
end
local function sync_player(d)
    local pos = d.transform:call("get_UniversalPosition()")
    d.context:call("setPos(via.Position)", pos)
    -- Runs on every anchored UpdateBehavior, including centered input and an open UI.
    d.fall:call("resetBaseHeight(via.Position)", pos)
    d.fall:call("resetFallHeight()")
    d.controller:call("warp()")
end
-- All layers follow a neutral Griffin anchor; only the selected layer gets stick offset.
-- Engine coupling is observed through readback, not assumed away.
local anchor_mode="rider"
local anchor_modes={
    {key="full",label="完整同步"},
    {key="rider",label="仅Hip头顶"},
}

local function close_position(a,b)
    return math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)<0.001
end
local function restore_bone(d)
    local items=d.bones_applied
    if not items then return end
    if not owned_player(d,false) then d.bones_applied=nil;return end
    -- Decide ownership before any parent write changes a child's world position.
    local matches={}
    for i,a in ipairs(items) do
        matches[i]=a.joint:get_Valid() and close_position(vector(a.joint:call("get_Position()")),a.written)
    end
    -- Restore parent first, then child, using the pose captured before either write.
    for i,a in ipairs(items) do
        if matches[i] then a.joint:call("set_Position(via.vec3)",Vector3f.new(a.original.x,a.original.y,a.original.z)) end
    end
    d.bones_applied=nil
end

local function discover_joints(d)
    if d.joints_searched then return end
    d.joints_searched=true
    d.display_roots={}
    local joints=d.transform:call("get_Joints()")
    assert(joints,"Player joints unavailable")
    for _,joint in pairs(joints:get_elements() or {}) do
        if joint and joint:get_Valid() then
            local name=tostring(joint:call("get_Name()"))
            if name:lower()=="hip" then d.hip_joint=joint;d.hip_name=name end
            if name:lower()=="root" then d.root_joint=joint;d.root_name=name end
            local parent=joint:call("get_Parent()")
            if not parent or not parent:get_Valid() then
                d.display_roots[#d.display_roots+1]=joint
                if not d.root_joint then d.root_joint=joint;d.root_name=name end
            end
        end
    end
    event("anchor_joint_inventory",{root=d.root_name,hip=d.hip_name,display_roots=#d.display_roots})
end
local function prepare_rider(d,key)
    discover_joints(d)
    assert(d.hip_joint and d.hip_joint:get_Valid(),"玩家Hip骨骼不可用，未开启固定")
    local ch=d.spawn.result.chara
    local tr=ch:call("get_Transform()")
    assert(tr,"Griffin Transform unavailable")
    d.rider_griffin_transform=tr
    d.rider_head=nil;d.rider_head_name=nil
    local joints=tr:call("get_Joints()")
    local candidates={}
    if joints then
        for _,joint in pairs(joints:get_elements() or {}) do
            if joint and joint:get_Valid() then
                local name=tostring(joint:call("get_Name()"))
                local lower=name:lower()
                if lower:find("head",1,true) then
                    candidates[#candidates+1]=name
                    if lower=="head" then d.rider_head=joint;d.rider_head_name=name
                    elseif not d.rider_head and not lower:find("end",1,true) and not lower:find("target",1,true)
                        and not lower:find("eff",1,true) then d.rider_head=joint;d.rider_head_name=name end
                end
            end
        end
    end
    event("rider_head_binding",{head=d.rider_head_name,candidates=candidates,
        fallback=not d.rider_head and "Griffin root + forward 3m / up 4m" or nil})
end
local function prepare_anchor_mode(d,key)
    if key=="rider" then prepare_rider(d,key);return end
    if key~="full" then
        local td=sdk.find_type_definition("via.physics.CharacterController")
        assert(td and td:get_method("applyWorldOffset(via.vec3)"),"Controller world-offset interface unavailable")
        local ct=sdk.find_type_definition("app.CharacterPosRotContext")
        assert(ct and ct:get_method("setPos(via.Position)"),"Context position interface unavailable")
    end
    if key=="root_bone" or key=="hip" then
        discover_joints(d)
        local joint=d.root_joint
        if key=="hip" then joint=d.hip_joint end
        assert(joint and joint:get_Valid(),"当前玩家没有可用的对应骨骼；未切换")
    elseif key=="controller" then
        local td=sdk.find_type_definition("via.physics.CharacterController")
        assert(td and td:get_method("applyWorldOffset(via.vec3)"),"Controller world-offset interface unavailable")
    elseif key=="context" then
        local td=sdk.find_type_definition("app.CharacterPosRotContext")
        assert(td and td:get_method("get_Pos()") and td:get_method("setPos(via.Position)"),"Context position interface unavailable")
    end
end
local function anchor_positions(d)
    local scene=vector(d.transform:call("get_Position()"))
    local universal=vector(d.transform:call("get_UniversalPosition()"))
    local ctx=vector(d.context:call("get_Pos()"))
    return {transform=scene,controller=vector(d.controller:call("get_Position()")),
        context={x=ctx.x-universal.x+scene.x,y=ctx.y-universal.y+scene.y,z=ctx.z-universal.z+scene.z},
        root_bone=d.root_joint and d.root_joint:get_Valid() and vector(d.root_joint:call("get_Position()")) or nil,
        hip=d.hip_joint and d.hip_joint:get_Valid() and vector(d.hip_joint:call("get_Position()")) or nil}
end
local function set_context_scene(d,target)
    local scene=vector(d.transform:call("get_Position()"))
    local universal=d.transform:call("get_UniversalPosition()")
    universal.x=universal.x+target.x-scene.x
    universal.y=universal.y+target.y-scene.y
    universal.z=universal.z+target.z-scene.z
    d.context:call("setPos(via.Position)",universal)
end
local function write_anchor(d,target,neutral)
    local key=d.anchor_mode
    restore_bone(d) -- remove last frame's pose correction before moving the actor
    d.anchor_target=target;d.neutral_anchor=neutral
    d.moved=true
    if key=="full" or key=="rider" then
        d.transform:call("set_Position(via.vec3)",Vector3f.new(target.x,target.y,target.z))
        sync_player(d)
        d.anchor_plan={transform=target,context=target,controller=target}
        return
    end
    local actor_target=key=="transform" and target or neutral
    local context_target=key=="context" and target or neutral
    local controller_target=key=="controller" and target or neutral
    -- Move all layers with the Griffin. Unselected layers get neutral, not stick.
    d.transform:call("set_Position(via.vec3)",Vector3f.new(actor_target.x,actor_target.y,actor_target.z))
    set_context_scene(d,context_target)
    local physical=vector(d.controller:call("get_Position()"))
    d.controller:call("applyWorldOffset(via.vec3)",Vector3f.new(controller_target.x-physical.x,
        controller_target.y-physical.y,controller_target.z-physical.z))
    d.fall:call("resetBaseHeight(via.Position)",d.transform:call("get_UniversalPosition()"))
    d.fall:call("resetFallHeight()")
    d.anchor_plan={transform=actor_target,context=context_target,controller=controller_target}
end

local function change_anchor_mode(key)
    local d=active
    if not d then anchor_mode=key;settings.anchor_mode=key;pcall(json.dump_file,settings_path,settings);event("anchor_mode_selected",key);return end
    run_once(function()
        if not alive or active~=d then return end
        local mutating=false
        local ok,err=pcall(function()
            validate_spawn(d.spawn)
            assert(owned_player(d,true),"Player binding changed")
            prepare_anchor_mode(d,key)
            mutating=true
            restore_bone(d)
            -- Normalize layers to the current player Transform once, at the boundary.
            sync_player(d)
            d.anchor_mode=key;anchor_mode=key;settings.anchor_mode=key;pcall(json.dump_file,settings_path,settings);d.anchor_target=nil;d.neutral_anchor=nil;d.anchor_plan=nil;d.target_probe_failed=nil
            event("anchor_mode_changed",{mode=key,baseline=anchor_positions(d)})
        end)
        if not ok then
            if mutating then stop_driver("位置实验切换未完成") end
            failed("位置实验切换失败",err)
        end
    end)
end
-- Camera experiment: target bone or native BaseOffset only. Never changes navigation.
local camera_modes={
    {key="original",label="原跟随／恢复镜头"},
    {key="offset",label="【本轮】镜头偏移滑条"},
    {key="hip",label="【本轮】镜头跟随玩家Hip"},
    {key="griffin",label="【本轮】镜头跟随狮鹫头部"},
}
local function restore_follow()
    yaw_state=nil -- angle writes leave no persistent lock; native/manual control resumes
    local s=follow_state
    if not s then return true end
    local ok,err=pcall(function()
        if not s.main:get_Valid() then return end
        if s.main:call("get_TargetCharacter()")~=s.player then return end
        if s.last_joint and s.main:call("get_TargetJoint()")==s.last_joint then
            assert(s.original_joint and s.original_joint:get_Valid(),"原镜头骨骼已失效")
            s.main:call("set_TargetJoint(via.Joint)",s.original_joint)
        end
        if s.last_offset and close_position(vector(s.main:call("get_BaseOffset()")),s.last_offset) then
            local p=s.original_offset
            s.main:call("set_BaseOffset(via.vec3)",Vector3f.new(p.x,p.y,p.z))
        end
    end)
    if ok then follow_state=nil else event("camera_follow_restore_error",tostring(err)) end
    return ok,err
end
local function change_camera_mode(key)
    run_once(function()
        if not alive then return end
        local ok,err=restore_follow()
        if not ok then camera_follow_status="镜头恢复未完成："..tostring(err);return end
        camera_mode=key
        camera_follow_status=key=="original" and "镜头实验：原跟随" or "镜头实验已选择，驾驶期间生效。"
        event("camera_follow_mode",key)
    end)
end
local function tick_camera_follow()
    local d,c=active,core()
    if not alive or not d or camera_mode=="original" or not c or c.properties.isPaused then return end
    local ok,err=pcall(function()
        assert(owned_player(d,true),"玩家实例变化")
        local manager=assert(sdk.get_managed_singleton("app.CameraManager"),"CameraManager不可用")
        local controllers=manager._MainCameraControllers
        local main=controllers and controllers[0]
        assert(main and main:get_Valid(),"主镜头控制器不可用")
        assert(main:call("get_TargetCharacter()")==d.player,"当前镜头不属于驾驶玩家")
        if not follow_state then
            local joint
            if camera_mode=="hip" or camera_mode=="griffin" then
                prepare_rider(d,"rider")
                joint=camera_mode=="hip" and d.hip_joint or d.rider_head
                assert(joint and joint:get_Valid(),"所选跟随骨骼不可用；未改镜头")
            end
            local original_joint=main:call("get_TargetJoint()")
            if joint then assert(original_joint and original_joint:get_Valid(),"原镜头骨骼不可用，无法安全恢复") end
            local original_offset=vector(main:call("get_BaseOffset()"))
            follow_state={main=main,manager=manager,player=d.player,joint=joint,original_joint=original_joint,
                original_offset=original_offset,controller=main._CurrentCameraController}
            event("camera_follow_bound",{mode=camera_mode,original_joint=original_joint and tostring(original_joint:call("get_Name()")),
                joint=joint and tostring(joint:call("get_Name()")),offset=original_offset})
        end
        local s=follow_state
        assert(main==s.main and manager==s.manager and main._CurrentCameraController==s.controller,"镜头控制器变化，停止实验")
        if s.joint then
            assert(s.joint:get_Valid(),"跟随骨骼失效")
            s.last_joint=s.joint -- keep restoration information even if setter raises
            main:call("set_TargetJoint(via.Joint)",s.joint)
        else
            local p=s.original_offset
            s.last_offset={x=p.x+settings.camera_x,y=p.y+settings.camera_y,z=p.z+settings.camera_z}
            local v=s.last_offset
            main:call("set_BaseOffset(via.vec3)",Vector3f.new(v.x,v.y,v.z))
        end
        camera_follow_status="镜头实验运行："..camera_mode
    end)
    if not ok then
        local restored,restore_err=restore_follow()
        camera_mode="original"
        camera_follow_status="镜头实验停用："..tostring(err)..(not restored and ("；恢复失败："..tostring(restore_err)) or "")
        event("camera_follow_error",camera_follow_status)
    end
end
-- Native manual-camera update finishes input handling before rotation is built.
-- Only the current driving player's exact controller is touched. No camera Transform writes.
local function wrap_yaw(a) return (a+math.pi)%(2*math.pi)-math.pi end
local function yaw_failed(err)
    yaw_state=nil
    settings.camera_auto_yaw=false
    yaw_status="自动跟随已停用："..tostring(err)
    event("camera_yaw_error",tostring(err))
end
local function tick_camera_yaw(controller)
    local d,s=active,follow_state
    if not alive or not settings.camera_auto_yaw then return end
    if not d or not s or camera_mode~="griffin" or d.gear~=3 or not d.controls_active or d.external_control then
        yaw_state=nil; yaw_status="自动跟随待机：仅3档头部镜头生效";return
    end
    if controller~=s.controller then return end
    local ok,err=pcall(function()
        local c=core()
        if not c or c.properties.isPaused then yaw_state=nil;return end
        assert(owned_player(d,true) and s.main:get_Valid(),"驾驶玩家或镜头失效")
        assert(s.main:call("get_TargetCharacter()")==d.player and s.main._CurrentCameraController==controller,
            "镜头归属或控制器变化")
        assert(sdk.get_managed_singleton("app.CameraManager")==s.manager,"镜头管理器变化")
        assert(not input.right_error and finite(input.rx) and finite(input.ry),"右摇杆读取不可用")
        local angle=vector(controller:call("get_Angle()"))
        local t=now()
        if not yaw_state or yaw_state.controller~=controller then
            -- Compare native/degree ranges instead of assuming the angle unit.
            local range=controller:call("get_YawRange()")
            local degrees=controller:call("get_YawRangeDeg()")
            assert(range and degrees and finite(range.x) and finite(range.y) and finite(degrees.x) and finite(degrees.y),"镜头角度范围不可用")
            local span,deg_span=math.abs(range.y-range.x),math.abs(degrees.y-degrees.x)
            assert(span>0.001 and deg_span>0.001,"镜头角度范围无效")
            local scale=(span/deg_span)*(180/math.pi)
            assert(math.abs(scale-1)<0.02 or math.abs(scale-180/math.pi)<0.1,"未知镜头角度单位")
            -- Calibrate the native orbit-angle offset from the actual camera-to-target ray.
            local pos=vector(s.main:call("get_Position()"))
            local target=vector(s.main:call("get_TargetPosition()"))
            local dx,dz=target.x-pos.x,target.z-pos.z
            assert(dx*dx+dz*dz>0.01,"镜头过于垂直，暂不能确定水平朝向")
            yaw_state={controller=controller,last_time=t,resume_at=t,
                scale=scale,offset=wrap_yaw(angle.y/scale-math.atan(dx,dz)),
                manual_yaw=0,previous_yaw=angle.y/scale}
            event("camera_yaw_bound",{scale=scale,offset=yaw_state.offset,original_yaw=angle.y})
        end
        local y=yaw_state
        local dt=math.max(0,math.min(0.1,t-y.last_time));y.last_time=t
        local magnitude=math.min(1,math.sqrt(input.rx*input.rx+input.ry*input.ry))
        local threshold=settings.camera_manual_threshold
        if magnitude>=threshold then y.manual_latched=true; y.resume_at=t+0.8
        elseif y.manual_latched then
            if magnitude>threshold-0.08 then y.resume_at=t+0.8
            else y.manual_latched=false end
        end
        local current=angle.y/y.scale
        local steering=input.x~=0 or input.y~=0
        local paused=y.manual_latched or t<y.resume_at
        if not steering or paused then
            y.previous_yaw=current
            yaw_status=not steering and "左摇杆回中：自动跟随暂停" or "右摇杆接管；释放后延迟恢复"
            d.trace.camera_yaw={manual=paused,steering=steering,current=angle.y,pitch=angle.x,
                right_magnitude=magnitude,threshold=threshold,weight=0,scale=y.scale}
            return
        end
        -- Original manual input has already updated Angle. Carry its actual delta into
        -- the follow target as well, so automatic correction doesn't erase that input.
        if magnitude>0.1 then
            y.manual_yaw=wrap_yaw(y.manual_yaw+wrap_yaw(current-y.previous_yaw))
        end
        local fraction=math.max(0,math.min(1,(magnitude-0.1)/(threshold-0.1)))
        local weight=1-fraction*fraction*(3-2*fraction)
        assert(d.heading and finite(d.heading.x) and finite(d.heading.z),"狮鹫朝向不可用")
        local desired=wrap_yaw(math.atan(d.heading.x,d.heading.z)+y.offset+y.manual_yaw)
        local function eased_step(error,speed)
            local maximum=math.rad(speed)*dt*weight
            return math.max(-maximum,math.min(maximum,error*(1-math.exp(-5*dt))*weight))
        end
        local step=eased_step(wrap_yaw(desired-current),settings.camera_yaw_speed)
        local output=current+step
        if dt>0 and math.abs(step)>0.00001 then controller:call("setYaw(System.Single)",output*y.scale) end
        y.previous_yaw=output
        yaw_status="3档转向跟随；右摇杆小幅叠加、大幅接管"
        d.trace.camera_yaw={manual=false,steering=true,current=angle.y,requested=output*y.scale,target=desired*y.scale,
            right_magnitude=magnitude,threshold=threshold,weight=weight,
            manual_yaw=y.manual_yaw,speed=settings.camera_yaw_speed,scale=y.scale,dt=dt}

    end)
    if not ok then yaw_failed(err) end
end
local function install_yaw_hook()
    if yaw_hook_ready then return true end
    local ok,err=pcall(function()
        local def=assert(sdk.find_type_definition("app.RotateCameraControllerBase"),"镜头旋转类型不可用")
        local method=assert(def:get_method("updateManualCameraControl()"),"镜头手动更新接口不可用")
        assert(def:get_method("setYaw(System.Single)") and def:get_method("get_Angle()") and
            def:get_method("get_YawRange()") and def:get_method("get_YawRangeDeg()"),"镜头水平角接口不可用")
        sdk.hook(method,function(args)
            local storage=thread.get_hook_storage()
            storage.griffin_yaw_controller=nil
            if alive and settings.camera_auto_yaw and active and follow_state then
                local candidate=sdk.to_managed_object(args[2])
                if candidate==follow_state.controller then storage.griffin_yaw_controller=candidate end
            end
        end,function(retval)
            local candidate=thread.get_hook_storage().griffin_yaw_controller
            if candidate then tick_camera_yaw(candidate) end
            return retval
        end)
        yaw_hook_ready=true
    end)
    if not ok then yaw_failed(err) end
    return ok
end
local function read_camera_follow()
    local d,s=active,follow_state
    if not d or not s then return end
    local ok,probe=pcall(function()
        return {mode=camera_mode,target=vector(s.main:call("get_TargetPosition()")),
            base_offset=vector(s.main:call("get_BaseOffset()")),
            selected=s.joint and vector(s.joint:call("get_Position()")) or nil,
            readback_matches=not s.joint or s.main:call("get_TargetJoint()")==s.joint,
            player=vector(d.transform:call("get_Position()")),
            hip=d.hip_joint and vector(d.hip_joint:call("get_Position()")) or nil,
            griffin=vector(d.spawn.result.chara:call("get_Transform()"):call("get_Position()"))}
    end)
    if d.trace then d.trace.camera_follow=ok and probe or {mode=camera_mode,error=tostring(probe)} end
end
local function restore_camera()
    restore_follow()
    camera_mode="original"
    yaw_state=nil
    local s = camera_state
    if not s then return end
    camera_state = nil
    local ok, err = pcall(function()
        if sdk.get_managed_singleton("app.CameraManager") == s.manager
            and math.abs(s.manager._DistanceOffset - s.last_distance) < 0.001 then
            s.manager._DistanceOffset = s.distance
        end
        if sdk.get_primary_camera() == s.camera
            and math.abs(s.camera:call("get_FOV") - s.last_fov) < 0.001 then
            s.camera:call("set_FOV", s.fov)
        end
    end)
    if not ok then event("camera_restore_error", tostring(err)) end
end
stop_driver = function(reason)
    operation = nil
    queued = false
    local d = active or state.recovery
    active = nil
    input = {x = 0, y = 0, buttons = 0}
    restore_camera()
    if not d then return true end
    d.intent = nil -- queued native action callbacks must see that driving has ended
    local errors = {}
    local bone_ok,bone_err=pcall(restore_bone,d)
    if not bone_ok then errors[#errors+1]="骨骼恢复 "..tostring(bone_err) end
    if d.moved then
        local ok, err = pcall(function()
            if owned_player(d, true) then
                d.transform:call("set_UniversalPosition(via.Position)", d.original_position)
                sync_player(d)
            end
            d.moved = false
        end)
        if not ok then errors[#errors + 1] = "位置恢复 " .. tostring(err) end
    end
    if d.fsm_touched then
        local ok, err = pcall(function()
            if d.player:get_Valid() and player_fsm(d.player) == d.fsm then
                d.fsm:call("set_Enabled(System.Boolean)", d.original_fsm)
                d.fsm_touched = false
            elseif not d.player:get_Valid() then
                d.fsm_touched = false
            else
                error("Player FSM instance changed; saved FSM was not written")
            end
        end)
        if not ok then errors[#errors + 1] = "FSM恢复 " .. tostring(err) end
    end
    state.recovery = (#errors > 0) and d or nil
    status = #errors > 0 and ("驾驶已停止，请再点结束驾驶恢复：" .. table.concat(errors, "; "))
        or "驾驶已结束，玩家已恢复。"
    event("driver_stopped", {reason = reason, errors = errors})
    return #errors == 0
end

-- Independent HID mapping, following OJR's capture/release-gate layout (no OJR/Hotkeys dependency).
controls.rows={
    {"spawn","召唤狮鹫","None","None"},{"start","开始驾驶","F","None"},
    {"stop","结束驾驶","X","None"},{"delete","删除狮鹫","None","None"},
    {"listen","让狮鹫听话","H","None"},{"a","起飞","Space","RDown"},
    {"rt","冲刺／3档","LShift","RTrigBottom"},{"lt","减速／降档","LControl","LTrigBottom"},
    {"rb","爬升／悬停","E","RTrigTop"},{"lb","俯冲／降落","Q","LTrigTop"},
    {"left","向左","A","None"},{"right","向右","D","None"},
    {"up","向上／前","W","None"},{"down","向下／后","S","None"},
    {"preset_next","切换座位预设","None","None"},
}
controls.enums={keyboard={},gamepad={}}
controls.choices={keyboard={"None"},gamepad={"None"}}
controls.previous={}
controls.save=function() pcall(json.dump_file,settings_path,settings) end
controls.enum=function(type_name,target,prefix)
    local def=sdk.find_type_definition(type_name)
    if not def then return end
    if def.get_fields then
        for _,field in ipairs(def:get_fields()) do
            if field:is_static() then
                local value,name=field:get_data(nil),field:get_name()
                if finite(value) and value>0 and value==math.floor(value) and name~="All" then target[(prefix or "")..name]=value end
            end
        end
    else -- Minimal/mock runtimes: resolve only concrete defaults.
        for _,row in ipairs(controls.rows) do
            local name=type_name=="via.hid.KeyboardKey" and row[3] or row[4]
            local field=def:get_field(name);local value=field and field:get_data(nil)
            if finite(value) and value>0 then target[(prefix or "")..name]=value end
        end
    end
end
controls.enum("via.hid.KeyboardKey",controls.enums.keyboard)
controls.enum("via.hid.MouseButton",controls.enums.keyboard,"Mouse:")
controls.enum("via.hid.GamePadButton",controls.enums.gamepad)
for device,values in pairs(controls.enums) do
    for name in pairs(values) do controls.choices[device][#controls.choices[device]+1]=name end
    table.sort(controls.choices[device],function(a,b) if a==b then return false end;if a=="None" then return true end;if b=="None" then return false end;return a<b end)
end
settings.bindings={}
for _,row in ipairs(controls.rows) do
    settings.bindings[row[1]]={}
    for i,device in ipairs({"keyboard","gamepad"}) do
        local stored=loaded_settings and loaded_settings.bindings and loaded_settings.bindings[row[1]]
        stored=type(stored)=="table" and stored[device]
        settings.bindings[row[1]][device]=(stored=="None" or controls.enums[device][stored]) and stored or row[i+2]
    end
end
masks={a=1,rt=2,lt=4,rb=8,lb=16} -- Logical actions; physical enum values remain runtime-resolved above.
controls.device=function(singleton_name,type_name,method)
    local singleton=sdk.get_native_singleton(singleton_name)
    local def=sdk.find_type_definition(type_name)
    return singleton and def and sdk.call_native_func(singleton,def,method)
end
local function read_pad()
    local pad=controls.device("via.hid.Gamepad","via.hid.GamePad","get_MergedDevice")
    local kb=controls.device("via.hid.Keyboard","via.hid.Keyboard","get_Device")
    local mouse=controls.device("via.hid.Mouse","via.hid.Mouse","get_Device")
    assert(pad or kb,"未检测到手柄或键盘")
    local bits=pad and pad:call("get_Button") or 0
    local mbits=mouse and mouse:call("get_Button") or 0
    assert(finite(bits) and finite(mbits),"输入按键不可用")
    local function down(device,name)
        local code=controls.enums[device][name]
        if not code or code==0 or name=="None" then return false end
        if device=="gamepad" then return (bits & code)==code end
        if name:sub(1,6)=="Mouse:" then return (mbits & code)==code end
        return kb and kb:call("isDown",code)==true or false
    end
    local current={}
    for name,binding in pairs(settings.bindings) do current[name]=down("keyboard",binding.keyboard) or down("gamepad",binding.gamepad) end
    local suppressed=false
    if controls.capture then
        local capture,pressed=controls.capture,{}
        for _,name in ipairs(controls.choices[capture.device]) do pressed[name]=down(capture.device,name) end
        if capture.previous then
            for _,name in ipairs(controls.choices[capture.device]) do
                if pressed[name] and not capture.previous[name] then
                    settings.bindings[capture.action][capture.device]=name
                    controls.capture=nil;controls.release_gate=true;controls.save();break
                end
            end
        end
        capture.previous=pressed;suppressed=true
    end
    if controls.release_gate then
        local any=false
        for device,names in pairs(controls.choices) do
            for _,name in ipairs(names) do if down(device,name) then any=true;break end end
        end
        if not any then controls.release_gate=false end
        suppressed=true
    end
    local logical,edges=0,{}
    for name,value in pairs(current) do
        edges[name]=not suppressed and value and controls.previous[name]~=nil and not controls.previous[name]
        if not suppressed and value and masks[name] then logical=logical|masks[name] end
    end
    controls.previous=current
    local axis=pad and pad:call("get_AxisL()") or {x=0,y=0}
    assert(axis and finite(axis.x) and finite(axis.y),"摇杆不可用")
    local x,y=math.max(-1,math.min(1,axis.x)),math.max(-1,math.min(1,axis.y))
    local length=math.sqrt(x*x+y*y)
    if length<=0.2 then x,y=0,0 else local scale=math.min(1,(length-0.2)/0.8)/length;x,y=-x*scale,y*scale end
    x=math.max(-1,math.min(1,x+(current.left and 1 or 0)-(current.right and 1 or 0)))
    y=math.max(-1,math.min(1,y+(current.up and 1 or 0)-(current.down and 1 or 0)))
    if suppressed then x,y=0,0 end
    local rx,ry,right_error=0,0,nil
    if settings.camera_auto_yaw and pad then
        local ok,right=pcall(function() return pad:call("get_AxisR()") end)
        if ok and right and finite(right.x) and finite(right.y) then rx,ry=right.x,right.y else right_error="右摇杆读取失败" end
    end
    return {x=x,y=y,buttons=logical,rx=rx,ry=ry,right_error=right_error,edges=edges}
end

local function held(bits, mask) return (bits & mask) == mask end
local function set_intent(d, node, mode)
    d.intent = {node = node, mode = mode}
end
local function dispatch(d)
    if not d.intent or d.pending or now() - d.last_request < 0.35 then return end
    local intent = d.intent
    d.pending = true
    run_once(function()
        if not alive or active ~= d or d.intent ~= intent then d.pending = false; return end
        local ok, err = pcall(function()
            local ch = validate_spawn(d.spawn)
            assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
            local manager = ch:call("get_ActionManager()")
            assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
            event("action_request", {node = intent.node, mode = intent.mode})
            d.last_request = now()
            manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)", 10, intent.node, 0)
            d.mode = intent.mode
            d.intent = nil
            if d.mode == "taking_off" then d.takeoff_at = now(); d.saw_takeoff = false; d.auto_hover = intent.auto_hover end
            event("action_returned", intent.node)
        end)
        d.pending = false
        if not ok then stop_driver("Action request failed"); failed("动作请求失败", err) end
    end)
end
local function apply_player_freeze(d, freeze)
    assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player FSM binding changed")
    local desired = d.original_fsm
    if freeze then desired = false end
    local current = d.fsm:call("get_Enabled()")
    assert(type(current) == "boolean", "Cannot read player FSM")
    if current ~= desired then
        d.fsm_touched = true -- retain recovery even if the setter raises after writing
        d.fsm:call("set_Enabled(System.Boolean)", desired)
    end
    assert(d.fsm:call("get_Enabled()") == desired, "Player FSM mode readback mismatch")
    d.freeze_requested = freeze
    event("player_fsm_mode", {freeze_requested=freeze, enabled=desired, original_enabled=d.original_fsm})
end
local freeze_revision = 0
local function change_player_freeze(freeze)
    freeze_revision = freeze_revision + 1
    local revision, d = freeze_revision, active
    if not d then
        settings.freeze_player = freeze
        pcall(json.dump_file, settings_path, settings)
        return
    end
    run_once(function()
        if not alive or active ~= d or revision ~= freeze_revision then return end
        local ok, err = pcall(function()
            validate_spawn(d.spawn)
            apply_player_freeze(d, freeze)
            settings.freeze_player = freeze
            pcall(json.dump_file, settings_path, settings)
        end)
        if not ok then stop_driver("FSM 对照切换失败"); failed("FSM 对照切换失败", err) end
    end)
end

-- Bound to the retained spawn reference; free-player observations do not move the player.
local target_record, target_status = nil, "目标坐标：尚未记录"
local function target_context(r)
    local ch = validate_spawn(r)
    local c = assert(core())
    local player = c.properties.player
    assert(player == r.owner and player:get_Valid(), "Player binding changed")
    local transform = player:call("get_Transform()")
    assert(transform and transform == c.properties.transform, "Player transform changed")
    local component = c.object.get_component(r.result.go, "app.Ch253")
    local tc = component and component:call("get_TargetController()")
    assert(tc and tc:call("get_Owner()") == r.result.go and tc:call("get_Chara()") == ch,
        "TargetController binding mismatch")
    local ctrl = ch:call("get_FlightCtrl()")
    assert(ctrl and ctrl:call("get_CachedCharacter()") == ch, "FlightControl binding mismatch")
    return player, transform, tc, ctrl
end
local target_enum_names={}
local function target_type_name(value)
    local key=tostring(value)
    if target_enum_names[key] then return target_enum_names[key] end
    local td=sdk.find_type_definition("app.TargetController.TargetTypeEnum")
    if td then
        for _,name in ipairs({"ManualPlayer","CharaHighWithoutClimber","HateHigh","HateLow","LastTargetPosition","GeneratePosition","Self","Nearest","CharaHigh","CharaLow"}) do
            local field=td:get_field(name)
            if field then
                local v=field:get_data()
                if finite(v) then target_enum_names[tostring(v)]=name end
            end
        end
    end
    return target_enum_names[key] or "Unknown"
end
local function target_snapshot(r)
    local player, transform, tc, ctrl = target_context(r)
    local fsm = player_fsm(player)
    local target=tc:call("get_TargetCharacter()")
    local target_type=tc:call("get_TargetType()")
    local party_index=nil
    for i,member in ipairs(r.party) do if target==member then party_index=i;break end end
    return {target_is_player=target == player, target_is_self=target == r.result.chara,
        target_party_index=party_index, target_has_character=target~=nil,
        target_character_id=target and target:get_Valid() and target:get_CharaIDString() or nil,
        target_type=tostring(target_type), target_type_name=target_type_name(target_type),
        character_target_position=vector(tc:call("get_TargetPosition()")),
        flight_target_position=vector(ctrl:call("get_TargetPosition()")),
        player_position=vector(transform:call("get_Position()")),
        player_fsm_enabled=fsm and fsm:call("get_Enabled()"),
        freeze_requested=active and active.freeze_requested or false}
end
local function read_target_probe(d)
    if d.target_probe_failed then return {error=d.target_probe_failed} end
    local ok, value = pcall(function()
        assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
        return target_snapshot(d.spawn)
    end)
    if ok then return value end
    d.target_probe_failed = tostring(value)
    event("target_probe_error", d.target_probe_failed)
    return {error=d.target_probe_failed}
end
local function start_target_record(r)
    target_record={spawn=r,deadline=now()+60,next_sample=now()}
    target_status="目标坐标记录中（60秒），玩家可自由移动；日志自动保存。"
    event("target_record_started",60)
end
local function select_player_target(r)
    local _,_,tc=target_context(r)
    local td=sdk.find_type_definition("app.TargetController.TargetTypeEnum")
    local field=td and td:get_field("ManualPlayer")
    local value=field and field:get_data()
    assert(finite(value), "ManualPlayer enum unavailable")
    local type_def=sdk.find_type_definition("app.TargetController")
    assert(type_def and type_def:get_method("setTarget(app.TargetController.TargetTypeEnum)"), "Target selection interface unavailable")
    assert(tc:call("get_ManualPlayerTarget()"), "ManualPlayer target unavailable")
    event("manual_player_target_request",{value=value,before=target_snapshot(r)})
    tc:call("setTarget(app.TargetController.TargetTypeEnum)",value)
    event("manual_player_target_returned",target_snapshot(r))
end
local function target_test(sync_once, select_player)
    local r=active and active.spawn or state.spawns[#state.spawns]
    if not r or not r.ready or r.delete_requested then target_status="请先生成并等待狮鹫就绪。";return end
    run_once(function()
        if not alive or state.generation ~= generation or r.delete_requested or r.deleted then return end
        local ok,err=pcall(function()
            local before=target_snapshot(r)
            event("flight_target_test_before",before)
            if select_player then select_player_target(r) end
            if sync_once then
                local _, transform, tc, ctrl=target_context(r)
                assert(tc:call("get_TargetCharacter()") == r.owner, "目标角色不是玩家；取消同步")
                local td=sdk.find_type_definition("app.FlightControl")
                assert(td and td:get_method("setFlightTargetPosition(via.vec3)"), "Flight target setter unavailable")
                local pos=vector(transform:call("get_Position()"))
                event("flight_target_sync_request",pos)
                ctrl:call("setFlightTargetPosition(via.vec3)",Vector3f.new(pos.x,pos.y,pos.z))
                event("flight_target_sync_returned",target_snapshot(r))
            end
            start_target_record(r)
        end)
        if not ok then target_status="目标请求未完成："..tostring(err);event("target_test_error",target_status);start_target_record(r) end
    end)
end

local function request_instance_skip(result, player)
    assert(result and result.go and result.chara and result.go:get_Valid() and result.chara:get_Valid(), "Griffin unavailable")
    local ch = result.chara
    assert(ch:get_CharaIDString()=="ch253000_00" and ch:call("get_GameObject()")==result.go, "Griffin binding mismatch")
    local maker=ch:call("get_AIDecisionMaker()")
    assert(maker and maker:call("get_Character()")==ch, "AIDecisionMaker mismatch")
    local module=maker:call("get_DecisionModule()")
    assert(module and module:call("get_Chara()")==ch and module:call("get_Owner()")==result.go
        and module:call("get_AIDecisionMaker()")==maker, "DecisionModule mismatch")
    local td=sdk.find_type_definition("app.AIDecisionModule")
    assert(td and td:get_method("requestSkipThink()") and td:get_method("get_IsSkipThink()"), "SkipThink interface unavailable")
    module:call("requestSkipThink()")
    assert(module:call("get_IsSkipThink()")==true, "SkipThink flag readback failed")
end

local function set_skip_think(enabled)
    skip_think_enabled, skip_think_expected = false, nil
    if not enabled then skip_think_status="已停止请求跳过狮鹫思考。";event("skip_think_disabled",true);return true end
    local r=active and active.spawn or state.spawns[#state.spawns]
    if not alive or not r or not r.ready or r.delete_requested then return false,"请先生成并等待狮鹫就绪" end
    r.skip_retry_at=nil
    skip_think_expected=r
    skip_think_enabled=true
    skip_think_status="已开启逐帧跳过思考，等待首次请求。"
    event("skip_think_enabled",true)
    return true
end
local function tick_skip_think()
    if not skip_think_enabled or not alive then return end
    local c,r=core(),skip_think_expected
    if not c or c.properties.isPaused then return end
    if not r or r.owner~=c.properties.player or r.delete_requested or state.spawns[#state.spawns]~=r then
        skip_think_enabled=false;skip_think_expected=nil;skip_think_status="跳过思考：实例已退出";return
    end
    if now()<(r.skip_retry_at or 0) then return end
    local ok,err=pcall(request_instance_skip,r.result,r.owner)
    if ok then
        r.skip_retry_at=nil;r.skip_last_error=nil;r.skip_applied=true
        skip_think_status="跳过思考：已生效"
    else
        r.skip_applied=false;r.skip_retry_at=now()+0.25
        skip_think_status="跳过思考：等待模块就绪，自动重试"
        if not r.skip_error_time or now()-r.skip_error_time>=5 then
            r.skip_error_time=now();event("skip_think_retry",tostring(err))
        end
    end

end

local fall_hook_installed,fall_hook_tried=false,false
local block_player_fall=true
local fall_hits,fall_blocked,fall_logged,fall_log_at=0,0,0,-math.huge
local fall_hook_status="坠落死亡请求拦截：默认开启（仅驾驶玩家）"
local function install_fall_hook()
    if fall_hook_installed or fall_hook_tried then return end
    fall_hook_tried=true
    local ok,err=pcall(function()
        local td=sdk.find_type_definition("app.Character")
        local method=td and td:get_method("requestFallDead()")
        assert(method and sdk.PreHookResult and sdk.PreHookResult.SKIP_ORIGINAL,"Fall request hook unavailable")
        sdk.hook(method,function(args)
            local d,c=active,core()
            if alive and d and d.moved and c and not c.properties.isPaused and c.properties.player==d.player
                and sdk.to_managed_object(args[2])==d.player then
                fall_hits=fall_hits+1
                if block_player_fall then fall_blocked=fall_blocked+1;return sdk.PreHookResult.SKIP_ORIGINAL end
            end
        end,function(ret) return ret end)
        fall_hook_installed=true
    end)
    if not ok then fall_hook_status="坠落请求 Hook 不可用："..tostring(err);event("fall_hook_error",fall_hook_status) end
end

local function start_driver()
    local experiment = rawget(_G, "GriffinMountExperimentControl")
    if experiment and experiment.is_driving() then status = "请先结束实验工具的玩家固定。"; return end
    if active or state.recovery or queued then return end
    if not core() then status = "等待 NickCore 加载。"; return end
    local r = state.spawns[#state.spawns]
    if not r then status = "请先生成狮鹫。"; return end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        local ok, err = pcall(function()
            local c = assert(core(), "等待 NickCore 加载")
            r.party = capture_party(c, r.owner)
            validate_spawn(r)
            local bus = rawget(_G, "DD2_OxcartControl")
            assert(not bus or not bus.owner, "请先结束牛车驾驶")
            local player = r.owner
            local terrain = player:get_field("<AdjustTerrain>k__BackingField")
            local d = {spawn = r, player = player, player_go = player:call("get_GameObject()"),
                transform = player:call("get_Transform()"), context = player:get_field("<PosRotContext>k__BackingField"),
                terrain = terrain, controller = terrain and terrain.MainCharacterController,
                fall = player:get_field("<FallInfo>k__BackingField"), fsm = player_fsm(player),
                anchor_mode=anchor_mode, gear=1, controls_active=false, mode = "ground", last_request = -math.huge, started = now(), pending = false}
            assert(d.transform and d.context and d.controller and d.fall and d.fsm, "Player interfaces unavailable")
            local ft = d.fsm:get_type_definition()
            assert(ft:get_method("get_Enabled()") and ft:get_method("set_Enabled(System.Boolean)"), "FSM Enabled interface unavailable")
            d.original_position = d.transform:call("get_UniversalPosition()")
            d.original_fsm = d.fsm:call("get_Enabled()")
            assert(d.original_position and type(d.original_fsm) == "boolean", "Cannot capture player state")
            input = read_pad()
            d.previous_buttons = input.buttons -- holding A/RT on enable is not a fresh press
            active = d
            if settings.camera_auto_yaw then install_yaw_hook() end
            if settings.head_camera~=false then change_camera_mode("griffin") end
            install_fall_hook()
            apply_player_freeze(d, settings.freeze_player)
            local joint_ok,joint_err=pcall(discover_joints,d)
            if not joint_ok then event("anchor_joint_probe_error",tostring(joint_err)) end
            prepare_anchor_mode(d,d.anchor_mode)
            select_player_target(r)
            if r.result.chara:call("get_IsFlight()") then
                d.controls_active=true; d.control_node="Ch253HoverWaitHoHomingHeight"
                set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            end
            status = "驾驶中：A 仅起飞；RT 3档，LT 逐档减速；RB／LB 分档操作。"
            event("driver_started", {ahead = settings.player_distance, height = settings.player_height, freeze_player = d.freeze_requested, lateral = 12, vertical = 10, anchor_mode=d.anchor_mode,sphere_navigation=settings.sphere_navigation,navigation_radius=settings.navigation_radius,steering_yaw=settings.steering_yaw,steering_pitch=settings.steering_pitch})
        end)
        if not ok then
            if active then stop_driver("Start failed") end
            failed("未能开始驾驶", err)
        end
    end)
end

-- Fixed-radius spherical navigation. Stick sets angles, never accumulates distance.
local function navigation_anchor(d,ch,tr,pos,fx,fz)
    if not settings.sphere_navigation then
        local neutral={x=pos.x+fx*settings.player_distance,y=pos.y+settings.player_height,z=pos.z+fz*settings.player_distance}
        return {x=neutral.x+fz*input.x*12,y=neutral.y+input.y*10,z=neutral.z-fx*input.x*12},neutral,nil
    end
    if d.rider_griffin_transform~=tr or not d.rider_head or not d.rider_head:get_Valid() then
        prepare_rider(d,"rider")
    end
    assert(d.rider_head and d.rider_head:get_Valid(),"未找到狮鹫头部，不能建立头部球面导航；可关闭球面模式")
    assert(validate_spawn(d.spawn)==ch,"Griffin reference changed")
    local center=vector(d.rider_head:call("get_Position()"))
    local radius=settings.navigation_radius
    local nav_x,nav_y=input.x,input.y
    if d.controls_active and not d.external_control and (d.gear==2 or d.manual_hold) then nav_x,nav_y=0,0 end
    local yaw=math.max(-1,math.min(1,nav_x))*settings.steering_yaw*math.pi/180
    local height=math.max(-radius*0.9,math.min(radius*0.9,settings.navigation_height))
    local neutral_pitch=math.asin(height/radius)
    local limit=85*math.pi/180
    local pitch=math.max(-limit,math.min(limit,neutral_pitch+math.max(-1,math.min(1,nav_y))*settings.steering_pitch*math.pi/180))
    if d.controls_active and not d.external_control and d.gear==3 and masks then
        local rb,lb=held(input.buttons,masks.rb),held(input.buttons,masks.lb)
        if rb ~= lb then pitch=(rb and 1 or -1)*settings.bumper_pitch*math.pi/180 end
    end
    local horizontal=radius*math.cos(pitch)
    local dx=fx*math.cos(yaw)+fz*math.sin(yaw)
    local dz=fz*math.cos(yaw)-fx*math.sin(yaw)
    local target={x=center.x+dx*horizontal,y=center.y+radius*math.sin(pitch),z=center.z+dz*horizontal}
    local neutral_horizontal=math.sqrt(math.max(0,radius*radius-height*height))
    local neutral={x=center.x+fx*neutral_horizontal,y=center.y+height,z=center.z+fz*neutral_horizontal}
    -- Roundoff guard: the requested point is never intentionally outside the sphere.
    local ox,oy,oz=target.x-center.x,target.y-center.y,target.z-center.z
    local length=math.sqrt(ox*ox+oy*oy+oz*oz)
    if length>radius then
        local scale=radius/length
        target={x=center.x+ox*scale,y=center.y+oy*scale,z=center.z+oz*scale}
    end
    return target,neutral,{center=center,radius=radius,yaw_degrees=yaw*180/math.pi,pitch_degrees=pitch*180/math.pi,
        requested_distance=math.min(length,radius),head_joint=d.rider_head_name,
        neutral_height=height,neutral_pitch_degrees=neutral_pitch*180/math.pi}
end
local function tick_driver()
    local d = active
    if not d or not alive then return end
    local c = core()
    if not c or c.properties.isPaused or now() < d.started then stop_driver("游戏暂停或上下文变化"); return end
    local ok, err = pcall(function()
        local ch = validate_spawn(d.spawn)
        local bus = rawget(_G, "DD2_OxcartControl")
        assert(not bus or not bus.owner, "OJR owns the player")
        assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
        local tr = ch:call("get_Transform()")
        local pos, q = vector(tr:call("get_Position()")), tr:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w), "Invalid Griffin rotation")
        local norm = math.sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w)
        assert(norm > 0.0001, "Invalid Griffin rotation length")
        local qx,qy,qz,qw = q.x/norm,q.y/norm,q.z/norm,q.w/norm
        local fx,fz = 2*(qx*qz + qw*qy), 1-2*(qx*qx+qy*qy)
        local length = math.sqrt(fx*fx+fz*fz)
        assert(length > 0.2, "Griffin is too vertical")
        fx,fz = fx/length,fz/length
        d.heading={x=fx,z=fz}
        local flying, ground = ch:call("get_IsFlight()"), ch:call("get_IsGround()")
        local manager = ch:call("get_ActionManager()")
        assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
        local info = manager:get_field("CurrentAction")
        local action_name = info and info:get_field("Name")
        local pressed = input.buttons & (~d.previous_buttons)
        d.previous_buttons = input.buttons
        local moving=input.x~=0 or input.y~=0
        local function resume(gear)
            d.gear=gear; d.controls_active=true; d.external_control=false
            d.manual_hold=nil; d.control_node=nil; d.auto_hover=false
            d.intent=nil; d.mode="control"
            event("gear_selected",gear)
        end
        if held(pressed,masks.rt) then
            resume(3)
        elseif held(pressed,masks.lt) then
            resume(math.max(1,d.gear-1))
        elseif held(pressed,masks.a) then
            -- This native node can also land. Never request it in flight or twice mid-takeoff.
            if ground and not flying and d.mode~="taking_off" and action_name~="Ch253TakeoffBackJump" then
                resume(1); d.mode="taking_off"
                set_intent(d,"Ch253TakeoffBackJump","taking_off"); d.intent.auto_hover=true
            else event("takeoff_ignored","A仅允许地面起飞") end
        elseif d.gear<=2 and (held(pressed,masks.rb) or held(pressed,masks.lb)) then
            resume(d.gear)
            d.manual_hold=held(pressed,masks.rb) and "hover" or "landing"
            d.wait_center=true
        end
        if d.mode=="taking_off" then
            if action_name=="Ch253TakeoffBackJump" then d.saw_takeoff=true end
            if d.auto_hover and flying and action_name~="Ch253TakeoffBackJump" and not d.intent then
                d.mode="hover"; d.manual_hold="hover"; d.wait_center=true; d.control_node=nil
            elseif ground and not flying and d.saw_takeoff and action_name~="Ch253TakeoffBackJump" then
                d.mode="ground"; d.controls_active=false
            end
        end
        if d.manual_hold then
            if not moving then d.wait_center=false
            elseif not d.wait_center then d.manual_hold=nil; d.control_node=nil end
        end
        if d.controls_active and not d.external_control and d.mode~="taking_off" then
            local node,mode
            if d.manual_hold=="landing" then node,mode="Ch253HoverToLanding","landing"
            elseif d.manual_hold=="hover" then node,mode="Ch253HoverWaitHoHomingHeight","hover"
            elseif d.gear==3 then node,mode="Ch253WrapAroundStartLoop","dash"
            elseif d.gear==2 then
                node,mode="HoverForwardTargetHeight","coast"
                if moving and math.abs(input.x)>math.abs(input.y) then
                    node=input.x<0 and "HoverLateralRTargetHeight" or "HoverLateralLTargetHeight"
                elseif input.y<0 then node="HoverBackwardTargetHeight" end
            elseif moving then node,mode="Ch253AirHoverMoveToTarget","fine"
            else node,mode="Ch253HoverWaitHoHomingHeight","hover" end
            if node~=d.control_node then d.control_node=node; set_intent(d,node,mode) end
        end
        local target,neutral,sphere=navigation_anchor(d,ch,tr,pos,fx,fz)
        write_anchor(d,target,neutral)
        dispatch(d)
        d.trace = {navigation_sphere=sphere,neutral_anchor=neutral,anchor_plan=d.anchor_plan,griffin = pos, player = vector(d.transform:call("get_Position()")), target = target,
            physical = vector(d.controller:call("get_Position()")), flight = flying, ground = ground,
            action = tostring(action_name), mode = d.mode, gear=d.gear, manual_hold=d.manual_hold, external_control=d.external_control, bumpers={rb=held(input.buttons,masks.rb),lb=held(input.buttons,masks.lb)}, anchor_mode=d.anchor_mode, anchor_height = settings.player_height, stick = {x=input.x,y=input.y}}
    end)
    if not ok then stop_driver("驾驶检查或位置同步失败"); failed("驾驶已停止", err) end
end

-- Seat calculation only. Bone writes use the original Hip experiment callback below.
local function rider_seat(d)
    local ch=validate_spawn(d.spawn)
    assert(ch:call("get_Transform()")==d.rider_griffin_transform,"Griffin anchor changed")
    local base
    if d.rider_head then
        assert(d.rider_head:get_Valid(),"Griffin Head unavailable")
        base=vector(d.rider_head:call("get_Position()"))
    else
        base=vector(d.rider_griffin_transform:call("get_Position()"))
        base={x=base.x+d.heading.x*3,y=base.y+4,z=base.z+d.heading.z*3}
    end
    local fx,fz=d.heading.x,d.heading.z
    local seat={x=base.x+fx*settings.rider_forward+fz*settings.rider_side,
        y=base.y+settings.rider_height,z=base.z+fz*settings.rider_forward-fx*settings.rider_side}
    return seat,base
end
local function spawn()
    if queued or #state.spawns > 0 or state.recovery then return end
    settings.freeze_player=true;block_player_fall=true
    if not core() then status = "等待 NickCore 加载。"; return end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        local ok, err = pcall(function()
            local c = assert(core(), "等待 NickCore 加载")
            assert(c.properties.player and not c.properties.isPaused, "请进入游戏")
            install_hooks()
            local r = {owner = c.properties.player, party = capture_party(c,c.properties.player), friend = true}
            -- NickCore returns a mutable instance-reference table; never search by Character ID.
            r.result = c.enemySpawner.spawn_enemy("Griffin", nil, true)
            assert(type(r.result) == "table", "Spawn interface returned no reference table")
            state.spawns[#state.spawns+1] = r
            status = "正在生成狮鹫并设置友方……"
            event("spawn_requested", "NickCore Griffin; ThinkStop requested; exact returned reference")
        end)
        if not ok then failed("生成失败", err) end
    end)
end
delete_one = function(r)
    if r.destroy_queued then return end
    local result = r.result
    if not result or not result.go then return end -- retain pending table; delete when NickCore fills it
    r.destroy_queued = true
    local go = result.go
    run_once(function()
        if not alive then r.destroy_queued = false; return end
        local ok, err = pcall(function()
            assert(not active and not state.recovery, "End driving before deletion")
            assert(r.result == result and result.go == go, "Spawn reference changed")
            if go:get_Valid() then
                if result.chara and result.chara:get_Valid() then
                    assert(result.chara:call("get_GameObject()") == go
                        and result.chara:get_CharaIDString() == "ch253000_00", "Spawn identity mismatch")
                end
                event("delete_requested", "Only this Beta's returned GameObject")
                go:destroy(go) -- same native destruction form as installed NickCore; never destroy_spawns()
            end
            r.deleted = true; r.friend = false
            status = "本 Beta 生成的狮鹫已删除。"
            event("deleted", "Owned instance only")
        end)
        r.destroy_queued = false
        if not ok then r.delete_requested = false; failed("删除失败", err) end
    end)
end

re.on_frame(function()
    if not alive then return end
    local c = core()
    if not c then return end
    if fall_hits~=fall_logged and now()-fall_log_at>=1 then
        fall_logged=fall_hits;fall_log_at=now();event("player_fall_request",{hits=fall_hits,blocked=fall_blocked})
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
                    event("spawn_think_stop",{before=before,after=r.spawn_think_stop})
                    status = "狮鹫已生成并设为队伍友方，可以开始驾驶。"
                    event("spawn_ready", "Friend bound; spawn ThinkStop released when true")
                    set_skip_think(true)
                end)
                if not ok then failed("狮鹫初始化失败",err) end
            end)
        end
    end
    if active and active.trace and now() >= next_sample then
        next_sample = now()+0.5
        active.trace.target_probe = read_target_probe(active)
        local positions_ok,positions=pcall(anchor_positions,active)
        active.trace.anchor_positions=positions_ok and positions or {error=tostring(positions)}
        local sphere=active.trace.navigation_sphere
        if sphere and positions_ok then
            local p,h=positions.transform,sphere.center
            sphere.sampled_player_distance=math.sqrt((p.x-h.x)^2+(p.y-h.y)^2+(p.z-h.z)^2)
        end
        rotate()
        if #journal.samples < 650 then journal.samples[#journal.samples+1] = {time=now(), data=active.trace} end
    end
    if target_record and not c.properties.isPaused then
        local rec=target_record
        if now()>=rec.deadline or rec.spawn.deleted or rec.spawn.delete_requested then
            target_record=nil;target_status="目标坐标记录已结束，日志已保存。";event("target_record_stopped",true)
        elseif now()>=rec.next_sample then
            rec.next_sample=now()+0.5
            local ok,value=pcall(target_snapshot,rec.spawn)
            if ok then
                rotate()
                journal.samples[#journal.samples+1]={time=now(),data={kind="target_record",target_probe=value}}
            else
                target_record=nil;target_status="目标记录停止："..tostring(value);event("target_record_error",target_status)
            end
        end
    end
    if (active or target_record) and now()-last_flush >= 2 then flush() end
end)
re.on_application_entry("UpdateHID",function()
    if not alive then return end
    local ok,result=pcall(read_pad)
    if not ok then
        if active then stop_driver("输入读取失败");failed("输入读取失败",result) end
        return
    end
    input=result
    if controls.capture or controls.release_gate then return end
    for _,name in ipairs({"stop","delete","spawn","start","listen","preset_next"}) do
        if result.edges[name] then
            if name=="spawn" then spawn()
            elseif name=="start" then start_driver()
            elseif name=="stop" then menu.stop()
            elseif name=="delete" then menu.delete()
            elseif name=="listen" then menu.listen()
            elseif name=="preset_next" then menu.apply_preset(settings.seat_index%#settings.seat_presets+1) end
            break
        end
    end
end)

re.on_pre_application_entry("UpdateBehavior",function() tick_skip_think();tick_driver();tick_camera_follow() end)
re.on_pre_application_entry("UpdateJointExpression",function()
    local d=active
    if not d or not alive or not d.bones_applied then return end
    local ok,err=pcall(function()
        assert(owned_player(d,true),"Player binding changed")
        restore_bone(d)
    end)
    if not ok then stop_driver("骨骼恢复失败");failed("骨骼恢复失败",err) end
end)
re.on_application_entry("UpdateJointExpression",function()
    local d,c=active,core()
    if not d or not alive or not c or c.properties.isPaused or not d.anchor_target then return end
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
                local anchor=d.anchor_mode==spec.key and d.anchor_target or d.neutral_anchor
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
        if seat then
            d.rider_trace={phase="UpdateJointExpression",mode="rider",head_joint=d.rider_head_name,
                fallback=not d.rider_head,head=head,seat=seat,
                hip=vector(d.hip_joint:call("get_Position()")),
                root=d.root_joint and vector(d.root_joint:call("get_Position()")) or nil,
                transform=actor}
            if d.trace then d.trace.rider=d.rider_trace end
        end
    end)
    if not ok then stop_driver("骨骼位置实验失败");failed("骨骼位置实验失败",err) end
end)
re.on_application_entry("PrepareRendering",function()
    read_camera_follow()
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
        manager._DistanceOffset=settings.distance
        camera:call("set_FOV",settings.fov)
    end)
    if not ok then restore_camera(); d.camera_failed=true; event("camera_error",tostring(err)) end
end)
-- Runtime bridge: only retained Beta instances; never resolve by character ID/address.
local bridge = {}
local external_serial = 0
function bridge.get_instance()
    if not alive or state.generation ~= generation then return nil end
    local r = active and active.spawn or state.spawns[#state.spawns]
    if r and r.ready and not r.delete_requested then return r.result end
end
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
        active.mode = "external"
        active.external_control = true
        active.control_node = nil
        active.auto_hover = false
        set_intent(active, node, "external")
        event("external_action_queued", node)
    else
        local r = state.spawns[#state.spawns]
        run_once(function()
            if not alive or state.generation ~= generation or serial ~= external_serial or active
                or r.delete_requested or state.spawns[#state.spawns] ~= r then return end
            local ok, err = pcall(function()
                local ch = validate_spawn(r)
                local manager = ch:call("get_ActionManager()")
                assert(manager and manager:call("get_GameObject()") == r.result.go, "ActionManager mismatch")
                event("action_request", {node=node, mode="external"})
                manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)", 10, node, 0)
                event("action_returned", node)
            end)
            if not ok then failed("实验工具动作请求失败", err) end
        end)
    end
    return true
end
_G.GriffinFlightBetaBridge = bridge

re.on_script_reset(function()
    stop_driver("脚本重置")
    alive = false
    target_record=nil
    skip_think_enabled=false;skip_think_expected=nil;block_player_fall=false
    if rawget(_G, "GriffinFlightBetaBridge") == bridge then _G.GriffinFlightBetaBridge = nil end
    for _, r in ipairs(state.spawns) do r.friend = false; r.ready = false; r.destroy_queued = false end
    flush()
end)

-- Rebind only when this global table survives a same-Lua-state reload. A full Lua reset
-- may discard all references; never reconstruct native objects from addresses/IDs.
for _, r in ipairs(state.spawns) do r.friend = true; r.ready = false; r.destroy_queued = false end
local function beta_button(label)
    local styled = type(imgui.push_style_color)=="function" and type(imgui.pop_style_color)=="function"
    if styled then imgui.push_style_color(21,0xff98652b);imgui.push_style_color(0,0xffa8ecff) end
    local clicked = imgui.button(label)
    if styled then imgui.pop_style_color(2) end
    return clicked
end
-- Player-facing menu. Debug controls share this script and are collapsed by default.
settings.anchor_mode=loaded_settings and loaded_settings.anchor_mode=="full" and "full" or "rider"
anchor_mode=settings.anchor_mode
settings.head_camera=not loaded_settings or loaded_settings.head_camera~=false
menu.clone=function(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=menu.clone(v) end;return result
end
menu.preset_name="新座位预设"
menu.snapshot=function(name,source)
    return {schema=1,name=name,player={height=settings.rider_height,forward=settings.rider_forward,side=settings.rider_side},
        camera={distance=settings.distance,fov=settings.fov},pawns=menu.clone(source and source.pawns or {}),
        companions=menu.clone(source and source.companions or {})}
end
settings.seat_presets={}
if loaded_settings and type(loaded_settings.seat_presets)=="table" then
    for _,preset in ipairs(loaded_settings.seat_presets) do
        if type(preset)=="table" and type(preset.name)=="string" and type(preset.player)=="table"
            and finite(preset.player.height) and finite(preset.player.forward) and finite(preset.player.side) then
            settings.seat_presets[#settings.seat_presets+1]=menu.clone(preset)
        end
    end
end
if #settings.seat_presets==0 then settings.seat_presets[1]=menu.snapshot("默认座位（当前设置）") end
settings.seat_index=math.max(1,math.min(#settings.seat_presets,math.floor(tonumber(loaded_settings and loaded_settings.seat_index) or 1)))
menu.apply_preset=function(index)
    local preset=settings.seat_presets[index]
    if not preset then return end
    settings.seat_index=index
    settings.rider_height=math.max(-5,math.min(15,preset.player.height))
    settings.rider_forward=math.max(-15,math.min(15,preset.player.forward))
    settings.rider_side=math.max(-10,math.min(10,preset.player.side))
    if type(preset.camera)=="table" then
        if finite(preset.camera.distance) then settings.distance=math.max(0,math.min(80,preset.camera.distance)) end
        if finite(preset.camera.fov) then settings.fov=math.max(40,math.min(120,preset.camera.fov)) end
    end
    controls.save();status="已应用座位预设："..preset.name
end
menu.stop=function()
    operation=nil;queued=false
    if type(run_once)~="function" then stop_driver("手动结束");return end
    run_once(function() if alive then stop_driver("手动结束") end end)
end
menu.delete=function()
    operation=nil;queued=false
    if type(run_once)~="function" then status="等待依赖加载后再删除。";return end
    run_once(function()
        if not alive or not stop_driver("删除狮鹫") then return end
        set_skip_think(false)
        for _,r in ipairs(state.spawns) do r.delete_requested=true;delete_one(r) end
    end)
end
menu.listen=function()
    local r=active and active.spawn or state.spawns[#state.spawns]
    if not r or not r.ready or r.delete_requested then status="请先召唤狮鹫。";return end
    run_once(function()
        if not alive or r.deleted or r.delete_requested then return end
        local ok,err=pcall(select_player_target,r)
        if ok then status="狮鹫已重新锁定玩家。" else failed("未能重新锁定玩家",err) end
    end)
end
menu.slider=function(key,label,low,high)
    if type(imgui.slider_float)~="function" then return end
    local changed,value=imgui.slider_float(label,math.max(low,math.min(high,settings[key])),low,high)
    if changed and finite(value) then settings[key]=math.max(low,math.min(high,value));controls.save() end
end
menu.toggle=function(label,value)
    if type(imgui.checkbox)~="function" then return false,value end
    return imgui.checkbox(label,value)
end
menu.bindings=function()
    local table_open=type(imgui.begin_table)=="function" and imgui.begin_table("GriffinBindings",3,1)
    if table_open then
        imgui.table_next_row()
        for _,label in ipairs({"动作","手柄","键盘／鼠标"}) do imgui.table_next_column();imgui.table_header(label) end
    end
    for _,row in ipairs(controls.rows) do
        if table_open then imgui.table_next_row();imgui.table_next_column() end
        imgui.text(row[2])
        for _,device in ipairs({"gamepad","keyboard"}) do
            if table_open then imgui.table_next_column() end
            local capture=controls.capture
            local label=capture and capture.action==row[1] and capture.device==device and "请按新按键…" or settings.bindings[row[1]][device]
            if beta_button(label.."###BetaBind_"..row[1].."_"..device) then
                controls.capture={action=row[1],device=device};controls.previous={}
            end
        end
    end
    if table_open then imgui.end_table() end
    if controls.capture then
        imgui.text("先松开已按住的键，再按新键。录入期间暂停驾驶输入。")
        if beta_button("取消录入###BetaBindCancel") then controls.capture=nil;controls.release_gate=true end
        if beta_button("清除此绑定###BetaBindClear") then
            settings.bindings[controls.capture.action][controls.capture.device]="None"
            controls.capture=nil;controls.release_gate=true;controls.save()
        end
    end
    if beta_button("恢复默认按键###BetaBindDefaults") then
        for _,row in ipairs(controls.rows) do settings.bindings[row[1]]={keyboard=row[3],gamepad=row[4]} end
        controls.capture=nil;controls.release_gate=true;controls.previous={};controls.save()
    end
    local used={}
    for _,row in ipairs(controls.rows) do
        for _,device in ipairs({"keyboard","gamepad"}) do
            local name=settings.bindings[row[1]][device];local key=device..":"..name
            if name~="None" then
                if used[key] then imgui.text("重复绑定："..used[key].."／"..row[2].." → "..name) else used[key]=row[2] end
            end
        end
    end
end
re.on_draw_ui(function()
    if not imgui.tree_node("狮鹫旅程 Redux###GriffinFlightBeta") then return end
    imgui.text("Beta "..VERSION)
    if imgui.tree_node("一般设置") then
        if beta_button("一键生成狮鹫###BetaSpawn") then spawn() end
        if beta_button("开始驾驶###BetaStart") then start_driver() end
        if beta_button("结束驾驶###BetaStop") then menu.stop() end
        if beta_button("删除狮鹫###BetaDelete") then menu.delete() end
        if beta_button("让狮鹫听话###BetaSelectPlayerTarget") then menu.listen() end
        for _,mode in ipairs(anchor_modes) do
            local changed,value=menu.toggle(mode.label.."###BetaAnchor_"..mode.key,anchor_mode==mode.key)
            if changed then change_anchor_mode(value and mode.key or (mode.key=="full" and "rider" or "full")) end
        end
        imgui.text(status)
        if active then imgui.text("当前档位："..active.gear.."档") end
        imgui.tree_pop()
    end
    if imgui.tree_node("飞行设置") then
        menu.slider("steering_yaw","【本轮】左右转向灵敏度（最大角度）",1,85)
        menu.slider("steering_pitch","【本轮】摇杆上下微调（最大角度）",1,80)
        menu.slider("bumper_pitch","RB／LB 升降角度（最高59°）",1,59)
        menu.slider("navigation_radius","【本轮】头部导航半径（米）",2,30)
        menu.slider("navigation_height","【本轮】球面回中高度（米）",-settings.navigation_radius*0.9,settings.navigation_radius*0.9)
        imgui.tree_pop()
    end
    if imgui.tree_node("镜头设置") then
        local changed,value=menu.toggle("镜头跟随狮鹫头部",settings.head_camera)
        if changed then settings.head_camera=value;change_camera_mode(value and "griffin" or "original");controls.save() end
        changed,value=menu.toggle("3档转向时跟随镜头###BetaCameraYaw",settings.camera_auto_yaw)
        if changed then
            settings.camera_auto_yaw=value;yaw_state=nil
            if value and install_yaw_hook() then settings.head_camera=true;change_camera_mode("griffin") end
            controls.save()
        end
        menu.slider("distance","相机距离偏移",0,80);menu.slider("fov","FOV",40,120)
        menu.slider("camera_yaw_speed","【新增】镜头跟随速度（度／秒）",15,360)
        menu.slider("camera_manual_threshold","【新增】右摇杆接管阈值",0.25,0.95)
        imgui.tree_pop()
    end
    if imgui.tree_node("座位预设") then
        local names={};for _,preset in ipairs(settings.seat_presets) do names[#names+1]=preset.name end
        if type(imgui.combo)=="function" then
            local changed,index=imgui.combo("当前预设",settings.seat_index,names)
            if changed then menu.apply_preset(index) end
        else imgui.text("当前预设："..names[settings.seat_index]) end
        if beta_button("下一预设###BetaPresetNext") then menu.apply_preset(settings.seat_index%#settings.seat_presets+1) end
        menu.slider("rider_height","【新增】座位上下偏移",-5,15)
        menu.slider("rider_forward","【新增】座位前后偏移",-15,15)
        menu.slider("rider_side","【新增】座位左右偏移",-10,10)
        if type(imgui.input_text)=="function" then
            local changed,name=imgui.input_text("预设名称",menu.preset_name)
            if changed and type(name)=="string" then menu.preset_name=name:sub(1,120) end
        end
        if beta_button("保存到当前预设###BetaPresetSave") then
            local old=settings.seat_presets[settings.seat_index]
            settings.seat_presets[settings.seat_index]=menu.snapshot(old.name,old);controls.save();status="座位预设已保存。"
        end
        if beta_button("另存为新预设###BetaPresetNew") then
            local name=menu.preset_name:match("^%s*(.-)%s*$")
            if name~="" then settings.seat_presets[#settings.seat_presets+1]=menu.snapshot(name);settings.seat_index=#settings.seat_presets;controls.save() end
        end
        if beta_button("重命名当前预设###BetaPresetRename") then
            local name=menu.preset_name:match("^%s*(.-)%s*$")
            if name~="" then settings.seat_presets[settings.seat_index].name=name;controls.save() end
        end
        if beta_button("删除当前预设###BetaPresetDelete") then
            if #settings.seat_presets>1 then table.remove(settings.seat_presets,settings.seat_index);menu.apply_preset(math.min(settings.seat_index,#settings.seat_presets))
            else status="至少保留一个座位预设。" end
        end
        imgui.text("调整实时预览；保存后写入预设。当前仅玩家座位。")
        imgui.tree_pop()
    end
    if imgui.tree_node("按键设置") then menu.bindings();imgui.tree_pop() end
    if imgui.tree_node("DEBUG") then
        if beta_button((skip_think_enabled and "关闭跳过狮鹫思考" or "开启跳过狮鹫思考").."###BetaThinkToggle") then set_skip_think(not skip_think_enabled) end
        imgui.text(skip_think_status)
        local changed,value=menu.toggle("【测试】拦截玩家坠落死亡请求",block_player_fall)
        if changed then block_player_fall=value;if active then install_fall_hook() end;event("fall_request_block_mode",value) end
        changed,value=menu.toggle("【对照测试】冻结玩家 FSM",settings.freeze_player)
        if changed then change_player_freeze(value) end
        changed,value=menu.toggle("【本轮】限制导航目标在头部球面",settings.sphere_navigation)
        if changed then settings.sphere_navigation=value;controls.save() end
        menu.slider("player_height","【新增】玩家相对高度（米）",-80,80)
        menu.slider("player_distance","玩家与狮鹫距离",2,80)
        for _,mode in ipairs({{key="original",label="恢复原镜头"},{key="griffin",label="跟随狮鹫头部"}}) do
            changed,value=menu.toggle(mode.label.."###BetaCamera_"..mode.key,camera_mode==mode.key)
            if changed then change_camera_mode(value and mode.key or "original") end
        end
        imgui.text("坠落请求："..fall_hits.."；拦截："..fall_blocked)
        imgui.text(yaw_status);imgui.text(camera_follow_status)
        if active and active.trace then imgui.text("当前动作："..active.trace.action) end
        imgui.text("LB／RB超过59°时曾出现黑屏；是否由过快坠落引起尚未确认。")
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
