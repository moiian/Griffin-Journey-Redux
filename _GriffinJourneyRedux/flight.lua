-- Griffin Journey Redux: flight
return function(ctx)
local _ENV=ctx
function start_driver()
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
            assert(ai_takeover:tick(d),"方向6组件恢复失败")
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
function navigation_anchor(d,ch,tr,fx,fz)
    if d.rider_griffin_transform~=tr or not d.rider_head or not d.rider_head:get_Valid() then
        prepare_rider(d)
    end
    assert(d.rider_head and d.rider_head:get_Valid(),"未找到狮鹫头部，不能建立头部球面导航")
    assert(validate_spawn(d.spawn)==ch,"Griffin reference changed")
    local center=vector(d.rider_head:call("get_Position()"))
    local anchor_detail={mode="head"}
    if debug_tools and debug_tools:recording() then d.route_navigation={center=vector(center),anchor=anchor_detail,input={x=input.x,y=input.y},heading={x=fx,z=fz},
        radius=settings.navigation_radius,height=settings.navigation_height} end
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
function tick_driver()
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
        if debug_tools and debug_tools:recording() then d.trace = {navigation_sphere=sphere,neutral_anchor=neutral,anchor_plan=d.anchor_plan,griffin = pos, player = vector(d.transform:call("get_Position()")), target = target,
            physical = vector(d.controller:call("get_Position()")), flight = flying, ground = ground,
            action = tostring(action_name), mode = d.mode, gear=d.gear, manual_hold=d.manual_hold, external_control=d.external_control, bumpers={rb=held(input.buttons,masks.rb),lb=held(input.buttons,masks.lb)}, anchor_mode=d.anchor_mode, stick = {x=input.x,y=input.y}} else d.trace=nil end
        passengers.tick_pose(d)
        passengers.tick(d)
        if d.trace then d.trace.passenger_protection=passengers.protection.counts;d.trace.seat_orientation=d.orientation_trace end
    end)
    if not ok then stop_driver("驾驶检查或位置同步失败"); failed("驾驶已停止", err) end
end
end
