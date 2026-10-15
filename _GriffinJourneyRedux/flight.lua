-- Griffin Journey Redux: flight
return function(ctx)
local _ENV=ctx
local takeoff_min_seconds=1.89
-- Keep seats/control at any valid body tilt, including a vertical forward axis.
local function horizontal_heading(d,qx,qy,qz,qw)
    local fx,fz=2*(qx*qz+qw*qy),1-2*(qx*qx+qy*qy)
    local length=math.sqrt(fx*fx+fz*fz)
    if length>0.000001 then return fx/length,fz/length,length end
    local h=d.heading
    if h and finite(h.x) and finite(h.z) then
        local previous=math.sqrt(h.x*h.x+h.z*h.z)
        if previous>0.000001 then return h.x/previous,h.z/previous,length end
    end
    -- On the first vertical frame, infer horizontal forward from body right.
    local rx,rz=1-2*(qy*qy+qz*qz),2*(qx*qz-qw*qy)
    local right=math.sqrt(rx*rx+rz*rz)
    if right>0.000001 then return -rz/right,rx/right,length end
    return 0,1,length
end
passengers.horizontal_heading=horizontal_heading
function hotkey_start_driver()
    if active or state.recovery or queued then return end
    local r=state.spawns[#state.spawns]
    local ok,distance=pcall(function()
        assert(r and r.ready and not r.deleted and not r.delete_requested,"请先生成狮鹫并等待就绪")
        local allowed,reason=spawn_watch:mountable(r);assert(allowed,reason)
        local ch=validate_spawn(r)
        local pt=assert(r.owner:call("get_Transform()"),"玩家根节点不可用")
        local gt=assert(ch:call("get_Transform()"),"狮鹫根节点不可用")
        local a=vector(pt:call("get_UniversalPosition()"))
        local b=vector(gt:call("get_UniversalPosition()"))
        local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
        return math.sqrt(x*x+y*y+z*z)
    end)
    if not ok then failed("无法开始驾驶",distance);return end
    local limit=settings.boarding_distance
    if event then event("boarding_distance_check",{distance=distance,limit=limit,allowed=distance<limit}) end
    if distance>=limit then status=string.format("距离狮鹫根节点 %.2f 米，需小于 %.2f 米；请靠近后松开重按。",distance,limit);return end
    start_driver(r)
end

function start_driver(expected_spawn)
    if passengers.held and passengers.held.held_releasing then status="请等待乘客释放完成。";return end
    if summon and summon.current then status="请等待召唤演出结束。";return end
    local experiment = rawget(_G, "GriffinMountExperimentControl")
    if experiment and experiment.is_driving() then status = "请先结束实验工具的玩家固定。"; return end
    if active or state.recovery or queued then return end
    if not core() then status = "等待 NickCore 加载。"; return end
    local r = state.spawns[#state.spawns]
    if not r then status = "请先生成狮鹫。"; return end
    if expected_spawn and r~=expected_spawn then status="狮鹫实例已变化，请松开后重试。";return end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        local ok, err = pcall(function()
            if expected_spawn then assert(state.spawns[#state.spawns]==expected_spawn,"狮鹫实例已变化") end
            local c = assert(core(), "等待 NickCore 加载")
            r.party = capture_party(c, r.owner)
            passengers.refresh(true)
            local allowed,reason=spawn_watch:mountable(r);assert(allowed,reason)
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
            if passengers.held and passengers.held.spawn==r then
                anti_jitter:stop()
                d.passengers=passengers.held.passengers;passengers.held.passengers={};passengers.held=nil
            end
            active = d
            install_yaw_hook()
            if settings.head_camera~=false then change_camera_mode("griffin") end
            install_fall_hook()
            passengers.install_protection()
            pcall(passengers.capture_identity,d)
            apply_player_freeze(d, settings.freeze_player)
            local joint_ok,joint_err=pcall(discover_joints,d)
            if not joint_ok then if event then event("anchor_joint_error",tostring(joint_err)) end end
            prepare_anchor_mode(d,d.anchor_mode)
            if settings.rider_anim~="" then d.pose_pending=settings.rider_anim end
            select_player_target(r)
            if driver_extension then assert(driver_extension:tick(d),"附加组件恢复失败") end
            if r.result.chara:call("get_IsFlight()") then
                d.controls_active=true; d.control_node="Ch253HoverWaitHoHomingHeight"
                set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            end
            status = "驾驶中：地面RB翼风攻击／LB结束；A 地面起飞／1档上移；Y 下移；RS 降落；RB 俯冲／LB 爬升进入2档；LT 惯性悬停；左摇杆前后移动、左右转向；1档镜头仅转向时跟随，右摇杆可打断。"
            if event then event("driver_started", {freeze_player = d.freeze_requested,anchor_mode=d.anchor_mode,navigation_radius=settings.navigation_radius,steering_yaw=settings.steering_yaw,steering_pitch=settings.steering_pitch}) end
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
    if d.gear==1 and not d.external_control then
        local preset=assert(settings.hover_player_preset,"Hover player preset unavailable")
        local target,base=rider_seat(d,preset.player)
        return target,target,{mode="physical_player",preset_index=-1,center=base}
    end
    local center=vector(d.rider_head:call("get_Position()"))
    local anchor_detail={mode="head"}
    local radius=settings.navigation_radius
    local nav_x,nav_y=input.x,input.y
    local yaw=math.max(-1,math.min(1,nav_x))*settings.steering_yaw*math.pi/180
    local height=math.max(-radius*0.9,math.min(radius*0.9,settings.navigation_height))
    local neutral_pitch=math.asin(height/radius)
    local limit=85*math.pi/180
    local pitch=math.max(-limit,math.min(limit,neutral_pitch+math.max(-1,math.min(1,nav_y))*settings.steering_pitch*math.pi/180))
    if d.controls_active and not d.external_control and (d.gear==1 or d.gear==2) and masks then
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
-- Shared by RS and the scoped near-ground experiment.
function request_hover_landing(d,source)
    assert(d==active and d.controls_active and not d.external_control,"Landing ownership changed")
    hover_motion:release(d)
    d.gear=1;d.manual_hold="landing";d.wait_center=true
    d.auto_landing_hold=source=="near_ground" or nil
    d.control_node=nil;d.intent=nil;d.auto_hover=false
    if event then event("hover_landing_requested",{source=source}) end
end
local exit_landing
exit_landing_status="退出降落：等待退出驾驶"
function request_exit_landing(d)
    if not d or d.external_control or d.exit_landing_requested or not d.spawn or d.spawn.delete_requested then return end
    local allowed=spawn_watch:mountable(d.spawn)
    if not allowed then return end
    local ch=d.spawn.result.chara
    if not ch:call("get_IsFlight()") or ch:call("get_IsGround()") then return end
    local node="Ch253HoverToLanding"
    if d.voluntary_exit then
        local ok,near=pcall(function()
            assert(validate_spawn(d.spawn,true)==ch,"Exit height instance changed")
            return hover_collision:probe_exit_ground(ch:call("get_Transform()"),25)
        end)
        if not ok or not near then node="Ch253HoverWaitHoHomingHeight" end
        d.exit_keep_passengers=ok and near==false
        if event then event("exit_ground_check",{threshold=25,query_ok=ok,ground_within_limit=ok and near or false,
            node=node,error=not ok and tostring(near) or nil}) end
    end
    d.exit_landing_requested=true
    exit_landing={spawn=d.spawn,ch=ch,go=d.spawn.result.go,owner=d.player,deadline=os.time()+30,node=node,voluntary=d.voluntary_exit==true}
    exit_landing_status=node=="Ch253HoverToLanding" and "退出降落：等待释放完成并关闭暂停" or "退出悬停：等待释放完成并关闭暂停"
end
function tick_exit_landing()
    local ticket=exit_landing
    if not ticket then return end
    if not alive or os.time()>ticket.deadline or active or queued or ticket.spawn.delete_requested then exit_landing=nil;return end
    if state.recovery or menu.gameplay_paused() then return end
    exit_landing=nil -- one native request; never resend on every frame
    local ok,err=pcall(function()
        local c=core();local r=ticket.spawn
        assert(c and c.properties.player==ticket.owner and r.result.chara==ticket.ch and r.result.go==ticket.go,"退出降落归属已变化")
        local ch=validate_spawn(r)
        assert(spawn_watch:mountable(r),"狮鹫不适合降落")
        if not ch:call("get_IsFlight()") or ch:call("get_IsGround()") then return end
        local manager=ch:call("get_ActionManager()")
        assert(manager and manager:call("get_GameObject()")==ticket.go,"降落动作管理器归属不符")
        manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",10,ticket.node,0)
        exit_landing_status=ticket.node=="Ch253HoverToLanding" and "退出降落：已提交一次原生指令" or "退出悬停：已提交一次原生指令"
        if event then event("exit_landing_requested",{node=ticket.node,voluntary=ticket.voluntary}) end
    end)
    if not ok then exit_landing_status="退出降落：跳过／"..tostring(err);if event then event("exit_landing_skipped",tostring(err)) end end
end
function tick_driver()
    local d = active
    if not d or not alive then return end
    local c = core()
    if not c then stop_driver("游戏上下文不可用");return end
    if menu.gameplay_paused() then
        if not d.menu_paused then if event then event("driver_menu_paused",true) end end
        d.menu_paused=true;d.previous_buttons=input.buttons;hover_yaw_state=nil;d.takeoff_timer_last=now();sprint_motion:pause(d)
        if d.hover_motion then d.hover_motion.last_time=now() end
        return -- preserve player position, FSM, bones, camera and pending intent
    end
    if d.menu_paused then
        d.menu_paused=nil;d.previous_buttons=input.buttons;d.takeoff_timer_last=now();sprint_motion:pause(d)
        request_camera_follow_check()
        if d.hover_motion then d.hover_motion.last_time=now() end
        if event then event("driver_menu_resumed",true) end
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
        local fx,fz,length=horizontal_heading(d,qx,qy,qz,qw)
        d.heading={x=fx,z=fz}
        d.body_pitch=math.atan(2*(qy*qz-qw*qx),length)*180/math.pi
        local flying, ground = ch:call("get_IsFlight()"), ch:call("get_IsGround()")
        local manager = ch:call("get_ActionManager()")
        assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
        local info = manager:get_field("CurrentAction")
        local action_name = info and info:get_field("Name")
        d.native_action=action_name
        local transition=d.action_transition
        if transition and (action_name==transition.node or action_name~=transition.from
            or now()-transition.at>=0.35) then
            d.action_transition=nil
        end
        sprint_motion:sample(d,ch,tr,flying,ground,action_name)
        if d.mode=="taking_off" and d.auto_hover then
            local t=now()
            if not d.takeoff_play_started then
                if action_name=="Ch253TakeoffBackJump" or flying and not ground then
                    d.takeoff_play_started=true;d.takeoff_elapsed=0
                end
            else d.takeoff_elapsed=d.takeoff_elapsed+math.max(0,t-(d.takeoff_timer_last or t)) end
            d.takeoff_timer_last=t
        end
        local takeoff_locked=d.mode=="taking_off" and (not d.takeoff_play_started
            or (d.takeoff_elapsed or 0)<takeoff_min_seconds)
        local pressed = input.buttons & (~d.previous_buttons)
        d.previous_buttons = input.buttons
        local moving=input.x~=0 or input.y~=0
        local function resume(gear)
            local keep_hover=gear==1 and not d.external_control and d.control_node=="Ch253HoverWaitHoHomingHeight"
            d.gear=gear; d.controls_active=true; d.external_control=false
            d.manual_hold=nil;d.auto_landing_hold=nil; d.control_node=keep_hover and "Ch253HoverWaitHoHomingHeight" or nil; d.auto_hover=false
            if not keep_hover then d.intent=nil end
            d.mode=keep_hover and "hover" or "control"
            d.hover_wait_center=nil;d.takeoff_choice=nil;d.takeoff_stop_requested=nil
            if gear==2 then hover_motion:release(d);sprint_motion:clear(d) end
            if event then event("gear_selected",gear) end
        end
        -- Adopt only the exact stationary hover action, never a name substring or
        -- target-height/attack/landing action. Actual native state owns idle gear.
        -- A fresh non-hover command gets the existing submission window to enter.
        local hover_node="Ch253HoverWaitHoHomingHeight"
        local outgoing=(d.intent and d.intent.node~=hover_node)
            or (d.action_transition and d.action_transition.node~=hover_node)
        if action_name==hover_node and flying and not ground and not d.external_control
            and d.mode~="taking_off" and d.manual_hold~="landing" and not d.pending and not outgoing then
            local natural=d.gear~=1
            if natural or not d.controls_active or d.mode~="hover" or d.control_node~=hover_node then
                if natural then
                    hover_motion:release(d);sprint_motion:clear(d)
                    d.hover_wait_center=nil
                end
                d.gear=1;d.controls_active=true;d.mode="hover";d.control_node=hover_node
                if d.intent and d.intent.node==hover_node then d.intent=nil end
                if event then event("native_hover_adopted",{natural=natural}) end
            end
        end
        -- Fresh controls below can still leave an already active native hover.
        if takeoff_locked and not held(pressed,masks.landing) then
            if held(pressed,masks.rt) then
                d.takeoff_choice="dash";d.takeoff_stop_requested=nil
            elseif held(pressed,masks.lt) then
                d.takeoff_choice="hover";d.takeoff_stop_requested=true
            end
        elseif ground and not flying and not d.external_control and d.mode~="taking_off"
            and (held(pressed,masks.ground_wind_start) or held(pressed,masks.ground_wind_end)) then
            local node=held(pressed,masks.ground_wind_end) and "Ch253WingWindAttackEnd" or "Ch253WingWindAttackStartLoop"
            hover_motion:release(d);d.controls_active=false;d.control_node=nil;d.manual_hold=nil;d.auto_hover=false
            set_intent(d,node,"ground_wind")
        elseif held(pressed,masks.rt) and flying and not ground then
            resume(2)
        elseif held(pressed,masks.lt) and flying and not ground then
            local momentum=d.gear==2 and sprint_motion:capture(d) or nil
            resume(1);hover_motion:brake(d)
            if momentum then d.sprint_handoff=momentum end
        elseif held(pressed,masks.a) and action_phase_allowed("ground",flying,ground) and d.mode~="taking_off" and action_name~="Ch253TakeoffBackJump" then
            resume(1);hover_motion:release(d);d.mode="taking_off"
            set_intent(d,"Ch253TakeoffBackJump","taking_off");d.intent.auto_hover=true
        elseif held(pressed,masks.landing) then
            resume(1);request_hover_landing(d,"manual")
        elseif d.gear==1 and action_name==hover_node and d.mode=="hover" and flying and not ground
            and not d.external_control and not d.manual_hold and not d.pending and not outgoing
            and (held(pressed,masks.rb) or held(pressed,masks.lb)) then
            resume(2)
        end
        if d.mode=="taking_off" then
            if action_name=="Ch253TakeoffBackJump" then d.saw_takeoff=true end
            if d.auto_hover and not takeoff_locked and flying and not ground and not d.intent then
                local choice,stop=d.takeoff_choice,d.takeoff_stop_requested
                if choice=="dash" then resume(2)
                else
                    d.mode="hover";d.gear=1;d.controls_active=true;d.auto_hover=false
                    d.control_node=action_name=="Ch253HoverWaitHoHomingHeight" and action_name or nil
                    d.hover_wait_center=nil;d.takeoff_choice=nil;d.takeoff_stop_requested=nil
                    if stop then hover_motion:brake(d) end
                end
            elseif not d.auto_hover and ground and not flying and d.saw_takeoff and action_name~="Ch253TakeoffBackJump" then
                d.mode="ground";d.controls_active=false
            end
        end
        if hover_collision then hover_collision:observe(d,ch,tr,flying,ground,action_name) end
        if d.manual_hold=="landing" then
            if d.auto_landing_hold then
                if ground and not flying then d.auto_landing_hold=nil end
            elseif not moving then d.wait_center=false
            elseif not d.wait_center then d.manual_hold=nil;d.control_node=nil end
        end
        if d.controls_active and not d.external_control and d.mode~="taking_off" then
            local node,mode
            if d.manual_hold=="landing" then node,mode="Ch253HoverToLanding","landing"
            elseif d.gear==2 then node,mode="Ch253WrapAroundStartLoop","dash"
            else node,mode="Ch253HoverWaitHoHomingHeight","hover" end
            if not action_phase_allowed("air",flying,ground) then
                -- Cancel our queued airborne action; keep the grounded native action intact.
                if d.intent and d.intent.phase=="air" then d.intent=nil end
                d.control_node=nil
            elseif node~=d.control_node then d.control_node=node;set_intent(d,node,mode) end
        end
        hover_motion:tick(d,ch,tr,fx,fz,flying,ground,action_name)
        if d.hover_motion then fx,fz=d.heading.x,d.heading.z end
        local target,neutral,sphere=navigation_anchor(d,ch,tr,fx,fz)
        write_anchor(d,target,neutral)
        dispatch(d)
        passengers.tick_pose(d)
        passengers.tick(d)
    end)
    if not ok then
        if hover_collision then hover_collision:record("driver_error",tostring(err),true) end
        stop_driver("驾驶检查或位置同步失败"); failed("驾驶已停止", err) end
end
end
