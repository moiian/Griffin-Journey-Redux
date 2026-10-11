-- Griffin Flight Beta 0.1.29. Requires installed NickCore + EnemySpawner + run_once.
-- Separate from GriffinMountExperiment; no OJR/LMD/NickCore files are changed.
local VERSION = "0.1.29-beta"
local state = rawget(_G, "GriffinFlightBetaState") or {spawns = {}}
_G.GriffinFlightBetaState = state
state.spawns = state.spawns or {}
local generation = {}
state.generation = generation
local alive, queued = true, false
local operation = nil
local active, camera_state = nil, nil
local camera_mode, follow_state = "original", nil
local camera_follow_status = "镜头跟随：游戏默认"
local status = "先生成狮鹫，再开始驾驶。"
local hooks_ready, hooks_tried, friend_value = false, false, nil
local yaw_state, yaw_hook_ready = nil, false
local yaw_status = "自动转向镜头：未开启"
local controls,menu,passengers = {},{},{}
passengers.frame=0
passengers.protection={damage=true,relocation=true,lost_check=false,destroy=false,counts={}}
local masks = nil
local input = {x = 0, y = 0, buttons = 0}
local settings = {distance = 30, fov = 90, freeze_player = true, rider_anim="", rider_lookX=0, rider_lookZ=1, rider_tilt_follow=1, rider_pitch_offset=0, rider_anchor="head", rider_neck_joint="", rider_height=1.0, rider_forward=0, rider_side=0, navigation_radius=4.019, steering_yaw=50.276, steering_pitch=22.018, navigation_height=0.991, bumper_pitch=59, controls_revision=1, camera_auto_yaw=false, camera_yaw_speed=120, camera_manual_threshold=0.55}
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
-- Same native Photo Mode flag used by OJR. Failure keeps ordinary pause behavior.
menu.photo_active=function()
    local ok,value=pcall(function()
        local gui=sdk.get_managed_singleton("app.GuiManager")
        return gui and gui["<IsDispPhotoModeAll>k__BackingField"]==true
    end)
    return ok and value==true
end
menu.gameplay_paused=function()
    local c=core()
    return not c or c.properties.isPaused or menu.photo_active()
end
menu.visual_allowed=function()
    local c=core()
    -- Display locking spans normal menus and the frame before pause is reported.
    -- Each visual write still validates the retained player/Griffin/actor instances.
    return alive and c and active and c.properties.player==active.player
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
local function event(name, detail, defer_flush)
    rotate()
    if #journal.events < 450 then
        journal.events[#journal.events + 1] = {name = name, detail = detail, time = now()}
    end
    if not defer_flush then flush() end
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
        settings.rider_anim=type(saved.rider_anim)=="string" and saved.rider_anim or ""
        if type(saved.camera_auto_yaw)=="boolean" then settings.camera_auto_yaw=saved.camera_auto_yaw end
        if finite(saved.camera_manual_threshold) then settings.camera_manual_threshold=math.max(0.25,math.min(0.95,saved.camera_manual_threshold)) end
        if finite(saved.camera_yaw_speed) then settings.camera_yaw_speed=math.max(15,math.min(360,saved.camera_yaw_speed)) end
        if type(saved.freeze_player) == "boolean" then settings.freeze_player = saved.freeze_player end
        if finite(saved.navigation_radius) then settings.navigation_radius=math.max(2,math.min(30,saved.navigation_radius)) end
        if finite(saved.navigation_height) then settings.navigation_height=math.max(-27,math.min(27,saved.navigation_height)) end
        if finite(saved.steering_yaw) then settings.steering_yaw=math.max(1,math.min(85,saved.steering_yaw)) end
        -- First controls migration adopts the user's screenshot, not an older cached pitch.
        if saved.controls_revision == 1 and finite(saved.steering_pitch) then settings.steering_pitch=math.max(1,math.min(80,saved.steering_pitch)) end
        if finite(saved.bumper_pitch) then settings.bumper_pitch=math.max(1,math.min(59,saved.bumper_pitch)) end
        if finite(saved.distance) then settings.distance = math.max(0, math.min(80, saved.distance)) end
        if finite(saved.fov) then settings.fov = math.max(40, math.min(120, saved.fov)) end
        for _,spec in ipairs({{"rider_lookX",-1,1},{"rider_lookZ",-1,1},{"rider_tilt_follow",0,1},{"rider_pitch_offset",-45,45}}) do
            if finite(saved[spec[1]]) then settings[spec[1]]=math.max(spec[2],math.min(spec[3],saved[spec[1]])) end
        end
        settings.rider_anchor=saved.rider_anchor=="neck" and "neck" or "head"
        settings.rider_neck_joint=type(saved.rider_neck_joint)=="string" and saved.rider_neck_joint or ""
        if finite(saved.rider_height) then settings.rider_height=math.max(-5,math.min(15,saved.rider_height)) end
        if finite(saved.rider_forward) then settings.rider_forward=math.max(-15,math.min(15,saved.rider_forward)) end
        if finite(saved.rider_side) then settings.rider_side=math.max(-10,math.min(10,saved.rider_side)) end
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
local function validate_spawn(r,visual_only)
    local c = assert(core(), "NickCore unavailable")
    assert(c.properties.player == r.owner and (not menu.gameplay_paused() or visual_only and menu.visual_allowed()), "Player changed or game paused")
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
passengers.reset_fall=function(d)
    local pos=d.transform:call("get_UniversalPosition()")
    d.fall:call("resetBaseHeight(via.Position)",pos)
    d.fall:call("resetFallHeight()")
    d.fall_reset_pending=false
end
local function sync_player(d,reset_fall)
    local pos = d.transform:call("get_UniversalPosition()")
    d.context:call("setPos(via.Position)", pos)
    -- Fall reset is an attach/preset/release operation, never a continuous movement update.
    if reset_fall or d.fall_reset_pending then passengers.reset_fall(d) end
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
local function prepare_rider(d)
    discover_joints(d)
    assert(d.hip_joint and d.hip_joint:get_Valid(),"玩家Hip骨骼不可用，未开启固定")
    local ch=d.spawn.result.chara
    local tr=ch:call("get_Transform()")
    assert(tr,"Griffin Transform unavailable")
    d.rider_griffin_transform=tr
    d.rider_head=nil;d.rider_head_name=nil;d.rider_necks={}
    local joints=tr:call("get_Joints()")
    local candidates={}
    if joints then
        for _,joint in pairs(joints:get_elements() or {}) do
            if joint and joint:get_Valid() then
                local name=tostring(joint:call("get_Name()"))
                local lower=name:lower()
                if lower:find("neck",1,true) and not lower:find("end",1,true)
                    and not lower:find("target",1,true) and not lower:find("eff",1,true) then
                    d.rider_necks[#d.rider_necks+1]={name=name,joint=joint}
                end
                if lower:find("head",1,true) then
                    candidates[#candidates+1]=name
                    if lower=="head" then d.rider_head=joint;d.rider_head_name=name
                    elseif not d.rider_head and not lower:find("end",1,true) and not lower:find("target",1,true)
                        and not lower:find("eff",1,true) then d.rider_head=joint;d.rider_head_name=name end
                end
            end
        end
    end
    table.sort(d.rider_necks,function(a,b) return a.name<b.name end)
    local neck_names={};for _,entry in ipairs(d.rider_necks) do neck_names[#neck_names+1]=entry.name end
    event("rider_head_binding",{head=d.rider_head_name,candidates=candidates,neck_candidates=neck_names,
        fallback=not d.rider_head and "Griffin root + forward 3m / up 4m" or nil})
end
local function prepare_anchor_mode(d,key)
    assert(key=="rider" or key=="full","Unsupported display mode")
    if key=="rider" then prepare_rider(d) end
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
local function write_anchor(d,target,neutral)
    restore_bone(d)
    d.anchor_target=target;d.neutral_anchor=neutral;d.moved=true
    d.transform:call("set_Position(via.vec3)",Vector3f.new(target.x,target.y,target.z))
    passengers.orient(d,passengers.player_config())
    sync_player(d)
    d.anchor_plan={transform=target,context=target,controller=target}
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
-- Head-joint camera follow; independent of navigation.
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
        camera_follow_status=key=="original" and "镜头跟随：游戏默认" or "镜头跟随已选择，驾驶期间生效。"
        event("camera_follow_mode",key)
    end)
end
local function tick_camera_follow()
    local d,c=active,core()
    if not alive or not d or camera_mode=="original" or not c or menu.gameplay_paused() then return end
    local ok,err=pcall(function()
        assert(owned_player(d,true),"玩家实例变化")
        local manager=assert(sdk.get_managed_singleton("app.CameraManager"),"CameraManager不可用")
        local controllers=manager._MainCameraControllers
        local main=controllers and controllers[0]
        assert(main and main:get_Valid(),"主镜头控制器不可用")
        assert(main:call("get_TargetCharacter()")==d.player,"当前镜头不属于驾驶玩家")
        if not follow_state then
            assert(camera_mode=="griffin","Unsupported camera follow mode")
            prepare_rider(d)
            local joint=d.rider_head
            assert(joint and joint:get_Valid(),"狮鹫头部骨骼不可用；未改镜头")
            local original_joint=main:call("get_TargetJoint()")
            if joint then assert(original_joint and original_joint:get_Valid(),"原镜头骨骼不可用，无法安全恢复") end
            follow_state={main=main,manager=manager,player=d.player,joint=joint,original_joint=original_joint,
                controller=main._CurrentCameraController}
            event("camera_follow_bound",{mode=camera_mode,original_joint=original_joint and tostring(original_joint:call("get_Name()")),
                joint=joint and tostring(joint:call("get_Name()"))})
        end
        local s=follow_state
        assert(main==s.main and manager==s.manager and main._CurrentCameraController==s.controller,"镜头控制器变化，停止跟随")
        assert(s.joint:get_Valid(),"跟随骨骼失效")
        s.last_joint=s.joint
        main:call("set_TargetJoint(via.Joint)",s.joint)
        camera_follow_status="镜头跟随中："..camera_mode
    end)
    if not ok then
        local restored,restore_err=restore_follow()
        camera_mode="original"
        camera_follow_status="镜头跟随已停用："..tostring(err)..(not restored and ("；恢复失败："..tostring(restore_err)) or "")
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
        if not c or menu.gameplay_paused() then yaw_state=nil;return end
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
    local errors = passengers.restore_all and passengers.restore_all(d) or {}
    local bone_ok,bone_err=pcall(restore_bone,d)
    if not bone_ok then errors[#errors+1]="骨骼恢复 "..tostring(bone_err) end
    local rot_ok,rot_err=pcall(passengers.restore_rotation,d)
    if not rot_ok then errors[#errors+1]="朝向恢复 "..tostring(rot_err) end
    if d.moved then
        local ok, err = pcall(function()
            if owned_player(d, true) then
                -- Release at the current physical position; never return to the launch point.
                sync_player(d,true)
                d.release_position=vector(d.transform:call("get_Position()"))
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
        or "驾驶已结束，玩家和乘客已在当前位置释放。"
    event("driver_stopped", {reason = reason, errors = errors,release_mode="current_physical_position",player_position=d.release_position})
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
controls.save=function()
    local ok,result=pcall(json.dump_file,settings_path,settings)
    if not ok or result==false then
        menu.save_error="设置保存失败，当前修改尚未写入文件："..tostring(result)
        status=menu.save_error
        return false
    end
    menu.save_error=nil
    return true
end
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
    local c=core()
    if not c or menu.gameplay_paused() or not d.intent or d.pending or now() - d.last_request < 0.35 then return end
    local intent = d.intent
    d.pending = true
    run_once(function()
        if not alive or active ~= d or d.intent ~= intent then d.pending = false; return end
        local c=core()
        if c and menu.gameplay_paused() then d.pending=false;return end -- keep intent until resume
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
    if not c or menu.gameplay_paused() then return end
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
local fall_hook_status="坠落死亡请求拦截：默认开启（驾驶玩家与接管乘客）"
local function install_fall_hook()
    if fall_hook_installed or fall_hook_tried then return end
    fall_hook_tried=true
    local ok,err=pcall(function()
        local td=sdk.find_type_definition("app.Character")
        local method=td and td:get_method("requestFallDead()")
        assert(method and sdk.PreHookResult and sdk.PreHookResult.SKIP_ORIGINAL,"Fall request hook unavailable")
        sdk.hook(method,function(args)
            local d,c=active,core()
            if alive and d and c and not menu.gameplay_paused() and c.properties.player==d.player then
                local ch=sdk.to_managed_object(args[2])
                local member=d.passengers and d.passengers[ch]
                if ch==d.player and d.moved or member and member.moved and member.anchor_target and not member.recovery_pending then
                    fall_hits=fall_hits+1
                    passengers.record_protection(ch==d.player and d or member,"fall",block_player_fall)
                    if block_player_fall then fall_blocked=fall_blocked+1;return sdk.PreHookResult.SKIP_ORIGINAL end
                end
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
            passengers.refresh(true)
            validate_spawn(r)
            local bus = rawget(_G, "DD2_OxcartControl")
            assert(not bus or not bus.owner, "请先结束牛车驾驶")
            local player = r.owner
            local terrain = player:get_field("<AdjustTerrain>k__BackingField")
            local d = {spawn = r, player = player, player_go = player:call("get_GameObject()"),
                transform = player:call("get_Transform()"), context = player:get_field("<PosRotContext>k__BackingField"),
                terrain = terrain, controller = terrain and terrain.MainCharacterController,
                fall = player:get_field("<FallInfo>k__BackingField"), fsm = player_fsm(player),
                passengers={},fall_reset_pending=true,anchor_mode=anchor_mode, gear=1, controls_active=false, mode = "ground", last_request = -math.huge, started = now(), pending = false}
            assert(d.transform and d.context and d.controller and d.fall and d.fsm, "Player interfaces unavailable")
            local ft = d.fsm:get_type_definition()
            assert(ft:get_method("get_Enabled()") and ft:get_method("set_Enabled(System.Boolean)"), "FSM Enabled interface unavailable")
            d.original_fsm = d.fsm:call("get_Enabled()")
            assert(type(d.original_fsm) == "boolean", "Cannot capture player state")
            input = read_pad()
            d.previous_buttons = input.buttons -- holding A/RT on enable is not a fresh press
            active = d
            if settings.camera_auto_yaw then install_yaw_hook() end
            if settings.head_camera~=false then change_camera_mode("griffin") end
            install_fall_hook()
            passengers.install_protection()
            pcall(passengers.capture_probe_refs,d)
            apply_player_freeze(d, settings.freeze_player)
            local joint_ok,joint_err=pcall(discover_joints,d)
            if not joint_ok then event("anchor_joint_probe_error",tostring(joint_err)) end
            prepare_anchor_mode(d,d.anchor_mode)
            if settings.rider_anim~="" then d.pose_pending=settings.rider_anim end
            select_player_target(r)
            if r.result.chara:call("get_IsFlight()") then
                d.controls_active=true; d.control_node="Ch253HoverWaitHoHomingHeight"
                set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            end
            status = "驾驶中：A 仅起飞；RT 3档，LT 逐档减速；RB／LB 分档操作。"
            event("driver_started", {freeze_player = d.freeze_requested,anchor_mode=d.anchor_mode,navigation_radius=settings.navigation_radius,steering_yaw=settings.steering_yaw,steering_pitch=settings.steering_pitch})
        end)
        if not ok then
            if active then stop_driver("Start failed") end
            failed("未能开始驾驶", err)
        end
    end)
end

-- Fixed-radius spherical navigation. Stick sets angles, never accumulates distance.
local function navigation_anchor(d,ch,tr,fx,fz)
    if d.rider_griffin_transform~=tr or not d.rider_head or not d.rider_head:get_Valid() then
        prepare_rider(d)
    end
    assert(d.rider_head and d.rider_head:get_Valid(),"未找到狮鹫头部，不能建立头部球面导航")
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
    if not c then stop_driver("游戏上下文不可用");return end
    if menu.gameplay_paused() then
        if not d.menu_paused then event("driver_menu_paused",true) end
        d.menu_paused=true;d.previous_buttons=input.buttons
        return -- preserve player position, FSM, bones, camera and pending intent
    end
    if d.menu_paused then
        d.menu_paused=nil;d.previous_buttons=input.buttons
        event("driver_menu_resumed",true)
    end
    if now()<d.started then stop_driver("游戏时间上下文变化");return end
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
        d.body_pitch=math.atan(2*(qy*qz-qw*qx),length)*180/math.pi
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
            d.manual_hold=held(pressed,masks.lb) and "landing" or (d.gear==2 and "climb" or "hover")
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
            elseif d.manual_hold=="climb" then node,mode="HoverBackwardTargetHeight","climb"
            elseif d.manual_hold=="hover" then node,mode="Ch253HoverWaitHoHomingHeight","hover"
            elseif d.gear==3 then node,mode="Ch253WrapAroundStartLoop","dash"
            elseif d.gear==2 then
                node,mode="Ch253HoverWaitHoHomingHeight","hover"
                if moving and math.abs(input.x)>math.abs(input.y) then
                    node=input.x<0 and "HoverLateralRTargetHeight" or "HoverLateralLTargetHeight"
                elseif input.y<0 then node,mode="HoverBackward","reverse"
                elseif input.y>0 then node,mode="HoverForward","forward" end
            elseif moving then node,mode="Ch253AirHoverMoveToTarget","fine"
            else node,mode="Ch253HoverWaitHoHomingHeight","hover" end
            if node~=d.control_node then d.control_node=node; set_intent(d,node,mode) end
        end
        local target,neutral,sphere=navigation_anchor(d,ch,tr,fx,fz)
        write_anchor(d,target,neutral)
        dispatch(d)
        d.trace = {navigation_sphere=sphere,neutral_anchor=neutral,anchor_plan=d.anchor_plan,griffin = pos, player = vector(d.transform:call("get_Position()")), target = target,
            physical = vector(d.controller:call("get_Position()")), flight = flying, ground = ground,
            action = tostring(action_name), mode = d.mode, gear=d.gear, manual_hold=d.manual_hold, external_control=d.external_control, bumpers={rb=held(input.buttons,masks.rb),lb=held(input.buttons,masks.lb)}, anchor_mode=d.anchor_mode, stick = {x=input.x,y=input.y}}
        passengers.tick_pose(d)
        passengers.tick(d)
        d.trace.passenger_protection=passengers.protection.counts
        d.trace.seat_orientation=d.orientation_trace
    end)
    if not ok then stop_driver("驾驶检查或位置同步失败"); failed("驾驶已停止", err) end
end

passengers.player_config=function()
    return {anchor=settings.rider_anchor,neck_joint=settings.rider_neck_joint,height=settings.rider_height,
        forward=settings.rider_forward,side=settings.rider_side,anim=settings.rider_anim,lookX=settings.rider_lookX,lookZ=settings.rider_lookZ,
        tilt_follow=settings.rider_tilt_follow,pitch_offset=settings.rider_pitch_offset}
end
passengers.basis=function(d,config,position_only)
    local fx,fz=d.heading.x,d.heading.z
    local strength=finite(config.tilt_follow) and math.max(0,math.min(1,config.tilt_follow)) or 1
    local trim=finite(config.pitch_offset) and math.max(-45,math.min(45,config.pitch_offset)) or 0
    if position_only then trim=0 end -- pose trim changes facing, never the calibrated seat position
    local pitch=math.max(-89,math.min(89,(d.body_pitch or 0)*strength+trim))*math.pi/180
    local cp,sp=math.cos(pitch),math.sin(pitch)
    return {x=fz,y=0,z=-fx},{x=-fx*sp,y=cp,z=-fz*sp},{x=fx*cp,y=sp,z=fz*cp},pitch*180/math.pi
end
passengers.same_rotation=function(a,b)
    if not a or not b then return false end
    local dot,na,nb=0,0,0
    for _,key in ipairs({"x","y","z","w"}) do
        if not finite(a[key]) or not finite(b[key]) then return false end
        dot=dot+a[key]*b[key];na=na+a[key]^2;nb=nb+b[key]^2
    end
    return na>0.00001 and nb>0.00001 and math.abs(dot)/math.sqrt(na*nb)>0.999999
end
passengers.restore_rotation=function(d)
    local s=d.seat_rotation
    if not s then return end
    if owned_player(d,false) and passengers.same_rotation(d.transform:call("get_Rotation()"),s.last) then
        d.transform:call("set_Rotation(via.Quaternion)",s.original)
    end
    d.seat_rotation=nil
end
passengers.orient=function(d,config)
    if d.orientation_failed then return end
    local ok,err=pcall(function()
        local right,up,forward,pitch=passengers.basis(d,config)
        local x=finite(config.lookX) and math.max(-1,math.min(1,config.lookX)) or 0
        local z=finite(config.lookZ) and math.max(-1,math.min(1,config.lookZ)) or 1
        local length=math.sqrt(x*x+z*z)
        if length<0.0001 then x,z,length=0,1,1 end
        local direction={x=(right.x*x+forward.x*z)/length,y=(right.y*x+forward.y*z)/length,z=(right.z*x+forward.z*z)/length}
        local pos=vector(d.transform:call("get_Position()"))
        if not d.seat_rotation then
            local original=d.transform:call("get_Rotation()")
            assert(passengers.same_rotation(original,original),"Seat original rotation invalid")
            d.seat_rotation={original=original,last=original}
        end
        local applied,apply_err=pcall(function()
            d.transform:call("lookAt(via.vec3, via.vec3)",Vector3f.new(pos.x+direction.x,pos.y+direction.y,pos.z+direction.z),Vector3f.new(up.x,up.y,up.z))
        end)
        -- Read back even after a Lua error raised after the native setter wrote.
        d.seat_rotation.last=d.transform:call("get_Rotation()")
        assert(applied,apply_err)
        d.orientation_trace={lookX=x,lookZ=z,pitch=pitch,body_pitch=d.body_pitch or 0,direction=direction,up=up}
    end)
    if not ok then
        d.orientation_failed=true
        event("seat_orientation_error",{group=d.group or "player",slot=d.slot,error=tostring(err)})
        pcall(passengers.restore_rotation,d)
    end
end

-- Seat calculation only. Bone writes use the original Hip experiment callback below.
local function rider_seat(d,config)
    config=config or passengers.player_config()
    local ch=validate_spawn(d.spawn,true)
    assert(ch:call("get_Transform()")==d.rider_griffin_transform,"Griffin anchor changed")
    local base
    if d.rider_head then
        assert(d.rider_head:get_Valid(),"Griffin Head unavailable")
        base=vector(d.rider_head:call("get_Position()"))
    else
        base=vector(d.rider_griffin_transform:call("get_Position()"))
        base={x=base.x+d.heading.x*3,y=base.y+4,z=base.z+d.heading.z*3}
    end
    local selected_name=d.rider_head_name
    if config.anchor=="neck" then
        local neck=d.rider_necks and d.rider_necks[1]
        for _,candidate in ipairs(d.rider_necks or {}) do
            if candidate.name==config.neck_joint then neck=candidate;break end
        end
        if neck and neck.joint:get_Valid() then
            base=vector(neck.joint:call("get_Position()"));selected_name=neck.name
            d.rider_neck_missing=nil
        elseif not d.rider_neck_missing then
            d.rider_neck_missing=true
            status="未找到可用颈部骨骼，座位暂用头部；导航与驾驶继续。"
            event("rider_neck_unavailable",config.neck_joint)
        end
    end
    d.rider_seat_joint_name=selected_name
    local right,up,forward=passengers.basis(d,config,true)
    local seat={x=base.x+forward.x*config.forward+right.x*config.side+up.x*config.height,
        y=base.y+forward.y*config.forward+right.y*config.side+up.y*config.height,
        z=base.z+forward.z*config.forward+right.z*config.side+up.z*config.height}
    return seat,base
end
-- Passenger ownership uses live character instances, never character IDs for control.
passengers.refresh=function(force)
    local c=core()
    if not alive or not c or menu.gameplay_paused() or not c.properties.player then return end
    if not force and now()<(passengers.next_roster or -math.huge) then return end
    passengers.next_roster=now()+0.25
    local ok,party=pcall(c.object.get_party)
    if not ok or type(party)~="table" or party[1]~=c.properties.player then return end
    local seen,pawns={[c.properties.player]=true},{}
    local friends={c.properties.player}
    for _,ch in ipairs(party) do
        if ch and ch:get_Valid() and not seen[ch] then
            seen[ch]=true;pawns[#pawns+1]=ch;friends[#friends+1]=ch
        end
    end
    if force or now()>=(passengers.next_npc or -math.huge) then
        passengers.next_npc=now()+1
        local scan_ok,found=pcall(function()
            local nm=assert(sdk.get_managed_singleton("app.NPCManager"),"NPCManager unavailable")
            local td=sdk.find_type_definition("app.NPCUtil")
            local method=assert(td and td:get_method("isAccompanyPLParty(app.Character)"),"NPC membership unavailable")
            local list,unique={},{}
            local prior={};for _,ch in ipairs(passengers.npcs or {}) do prior[ch]=true end
            for _,holder in pairs(assert(nm.NPCHolderDic,"NPC roster unavailable")) do
                local read_ok,ch=pcall(function() return holder and nm:getCharacter(holder.CharaID) end)
                if read_ok and ch and ch:get_Valid() and not seen[ch] and not unique[ch] then
                    local membership_ok,following=pcall(function() return method:call(nil,ch) end)
                    if membership_ok and following==true or (not membership_ok or type(following)~="boolean") and prior[ch] then
                        unique[ch]=true;list[#list+1]=ch
                    end
                end
            end
            table.sort(list,function(a,b) return a:get_address()<b:get_address() end)
            return list
        end)
        if scan_ok then
            passengers.npcs=found;passengers.npc_status="同行NPC识别正常"
        else
            passengers.npc_status="同行NPC扫描暂不可用，保留上次有效名单"
            if not passengers.npc_error_logged then event("passenger_npc_scan_error",tostring(found));passengers.npc_error_logged=true end
        end
    end
    local companions={}
    for _,ch in ipairs(passengers.npcs or {}) do
        if ch:get_Valid() and not seen[ch] then
            seen[ch]=true;companions[#companions+1]=ch;friends[#friends+1]=ch
        end
    end
    passengers.roster={pawns=pawns,companions=companions}
    for _,r in ipairs(state.spawns) do
        if r.friend and r.owner==c.properties.player then
            local changed=#(r.party or {})~=#friends
            for i,ch in ipairs(friends) do if (r.party or {})[i]~=ch then changed=true end end
            r.party=friends
            if changed then event("friend_roster_refreshed",{pawns=#pawns,companions=#companions}) end
        end
    end
end
passengers.seat=function(group,index,preset)
    local key=preset and group or (group=="pawns" and "pawn_seats" or "companion_seats")
    local store=preset or settings
    if type(store[key])~="table" then store[key]={} end
    local seat=store[key][index]
    local physical=settings.seat_presets and (preset==settings.seat_presets[1] or not preset and settings.seat_index==1)
    if type(seat)~="table" then
        seat={};store[key][index]=seat
        if physical then
            -- New roster slots inherit the former safe point once; each owns its own table.
            for _,field in ipairs({"anchor","neck_joint","height","forward","side","tilt_follow","pitch_offset"}) do seat[field]=settings.seat_presets[1].player[field] end
            seat.enabled=true;seat.anim=""
        end
    end
    if seat.enabled==nil then seat.enabled=true end
    if type(seat.anim)~="string" then seat.anim="" end
    for _,spec in ipairs({{"lookX",0,-1,1},{"lookZ",1,-1,1},{"tilt_follow",physical and 0 or 1,0,1},{"pitch_offset",0,-45,45}}) do
        local key,default,lo,hi=spec[1],spec[2],spec[3],spec[4]
        seat[key]=finite(seat[key]) and math.max(lo,math.min(hi,seat[key])) or default
    end
    seat.anchor=seat.anchor=="head" and "head" or "neck"
    if type(seat.neck_joint)~="string" then seat.neck_joint="" end
    if not finite(seat.height) then seat.height=0.5 end
    if not finite(seat.forward) then seat.forward=-index*1.2-(group=="companions" and 3.6 or 0) end
    if not finite(seat.side) then seat.side=index%2==1 and -0.7 or 0.7 end
    if not physical then
        seat.height=math.max(-5,math.min(15,seat.height))
        seat.forward=math.max(-15,math.min(15,seat.forward))
        seat.side=math.max(-10,math.min(10,seat.side))
    end
    return seat
end
-- Same receiver-scoped damage policy as OJR; no global invincibility fields.
passengers.controlled=function(ch,include_player)
    local d,c=active,core()
    if not alive or not d or not c or c.properties.player~=d.player then return end
    local a=include_player and ch==d.player and d or (d.passengers or {})[ch]
    if a and a.moved and a.anchor_target and not a.recovery_pending and ch:get_Valid() then return a end
end
-- Hooks only aggregate in memory. No disk I/O or per-hit snapshots in native callbacks.
passengers.record_protection=function(a,route,blocked)
    if not a then return end
    local key=(a.group or "player")..":"..(a.slot or 0)..":"..route..(blocked and ":blocked" or ":observed")
    local counts=passengers.protection.counts
    counts[key]=(counts[key] or 0)+1
    a.protection_counts=a.protection_counts or {}
    a.protection_counts[route]=(a.protection_counts[route] or 0)+1
    a.protection_dirty=true
    a.protection_routes=a.protection_routes or {}
    a.protection_routes[route]=blocked and "blocked" or "observed"
end
passengers.each_controlled=function(fn)
    local d=active
    if not d then return end
    local a=passengers.controlled(d.player,true)
    if a then local value=fn(a);if value then return value end end
    for ch in pairs(d.passengers or {}) do
        a=passengers.controlled(ch)
        if a then local value=fn(a);if value then return value end end
    end
end
passengers.receiver=function(go)
    if not go then return end
    return passengers.each_controlled(function(a) if a.player_go==go then return a end end)
end
passengers.component_actor=function(component)
    if not component then return end
    local ch=component["<CachedCharacter>k__BackingField"]
    return ch and passengers.controlled(ch,true)
end
passengers.container_actor=function(container)
    if not container then return end
    -- Exact captured container only. Never walk parent/shared containers or match IDs.
    return passengers.each_controlled(function(a) if a.generate_container==container then return a end end)
end
passengers.snapshot=function(value)
    if type(value)~="table" then return value end
    local result={}
    for key,item in pairs(value) do result[key]=passengers.snapshot(item) end
    return result
end
passengers.capture_probe_refs=function(a)
    local info=a.player:get_field("<GenerateInfo>k__BackingField")
    a.generate_info=info
    a.generate_container=info and info:call("get_Container()") or nil
    a.brine=a.player:get_field("<BrineProcessor>k__BackingField")
end
passengers.probe_tick=function()
    if not active then return end
    passengers.each_controlled(function(a)
        if a.protection_dirty and now()>=(a.protection_log_at or -math.huge) then
            a.protection_log_at=now()+5;a.protection_dirty=false
            local counts,routes={},{}
            for key,value in pairs(a.protection_counts or {}) do counts[key]=value end
            for key,value in pairs(a.protection_routes or {}) do routes[key]=value end
            event("rider_protection",{group=a.group or "player",slot=a.slot,counts=counts,routes=routes},true)
        end
        if now()<(a.health_probe_at or -math.huge) then return end
        a.health_probe_at=now()+0.5
        local ok,value=pcall(function()
            -- Metadata-verified read-only getters; no HP refill or forced resurrection.
            passengers.capture_probe_refs(a)
            local b=a.brine
            return {hp=a.player:call("get_Hp()"),dead=a.player:call("get_IsDead()"),
                fall_dead=a.player:call("get_IsFallDead()"),cause=tostring(a.player:call("get_CauseOfDeath()")),
                brine=b and b["<IsKilledByBrine>k__BackingField"] or false,
                wall_brine=b and b["<IsKilledByWallBrine>k__BackingField"] or false,
                position=vector(a.transform:call("get_Position()")),container_available=a.generate_container~=nil,
                generate_destroyed=a.generate_info and a.generate_info:call("get_IsExecutedDestroy()") or false}
        end)
        if not ok then
            if not a.health_probe_error then event("rider_health_probe_error",{group=a.group or "player",slot=a.slot,error=tostring(value)},true);a.health_probe_error=true end
            return
        end
        local previous=a.health_probe
        a.health_probe=value
        if not previous or previous.hp~=value.hp or previous.dead~=value.dead or previous.fall_dead~=value.fall_dead
            or previous.cause~=value.cause or previous.brine~=value.brine or previous.wall_brine~=value.wall_brine
            or previous.generate_destroyed~=value.generate_destroyed then
            event("rider_health_changed",{group=a.group or "player",slot=a.slot,before=previous,after=value},true)
        end
    end)
end
passengers.install_protection=function()
    if passengers.protection.installed then return end
    passengers.protection.installed=true
    local errors={}
    local function hook(type_name,signature,pre,boolean_result)
        local ok,err=pcall(function()
            local td=sdk.find_type_definition(type_name)
            local m=assert(td and td:get_method(signature),signature.." unavailable")
            local key="griffin_beta_guard_"..type_name..signature
            sdk.hook(m,function(args)
                if boolean_result then thread.get_hook_storage()[key]=false end
                local success,result=pcall(pre,args)
                if success then
                    if boolean_result then thread.get_hook_storage()[key]=result==sdk.PreHookResult.SKIP_ORIGINAL end
                    return result
                end
            end,function(ret)
                if boolean_result and thread.get_hook_storage()[key] then return sdk.to_ptr(0) end
                return ret
            end)
        end)
        if not ok then errors[#errors+1]=tostring(err) end
    end
    for _,signature in ipairs({"damageProc(app.HitController.DamageInfo)","updateDamage(app.HitController.DamageInfo, System.UInt32, System.Single, System.Boolean)"}) do
        hook("app.HitController",signature,function(args)
            if not active then return end
            local info=sdk.to_managed_object(args[3])
            local a=passengers.receiver(info and info["<DamageGameObject>k__BackingField"])
            if a then
                passengers.record_protection(a,signature,passengers.protection.damage)
                if passengers.protection.damage then return sdk.PreHookResult.SKIP_ORIGINAL end
            end
        end,signature=="damageProc(app.HitController.DamageInfo)")
    end
    -- Closer to HP application, covering direct routes that bypass damageProc/updateDamage.
    hook("app.HitController","updateDamageHp(app.HitController.DamageInfo, System.Single, System.Boolean)",function(args)
        if not active then return end
        local a=passengers.component_actor(sdk.to_managed_object(args[2]))
        if a then
            passengers.record_protection(a,"updateDamageHp",passengers.protection.damage)
            if passengers.protection.damage then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end)
    for _,signature in ipairs({"setHp(System.Single, System.Boolean, System.Int32)","setHpValue(System.Single, System.Boolean)"}) do
        hook("app.HitController",signature,function(args)
            if not active then return end
            local a=passengers.component_actor(sdk.to_managed_object(args[2]))
            if a then passengers.record_protection(a,signature,false) end -- healing/setup must pass
        end)
    end
    for _,signature in ipairs({"safeWarp(app.Character, via.Position)","safeWarp(app.Character, via.Position, via.Quaternion)",
        "pawnLost(app.Character, System.Boolean, System.Boolean)","setPawnLostTimer(app.Character)"}) do
        hook("app.PawnManager",signature,function(args)
            if not active then return end
            local a=passengers.controlled(sdk.to_managed_object(args[3]))
            if a and a.group=="pawns" then
                passengers.record_protection(a,signature,passengers.protection.relocation)
                if passengers.protection.relocation then return sdk.PreHookResult.SKIP_ORIGINAL end
            end
        end)
    end
    hook("app.PawnManager","pawnLost(app.InstanceInfo, app.DummyArg_2_0_0_37)",function(args)
        if not active then return end
        local info=sdk.to_managed_object(args[3])
        local a=passengers.container_actor(info and info["<Container>k__BackingField"])
        if a and a.group=="pawns" then
            passengers.record_protection(a,"pawnLost.InstanceInfo",passengers.protection.relocation)
            if passengers.protection.relocation then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end)
    -- Character and CharacterID overloads share their native address in this dump.
    -- Compare the raw pointer first; never cast an unknown CharacterID argument to Character.
    hook("app.PawnManager","onLostCheck(app.Character)",function(args)
        if not active then return end
        for ch,a in pairs(active.passengers or {}) do
            if a.group=="pawns" and args[3]==sdk.to_ptr(ch:get_address()) and passengers.controlled(ch) then
                passengers.record_protection(a,"onLostCheck.Character",passengers.protection.lost_check)
                if passengers.protection.lost_check then return sdk.PreHookResult.SKIP_ORIGINAL end
                return
            end
        end
    end)
    hook("app.GenerateManager","requestDestroy(app.GenerateInfo.GenerateInfoContainer, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean)",function(args)
        if not active then return end
        local a=passengers.container_actor(sdk.to_managed_object(args[3]))
        if a and a.group then
            passengers.record_protection(a,"requestDestroy.exactContainer",passengers.protection.destroy)
            if passengers.protection.destroy then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end,true)
    hook("app.BrineProcessor","onKillCommon()",function(args)
        if not active then return end
        local processor=sdk.to_managed_object(args[2])
        if not processor then return end
        local a=passengers.each_controlled(function(actor) if actor.brine==processor then return actor end end)
        if a then passengers.record_protection(a,"BrineProcessor.onKillCommon",false) end
    end)
    -- Observe execution/notification only. Never skip destructors or destruction callbacks.
    hook("app.GenerateInfo","applyDestroy()",function(args)
        if not active then return end
        local info=sdk.to_managed_object(args[2])
        if not info then return end
        local a=passengers.each_controlled(function(actor) if actor.generate_info==info then return actor end end)
        if a then passengers.record_protection(a,"GenerateInfo.applyDestroy",false) end
    end)
    hook("app.Character","onDestroyCharacterByGenerator()",function(args)
        if not active then return end
        local a=passengers.controlled(sdk.to_managed_object(args[2]),true)
        if a then passengers.record_protection(a,"Character.onDestroyCharacterByGenerator",false) end
    end)
    passengers.protection.status=#errors==0 and "驾驶角色扣血／随从丢失保护及根因探针已安装" or "部分保护／探针不可用："..table.concat(errors,"; ")
    event("passenger_protection_installed",{errors=errors})
end
passengers.play_pose=function(a,node)
    assert(active and alive and not menu.gameplay_paused(),"请开始驾驶并关闭暂停菜单后播放")
    assert(owned_player(a,false) and player_fsm(a.player)==a.fsm,"Animation actor binding changed")
    node=type(node)=="string" and node:match("^%s*(.-)%s*$") or ""
    if node=="" then return end
    local manager=assert(a.player:call("get_ActionManager()"),"Actor ActionManager unavailable")
    a.fsm_touched=true
    a.pose_freeze_frame=passengers.frame+1
    a.fsm:call("set_Enabled(System.Boolean)",true)
    local ok,err=pcall(function()
        manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",1,node,0)
    end)
    if not ok then
        local desired=false
        if not a.group and not settings.freeze_player then desired=a.original_fsm end
        a.fsm:call("set_Enabled(System.Boolean)",desired)
        a.pose_freeze_frame=nil;error(err)
    end
    a.fall_reset_pending=true
    event("seat_animation_requested",{group=a.group or "player",slot=a.slot,node=node})
end
passengers.tick_pose=function(a)
    if a.pose_freeze_frame and passengers.frame>=a.pose_freeze_frame then
        local desired=false
        if not a.group and not settings.freeze_player then desired=a.original_fsm end
        a.fsm:call("set_Enabled(System.Boolean)",desired)
        assert(a.fsm:call("get_Enabled()")==desired,"Animation FSM freeze readback mismatch")
        a.pose_freeze_frame=nil
    end
    if a.pose_pending~=nil then
        local node=a.pose_pending;a.pose_pending=nil
        local ok,err=pcall(passengers.play_pose,a,node)
        if not ok then event("seat_animation_error",{group=a.group or "player",slot=a.slot,error=tostring(err)});status="动画请求失败："..tostring(err) end
    end
end

passengers.visual_seat=function(group,index)
    if settings.seat_index==1 then return passengers.seat(group,index,settings.seat_presets[1]) end
    return passengers.seat(group,index)
end
passengers.restore_one=function(a)
    if not a.player:get_Valid() then
        a.bones_applied=nil;a.moved=false;a.fsm_touched=false;return
    end
    assert(owned_player(a,false),"Passenger binding changed; retained for recovery")
    restore_bone(a)
    passengers.restore_rotation(a)
    local pose_enabled=a.pose_freeze_frame~=nil
    a.pose_pending=nil
    if a.moved then
        if core() and core().properties.player==a.owner then
            -- Hip display is restored above; keep the current physical location.
            sync_player(a,true)
        end
        a.moved=false
    end
    if a.fsm_touched then
        assert(player_fsm(a.player)==a.fsm,"Passenger FSM changed; retained for recovery")
        -- Preserve third-party re-enabling, except the explicit pose window we own.
        if a.fsm:call("get_Enabled()")==false or pose_enabled then a.fsm:call("set_Enabled(System.Boolean)",a.original_fsm) end
        a.fsm_touched=false
    end
    a.pose_freeze_frame=nil
end
passengers.restore_all=function(d)
    local errors={}
    for ch,a in pairs(d.passengers or {}) do
        local ok,err=pcall(passengers.restore_one,a)
        if ok then d.passengers[ch]=nil else errors[#errors+1]=tostring(err) end
    end
    return errors
end
passengers.bind=function(d,ch,group,index)
    assert(ch:get_Valid(),"Passenger unloaded")
    local terrain=ch:get_field("<AdjustTerrain>k__BackingField")
    local a={player=ch,owner=d.player,spawn=d.spawn,fall_reset_pending=true,player_go=ch:call("get_GameObject()"),
        transform=ch:call("get_Transform()"),context=ch:get_field("<PosRotContext>k__BackingField"),terrain=terrain,
        controller=terrain and terrain.MainCharacterController,fall=ch:get_field("<FallInfo>k__BackingField"),
        fsm=player_fsm(ch),group=group,slot=index,anchor_mode="rider"}
    assert(a.player_go and a.transform and a.context and a.controller and a.fall and a.fsm,"Passenger interfaces unavailable")
    assert(owned_player(a,false),"Passenger interface ownership mismatch")
    a.original_fsm=a.fsm:call("get_Enabled()")
    assert(type(a.original_fsm)=="boolean","Passenger original state unavailable")
    discover_joints(a)
    assert(a.hip_joint and a.hip_joint:get_Valid(),"Passenger Hip unavailable")
    a.pose_pending=passengers.visual_seat(group,index).anim
    pcall(passengers.capture_probe_refs,a) -- ready before the first anchored game tick
    d.passengers[ch]=a -- recovery registered before the first native mutation
    event("passenger_bound",{group=group,slot=index,instance=tostring(ch)})
    return a
end
passengers.prepare_rig=function(a,d)
    a.heading=d.heading;a.body_pitch=d.body_pitch;a.rider_griffin_transform=d.rider_griffin_transform
    a.rider_head=d.rider_head;a.rider_head_name=d.rider_head_name;a.rider_necks=d.rider_necks
end
passengers.record_release_context=function(a,reason,valid)
    local value={group=a.group,slot=a.slot,instance=tostring(a.player),reason=reason,valid=valid,
        health=a.health_probe,protection=passengers.snapshot(a.protection_counts or {})}
    if valid then
        local ok,detail=pcall(function()
            local info=a.player:get_field("<GenerateInfo>k__BackingField")
            return {hp=a.player:call("get_Hp()"),dead=a.player:call("get_IsDead()"),
                gameobject_valid=a.player_go:get_Valid(),interfaces_match=owned_player(a,false),
                generate_destroyed=info and info:call("get_IsExecutedDestroy()") or false,
                generate_info_unchanged=info==a.generate_info,
                position=vector(a.transform:call("get_Position()"))}
        end)
        if ok then value.current=detail else value.read_error=tostring(detail) end
    end
    event("passenger_release_context",value)
end
passengers.tick=function(d)
    d.passengers=d.passengers or {}
    passengers.last_error=nil
    local wanted={}
    for _,group in ipairs({"pawns","companions"}) do
        for i,ch in ipairs((passengers.roster or {})[group] or {}) do
            local seat=passengers.seat(group,i)
            if seat.enabled and ch:get_Valid() then wanted[ch]={group=group,slot=i} end
        end
    end
    for ch,a in pairs(d.passengers) do
        local valid=ch:get_Valid()
        if not wanted[ch] or not valid then
            local in_roster=false
            for _,member in ipairs((passengers.roster or {})[a.group] or {}) do if member==ch then in_roster=true end end
            local reason=not valid and "invalid_instance" or (in_roster and "seat_disabled" or "absent_from_engine_roster")
            passengers.record_release_context(a,reason,valid)
            if not valid then event("passenger_unloaded",{group=a.group,slot=a.slot,instance=tostring(ch),protection=a.protection_counts,health=a.health_probe}) end
            a.anchor_target=nil
            local ok,err=pcall(passengers.restore_one,a)
            if ok then d.passengers[ch]=nil;event("passenger_released",{group=a.group,slot=a.slot})
            elseif not a.restore_error_logged then event("passenger_restore_error",tostring(err));a.restore_error_logged=true end
        end
    end
    d.passenger_trace={}
    for ch,slot in pairs(wanted) do
        local ok,err=pcall(function()
            local a=d.passengers[ch] or passengers.bind(d,ch,slot.group,slot.slot)
            assert(not a.recovery_pending,"Passenger recovery pending")
            assert(owned_player(a,false) and player_fsm(ch)==a.fsm,"Passenger binding changed")
            assert(a.hip_joint and a.hip_joint:get_Valid(),"Passenger Hip unavailable")
            a.group=slot.group;a.slot=slot.slot
            passengers.prepare_rig(a,d)
            restore_bone(a)
            local current=a.fsm:call("get_Enabled()")
            if current~=false and not a.pose_freeze_frame then
                a.fsm_touched=true;a.fsm:call("set_Enabled(System.Boolean)",false)
                assert(a.fsm:call("get_Enabled()")==false,"Passenger freeze readback mismatch")
            end
            -- Each passenger always uses its own slot in preset [1] for real position.
            local physical=rider_seat(a,passengers.seat(a.group,a.slot,settings.seat_presets[1]))
            a.moved=true;a.anchor_target=physical;a.neutral_anchor=physical
            a.transform:call("set_Position(via.vec3)",Vector3f.new(physical.x,physical.y,physical.z))
            passengers.orient(a,passengers.visual_seat(a.group,a.slot))
            sync_player(a)
            passengers.tick_pose(a)
            d.passenger_trace[#d.passenger_trace+1]={group=a.group,slot=a.slot,physical=physical,fsm_enabled=a.fsm:call("get_Enabled()"),protection=a.protection_counts,health=a.health_probe,orientation=a.orientation_trace,orientation_failed=a.orientation_failed or false}
        end)
        if not ok then
            passengers.last_error=slot.group.." "..slot.slot..": "..tostring(err)
            local key=slot.group..":"..slot.slot
            passengers.errors=passengers.errors or {}
            if now()>=(passengers.errors[key] or -math.huge) then
                passengers.errors[key]=now()+5;event("passenger_control_error",{group=slot.group,slot=slot.slot,error=tostring(err)})
            end
            -- A partial write must recover before retrying. Keep failures for stop/reset recovery.
            local a=d.passengers[ch]
            if a then
                a.anchor_target=nil;a.recovery_pending=true
                local restored=pcall(passengers.restore_one,a)
                if restored then d.passengers[ch]=nil end
            end
        end
    end
    if d.trace then d.trace.passengers=d.passenger_trace end
end
passengers.pre=function()
    if not alive or not active or not menu.visual_allowed() then return end
    for _,a in pairs(active.passengers or {}) do
        local ok,err=pcall(function()
            restore_bone(a)
            if a.anchor_target then passengers.orient(a,passengers.visual_seat(a.group,a.slot)) end
        end)
        if not ok then event("passenger_bone_restore_error",tostring(err)) end
    end
end
passengers.post=function()
    local d=active
    if not alive or not d or not menu.visual_allowed() then return end
    for _,a in pairs(d.passengers or {}) do
        if a.anchor_target then
            local ok,err=pcall(function()
                assert(owned_player(a,false),"Passenger changed")
                restore_bone(a)
                local actor=vector(a.transform:call("get_Position()"))
                local seat=rider_seat(a,passengers.visual_seat(a.group,a.slot))
                local items={}
                for _,spec in ipairs({{joint=a.root_joint,key="root"},{joint=a.hip_joint,key="hip"}}) do
                    local joint=spec.joint
                    if joint and joint:get_Valid() then
                        local original=vector(joint:call("get_Position()"))
                        local anchor=spec.key=="hip" and seat or a.neutral_anchor
                        items[#items+1]={joint=joint,original=original,
                            written={x=anchor.x+original.x-actor.x,y=anchor.y+original.y-actor.y,z=anchor.z+original.z-actor.z}}
                    end
                end
                a.bones_applied=items
                for _,item in ipairs(items) do item.joint:call("set_Position(via.vec3)",Vector3f.new(item.written.x,item.written.y,item.written.z)) end
            end)
            if not ok and not a.pose_error_logged then event("passenger_pose_error",tostring(err));a.pose_error_logged=true end
        end
    end
end

local function spawn()
    if queued or #state.spawns > 0 or state.recovery then return end
    settings.freeze_player=true;block_player_fall=true
    passengers.protection.damage=true;passengers.protection.relocation=true
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
            assert(c.properties.player and not menu.gameplay_paused(), "请进入游戏")
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
    if not c or menu.gameplay_paused() then return end
    passengers.probe_tick()
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
        active.trace.rider_health=active.health_probe
        active.trace.target_probe = read_target_probe(active)
        local positions_ok,positions=pcall(anchor_positions,active)
        active.trace.anchor_positions=positions_ok and positions or {error=tostring(positions)}
        local sphere=active.trace.navigation_sphere
        if sphere and positions_ok then
            local p,h=positions.transform,sphere.center
            sphere.sampled_player_distance=math.sqrt((p.x-h.x)^2+(p.y-h.y)^2+(p.z-h.z)^2)
        end
        rotate()
        if #journal.samples < 650 then journal.samples[#journal.samples+1] = {time=now(), data=passengers.snapshot(active.trace)} end
    end
    if active and now()-last_flush >= 2 then flush() end
end)
re.on_application_entry("UpdateHID",function()
    if not alive then return end
    local ok,result=pcall(read_pad)
    if not ok then
        if core() and menu.gameplay_paused() then return end
        if active then stop_driver("输入读取失败");failed("输入读取失败",result) end
        return
    end
    input=result
    if core() and menu.gameplay_paused() then
        if active then active.previous_buttons=result.buttons end
        return -- menu navigation must not invoke gameplay hotkeys
    end
    if active and active.menu_paused then
        active.previous_buttons=result.buttons
        return -- seed menu-held inputs before the first resumed behavior update
    end
    if controls.capture or controls.release_gate then return end
    for _,name in ipairs({"stop","delete","spawn","start","listen","preset_next"}) do
        if result.edges[name] then
            if name=="spawn" then spawn()
            elseif name=="start" then start_driver()
            elseif name=="stop" then menu.stop()
            elseif name=="delete" then menu.delete()
            elseif name=="listen" then menu.listen()
            elseif name=="preset_next" then menu.next_preset() end
            break
        end
    end
end)

re.on_pre_application_entry("UpdateBehavior",function() passengers.frame=passengers.frame+1;if menu.apply_pending_preset then menu.apply_pending_preset() end;passengers.refresh();tick_skip_think();tick_driver();tick_camera_follow() end)
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
        if seat then
            d.rider_trace={phase="UpdateJointExpression",mode="rider",head_joint=d.rider_head_name,seat_joint=d.rider_seat_joint_name,seat_anchor=settings.rider_anchor,
                fallback=not d.rider_head,head=head,seat=seat,
                hip=vector(d.hip_joint:call("get_Position()")),
                root=d.root_joint and vector(d.root_joint:call("get_Position()")) or nil,
                transform=actor}
            if d.trace then d.trace.rider=d.rider_trace end
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
re.on_pre_application_entry("UpdateJointExpression",function()
    passengers.pre();menu.player_visual_pre()
end)
re.on_application_entry("UpdateJointExpression",function()
    passengers.post();menu.player_visual_post()
end)
re.on_pre_application_entry("PrepareRendering",function()
    if not menu.visual_allowed() then return end
    -- Menu transitions can replace the pose before NickCore reports pause. Keep
    -- this fallback active every rendered frame, using the same Hip restore path.
    -- No physics, AI, input or FSM updates here; normal menu preset changes wait.
    menu.apply_pending_preset()
    menu.rendering_visual=true
    passengers.pre();menu.player_visual_pre()
    passengers.post();menu.player_visual_post()
    menu.rendering_visual=false
end)
re.on_application_entry("PrepareRendering",function()
    if not core() or menu.gameplay_paused() then return end
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
-- OJR preset contract: edit the persisted layout itself, never a second draft.
menu.snapshot=function(name,source)
    local preset=menu.clone(source or {})
    preset.schema=5;preset.name=name
    preset.player=preset.player or {}
    for k,v in pairs(passengers.player_config()) do preset.player[k]=v end
    preset.camera=preset.camera or {};preset.camera.distance=settings.distance;preset.camera.fov=settings.fov
    preset.pawns=menu.clone(settings.pawn_seats or preset.pawns or {})
    preset.companions=menu.clone(settings.companion_seats or preset.companions or {})
    return preset
end
settings.pawn_seats=menu.clone(loaded_settings and loaded_settings.pawn_seats or {})
settings.companion_seats=menu.clone(loaded_settings and loaded_settings.companion_seats or {})
settings.seat_presets={}
if loaded_settings and type(loaded_settings.seat_presets)=="table" then
    for _,preset in ipairs(loaded_settings.seat_presets) do
        if type(preset)=="table" and type(preset.name)=="string" and type(preset.player)=="table"
            and finite(preset.player.height) and finite(preset.player.forward) and finite(preset.player.side) then
            settings.seat_presets[#settings.seat_presets+1]=menu.clone(preset)
        end
    end
end
if #settings.seat_presets==0 then settings.seat_presets[1]=menu.snapshot("实体位置校正") end
if #settings.seat_presets==1 then
    settings.seat_presets[2]=menu.clone(settings.seat_presets[1]);settings.seat_presets[2].name="默认乘坐座位"
end
settings.seat_index=math.max(2,math.min(#settings.seat_presets,math.floor(tonumber(loaded_settings and loaded_settings.seat_index) or 2)))
-- Recover legacy edits that were written only to the runtime mirrors, once.
if loaded_settings and loaded_settings.preset_store_revision~=1 and loaded_settings.seat_index~=1 then
    local preset=settings.seat_presets[settings.seat_index]
    for key,value in pairs(passengers.player_config()) do
        if loaded_settings["rider_"..key]~=nil then preset.player[key]=value end
    end
    preset.camera=type(preset.camera)=="table" and preset.camera or {}
    for _,key in ipairs({"distance","fov"}) do if loaded_settings[key]~=nil then preset.camera[key]=settings[key] end end
    for _,entry in ipairs({{"pawn_seats","pawns"},{"companion_seats","companions"}}) do
        if type(loaded_settings[entry[1]])=="table" then preset[entry[2]]=menu.clone(loaded_settings[entry[1]]) end
    end
end
if not finite(settings.seat_presets[1].player.tilt_follow) then settings.seat_presets[1].player.tilt_follow=0 end
if not finite(settings.seat_presets[1].player.pitch_offset) then settings.seat_presets[1].player.pitch_offset=0 end
menu.migrate_physical=function()
    if loaded_settings and loaded_settings.physical_seat_revision==1 then return end
    local preset=settings.seat_presets[1]
    for _,group in ipairs({"pawns","companions"}) do
        local count=group=="pawns" and 3 or 0
        for _,entry in ipairs(settings.seat_presets) do count=math.max(count,type(entry[group])=="table" and #entry[group] or 0) end
        preset[group]=type(preset[group])=="table" and preset[group] or {}
        for i=1,count do
            local seat=menu.clone(preset[group][i] or {})
            for _,field in ipairs({"anchor","neck_joint","height","forward","side","tilt_follow","pitch_offset"}) do seat[field]=preset.player[field] end
            seat.enabled=true;seat.anim="";preset[group][i]=seat
        end
    end
end
menu.migrate_physical()
settings.physical_seat_revision=1
settings.preset_store_revision=1
menu.show_physical=false
menu.selected_index=settings.seat_index
menu.last_normal=settings.seat_index
menu.reindex=function()
    for i,preset in ipairs(settings.seat_presets) do
        preset.name="["..i.."] "..preset.name:gsub("^%[%d+%]%s*","")
        preset.enabled=true
        if type(preset.pawns)~="table" then preset.pawns={} end
        if type(preset.companions)~="table" then preset.companions={} end
    end
end
menu.pull_values=function(index)
    local preset=settings.seat_presets[index]
    local player=preset.player
    player.anchor=player.anchor=="neck" and "neck" or "head"
    player.neck_joint=type(player.neck_joint)=="string" and player.neck_joint or ""
    player.anim=type(player.anim)=="string" and player.anim or ""
    for _,spec in ipairs({{"height",1,-5,15},{"forward",0,-15,15},{"side",0,-10,10},
        {"lookX",0,-1,1},{"lookZ",1,-1,1},{"tilt_follow",index==1 and 0 or 1,0,1},{"pitch_offset",0,-45,45}}) do
        local value=player[spec[1]]
        local coordinate=spec[1]=="height" or spec[1]=="forward" or spec[1]=="side"
        player[spec[1]]=finite(value) and (index==1 and coordinate and value or math.max(spec[3],math.min(spec[4],value))) or spec[2]
    end
    for key,value in pairs(player) do
        if ({anchor=true,neck_joint=true,anim=true,height=true,forward=true,side=true,lookX=true,lookZ=true,tilt_follow=true,pitch_offset=true})[key] then
            settings["rider_"..key]=value
        end
    end
    -- The current layout controls visible seats and carry options, including debug [1].
    settings.pawn_seats=preset.pawns;settings.companion_seats=preset.companions
    if index~=1 then
        preset.camera=type(preset.camera)=="table" and preset.camera or {}
        for _,spec in ipairs({{"distance",30,0,80},{"fov",90,40,120}}) do
            local value=preset.camera[spec[1]]
            preset.camera[spec[1]]=finite(value) and math.max(spec[3],math.min(spec[4],value)) or spec[2]
            settings[spec[1]]=preset.camera[spec[1]]
        end
    end
end
menu.persist_preset=function(preset)
    for index,entry in ipairs(settings.seat_presets) do
        if entry==preset and index==settings.seat_index then menu.pull_values(index);break end
    end
    menu.reindex()
    controls.save()
end
menu.apply_preset=function(index)
    local preset=settings.seat_presets[index]
    if not preset or index==1 and not menu.show_physical then return end
    if index~=1 then menu.last_normal=index end
    settings.seat_index=index;menu.selected_index=index
    menu.pull_values(index)
    if active then
        active.fall_reset_pending=true;active.pose_pending=settings.rider_anim
        for _,a in pairs(active.passengers or {}) do
            a.fall_reset_pending=true;a.pose_pending=passengers.visual_seat(a.group,a.slot).anim
        end
    end
    controls.save();status="当前生效预设："..preset.name
end
menu.apply_pending_preset=function()
    local preset=menu.pending_preset
    if not preset or not core() or menu.gameplay_paused() and not menu.photo_active() then return end
    menu.pending_preset=nil
    for index,entry in ipairs(settings.seat_presets) do if entry==preset then menu.apply_preset(index);return end end
end
menu.queue_preset=function(index)
    local preset=settings.seat_presets[index]
    if not preset or index==1 and not menu.show_physical then return end
    menu.selected_index=index;menu.confirm_delete=nil;menu.pending_preset=preset
    if type(run_once)=="function" then run_once(function() if alive then menu.apply_pending_preset() end end) end
end
menu.next_preset=function()
    local index=settings.seat_index+1
    menu.queue_preset(index>#settings.seat_presets and 2 or index)
end
menu.reindex();menu.pull_values(settings.seat_index)
-- No settings file is overwritten during deployment. This migration runs on script load.
if loaded_settings then controls.save() end

menu.edit_facing=function(seat,id)
    local dirty=false
    for _,spec in ipairs({{"lookX","Look At X（右正／左负）",0,-1,1},
        {"lookZ","Look At Z（前正／后负）",1,-1,1},
        {"pitch_offset","角色倾斜修正角（度）",0,-45,45}}) do
        local key=spec[1]
        if not finite(seat[key]) then seat[key]=spec[3] end
        local changed,value=imgui.slider_float(spec[2].."###"..id..key,seat[key],spec[4],spec[5])
        if changed and finite(value) then seat[key]=math.max(spec[4],math.min(spec[5],value));dirty=true end
    end
    local changed,value=menu.toggle("角色身体倾斜跟随###"..id.."Tilt",(seat.tilt_follow or 1)>0)
    if changed then seat.tilt_follow=value and 1 or 0;dirty=true end
    imgui.text("Look At X左右面向、Z前后面向；(0, 1)朝狮鹫前方。倾斜仅作用于角色身体。")
    return dirty
end
menu.animation=function(seat,id,preset)
    if type(seat.anim)~="string" then seat.anim="" end
    if type(imgui.input_text)=="function" then
        local changed,value=imgui.input_text("动作名称###"..id.."Anim",seat.anim)
        if changed and type(value)=="string" then seat.anim=value:sub(1,160);menu.persist_preset(preset) end
    end
    if beta_button("播放动画###"..id.."Play") then
        local d=active
        local a=id=="BetaPlayerPose" and d or nil
        for _,member in pairs(d and d.passengers or {}) do
            if id=="BetaSeat"..member.group..member.slot then a=member end
        end
        if not a then status="请先开始驾驶并启用该座位。"
        else a.pose_pending=seat.anim end
    end
end
menu.number=function(label,value,step,lo,hi)
    if type(imgui.drag_float)=="function" then return imgui.drag_float(label,value,step,lo,hi) end
    return imgui.slider_float(label,value,lo,hi)
end
menu.edit_seat=function(seat,id,preset)
    local dirty=false
    if type(imgui.combo)=="function" then
        local changed,index=imgui.combo("骨骼锚点###"..id.."Anchor",seat.anchor=="neck" and 2 or 1,{"头部","颈部"})
        if changed then seat.anchor=index==2 and "neck" or "head";dirty=true end
        if seat.anchor=="neck" then
            local names={"自动（首个颈部骨骼）"};local selected=1
            for _,entry in ipairs(active and active.rider_necks or {}) do
                names[#names+1]=entry.name;if entry.name==seat.neck_joint then selected=#names end
            end
            local changed,index=imgui.combo("颈部骨骼###"..id.."Neck",selected,names)
            if changed then seat.neck_joint=index==1 and "" or names[index];dirty=true end
        end
    end
    for _,spec in ipairs({{"side","X（左右）",-10,10},{"forward","Z（前后）",-15,15},{"height","Y（高度）",-5,15}}) do
        if not finite(seat[spec[1]]) then seat[spec[1]]=0 end
        if preset==settings.seat_presets[1] then spec[3],spec[4]=-100,100 end
        local changed,value=menu.number(spec[2].."###"..id..spec[1],seat[spec[1]],0.05,spec[3],spec[4])
        if changed and finite(value) then seat[spec[1]]=math.max(spec[3],math.min(spec[4],value));dirty=true end
    end
    if menu.edit_facing(seat,id=="BetaPlayerSeat" and "BetaPlayerFacing" or id) then dirty=true end
    if dirty then
        menu.persist_preset(preset)
        if active then
            if id=="BetaPlayerSeat" then active.fall_reset_pending=true end
            for _,a in pairs(active.passengers or {}) do
                if id=="BetaSeat"..a.group..a.slot then a.fall_reset_pending=true end
            end
        end
    end
    menu.animation(seat,id=="BetaPlayerSeat" and "BetaPlayerPose" or id,preset)
end
menu.passenger_seats=function(preset)
    for _,group in ipairs({"pawns","companions"}) do
        local roster=(passengers.roster or {})[group] or {}
        local count=math.max(group=="pawns" and 3 or 0,#roster,#preset[group])
        for i=1,count do
            if imgui.tree_node((group=="pawns" and "随从 " or "同伴NPC ")..i.."###BetaSeat"..group..i) then
                local seat=passengers.seat(group,i,preset)
                local changed,value=menu.toggle("自动携带／冻结FSM###BetaSeatEnabled"..group..i,seat.enabled~=false)
                if changed then seat.enabled=value;menu.persist_preset(preset) end
                menu.edit_seat(seat,"BetaSeat"..group..i,preset)
                imgui.tree_pop()
            end
        end
    end
end
menu.presets=function()
    imgui.text("当前生效预设："..settings.seat_presets[settings.seat_index].name)
    if imgui.separator then imgui.separator() end
    local first=menu.show_physical and 1 or 2
    local names={};for i=first,#settings.seat_presets do names[#names+1]=settings.seat_presets[i].name end
    menu.selected_index=math.max(first,math.min(#settings.seat_presets,menu.selected_index or settings.seat_index))
    if type(imgui.combo)=="function" then
        local changed,index=imgui.combo("当前布局###BetaPresetSelect",menu.selected_index-first+1,names)
        if changed and names[index] then menu.queue_preset(index+first-1) end
    end
    local index=menu.selected_index
    local preset=settings.seat_presets[index]
    if index~=1 then
        if #settings.seat_presets<15 and beta_button("＋新增预设（最多15项）###BetaPresetNew") then
            local clone=menu.clone(preset)
            clone.name="狮鹫座位 - "..(#settings.seat_presets+1)
            settings.seat_presets[#settings.seat_presets+1]=clone
            menu.reindex();controls.save();menu.queue_preset(#settings.seat_presets)
            return
        end
        if #settings.seat_presets>2 then
            if imgui.same_line then imgui.same_line() end
            if menu.confirm_delete~=preset then
                if beta_button("删除预设###BetaPresetDelete") then menu.confirm_delete=preset end
            else
                if beta_button("确认删除###BetaPresetConfirmDelete") then
                    table.remove(settings.seat_presets,index)
                    if settings.seat_index>index then settings.seat_index=settings.seat_index-1
                    elseif settings.seat_index==index then settings.seat_index=math.max(2,math.min(index,#settings.seat_presets)) end
                    menu.last_normal=math.max(2,math.min(menu.last_normal or 2,#settings.seat_presets))
                    menu.selected_index=math.max(2,math.min(index,#settings.seat_presets));menu.confirm_delete=nil
                    menu.reindex();menu.pull_values(settings.seat_index);controls.save();menu.queue_preset(settings.seat_index)
                    return
                end
                if imgui.same_line then imgui.same_line() end
                if beta_button("取消###BetaPresetCancelDelete") then menu.confirm_delete=nil end
            end
        end
        if type(imgui.input_text)=="function" then
            local changed,name=imgui.input_text("预设名称###BetaPresetName",preset.name)
            if changed and type(name)=="string" and name:match("%S") then preset.name=name:sub(1,120);menu.persist_preset(preset) end
        end
    else imgui.text("调试[1]：各随从／同伴的实体与当前Hip使用各自参数；玩家参数只控制玩家Hip。") end
    if imgui.tree_node("玩家参数###BetaPlayerParameters") then
        menu.edit_seat(preset.player,"BetaPlayerSeat",preset)
        if index~=1 then
            preset.camera=type(preset.camera)=="table" and preset.camera or {distance=settings.distance,fov=settings.fov}
            for _,spec in ipairs({{"distance","相机距离偏移",0,80},{"fov","FOV",40,120}}) do
                local changed,value=menu.number(spec[2].."###BetaPresetCamera"..spec[1],preset.camera[spec[1]],0.1,spec[3],spec[4])
                if changed and finite(value) then preset.camera[spec[1]]=math.max(spec[3],math.min(spec[4],value));menu.persist_preset(preset) end
            end
        end
        imgui.tree_pop()
    end
    menu.passenger_seats(preset)
    imgui.text("与牛车MOD相同：调整立即保存；新增复制当前布局，删除需确认。")
    if menu.pending_preset then imgui.text("布局切换已排队，继续游戏或进入照片模式后应用。") end
    if active and menu.photo_active() then imgui.text("照片模式：保持座位显示；飞行输入和动画请求暂停。") end
    if menu.save_error then imgui.text(menu.save_error) end
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
    if menu.save_error then imgui.text(menu.save_error) end
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
        menu.slider("steering_yaw","左右转向灵敏度（最大角度）",1,85)
        menu.slider("steering_pitch","摇杆上下微调（最大角度）",1,80)
        menu.slider("bumper_pitch","RB／LB 升降角度（最高59°）",1,59)
        menu.slider("navigation_radius","头部导航半径（米）",2,30)
        menu.slider("navigation_height","球面回中高度（米）",-settings.navigation_radius*0.9,settings.navigation_radius*0.9)
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
        menu.slider("camera_yaw_speed","镜头跟随速度（度／秒）",15,360)
        menu.slider("camera_manual_threshold","右摇杆接管阈值",0.25,0.95)
        imgui.tree_pop()
    end
    if imgui.tree_node("座位预设") then
        menu.presets()
        imgui.tree_pop()
    end
    if imgui.tree_node("按键设置") then menu.bindings();imgui.tree_pop() end
    if imgui.tree_node("DEBUG") then
        local changed,value=menu.toggle("显示预设[1]（仅手动调试）",menu.show_physical)
        if changed then
            menu.show_physical=value
            if not value then
                if settings.seat_index==1 or menu.selected_index==1 then menu.queue_preset(menu.last_normal or 2) end
                if menu.pending_preset==settings.seat_presets[1] then menu.pending_preset=nil end
            end
        end
        if menu.show_physical then imgui.text("在座位预设的当前布局中选择[1]，编辑实体位置。") end
        changed,value=menu.toggle("驾驶玩家／乘客扣血拦截",passengers.protection.damage)
        if changed then passengers.protection.damage=value end
        changed,value=menu.toggle("阻止落座乘客自动传送／丢失",passengers.protection.relocation)
        if changed then passengers.protection.relocation=value end
        changed,value=menu.toggle("跳过随从丢失检查",passengers.protection.lost_check)
        if changed then passengers.protection.lost_check=value;event("lost_check_guard_mode",value) end
        changed,value=menu.toggle("阻止乘客被生成器销毁",passengers.protection.destroy)
        if changed then passengers.protection.destroy=value;event("destroy_guard_mode",value) end
        imgui.text("两项额外拦截用于对照；日志自动记录，结束驾驶后放行。")
        imgui.text(passengers.protection.status or "乘客保护：开始驾驶后安装")
        if imgui.tree_node("运行诊断") then
            for key,count in pairs(passengers.protection.counts) do imgui.text(key.."："..count) end
            imgui.tree_pop()
        end
        if beta_button((skip_think_enabled and "关闭跳过狮鹫思考" or "开启跳过狮鹫思考").."###BetaThinkToggle") then set_skip_think(not skip_think_enabled) end
        imgui.text(skip_think_status)
        local changed,value=menu.toggle("拦截驾驶角色坠落死亡请求",block_player_fall)
        if changed then block_player_fall=value;if active then install_fall_hook() end;event("fall_request_block_mode",value) end
        changed,value=menu.toggle("冻结玩家 FSM",settings.freeze_player)
        if changed then change_player_freeze(value) end
        imgui.text("坠落请求："..fall_hits.."；拦截："..fall_blocked)
        imgui.text(yaw_status);imgui.text(camera_follow_status)
        if active and active.trace then imgui.text("当前动作："..active.trace.action) end
        imgui.text("LB／RB超过59°时曾出现黑屏；是否由过快坠落引起尚未确认。")
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
