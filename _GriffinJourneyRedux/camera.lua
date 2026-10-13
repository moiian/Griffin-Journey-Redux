-- Griffin Journey Redux: camera
return function(ctx)
local _ENV=ctx
function restore_follow()
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
function change_camera_mode(key)
    run_once(function()
        if not alive then return end
        local ok,err=restore_follow()
        if not ok then camera_follow_status="镜头恢复未完成："..tostring(err);return end
        camera_mode=key
        camera_follow_status=key=="original" and "镜头跟随：游戏默认" or "镜头跟随已选择，驾驶期间生效。"
        event("camera_follow_mode",key)
    end)
end
function tick_camera_follow()
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
function wrap_yaw(a) return (a+math.pi)%(2*math.pi)-math.pi end
function yaw_failed(err)
    yaw_state=nil
    settings.camera_auto_yaw=false
    yaw_status="自动跟随已停用："..tostring(err)
    event("camera_yaw_error",tostring(err))
end
function tick_camera_yaw(controller)
    local d,s=active,follow_state
    if not alive or not settings.camera_auto_yaw then return end
    if not d or not s or camera_mode~="griffin" or d.gear~=2 or not d.controls_active or d.external_control then
        yaw_state=nil; yaw_status="自动跟随待机：仅2档头部镜头生效";return
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
            if d.trace then d.trace.camera_yaw={manual=paused,steering=steering,current=angle.y,pitch=angle.x,
                right_magnitude=magnitude,threshold=threshold,weight=0,scale=y.scale} end
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
        yaw_status="2档转向跟随；右摇杆小幅叠加、大幅接管"
        if d.trace then d.trace.camera_yaw={manual=false,steering=true,current=angle.y,requested=output*y.scale,target=desired*y.scale,
            right_magnitude=magnitude,threshold=threshold,weight=weight,
            manual_yaw=y.manual_yaw,speed=settings.camera_yaw_speed,scale=y.scale,dt=dt} end

    end)
    if not ok then yaw_failed(err) end
end
function install_yaw_hook()
    if yaw_hook_ready then return true end
    local ok,err=pcall(function()
        local def=assert(sdk.find_type_definition("app.RotateCameraControllerBase"),"镜头旋转类型不可用")
        local method=assert(def:get_method("updateManualCameraControl()"),"镜头手动更新接口不可用")
        assert(def:get_method("setYaw(System.Single)") and def:get_method("get_Angle()") and
            def:get_method("get_YawRange()") and def:get_method("get_YawRangeDeg()"),"镜头水平角接口不可用")
        sdk.hook(method,function(args)
            local storage=thread.get_hook_storage()
            storage.griffin_yaw_controller=nil
            storage.griffin_hover_camera=nil
            local d=active
            if alive and d and d.hover_motion and not menu.gameplay_paused() and math.abs(input.rx or 0)>0.2 then
                local ok=pcall(function()
                    if not owned_player(d,true) then return end
                    local manager=sdk.get_managed_singleton("app.CameraManager")
                    local main=manager and manager._MainCameraControllers and manager._MainCameraControllers[0]
                    if not main or not main:get_Valid() or main:call("get_TargetCharacter()")~=d.player then return end
                    local candidate=sdk.to_managed_object(args[2])
                    if candidate~=main._CurrentCameraController then return end
                    local angle=candidate:call("get_Angle()")
                    if angle and finite(angle.y) then storage.griffin_hover_camera={driver=d,controller=candidate,yaw=angle.y,main=main} end
                end)
            end
            if alive and settings.camera_auto_yaw and active and follow_state then
                local candidate=sdk.to_managed_object(args[2])
                if candidate==follow_state.controller then storage.griffin_yaw_controller=candidate end
            end
        end,function(retval)
            local hover=thread.get_hook_storage().griffin_hover_camera
            if hover and active==hover.driver and active.hover_motion and not menu.gameplay_paused() then
                local ok,err=pcall(function()
                    assert(owned_player(active,true) and hover.main:get_Valid()
                        and hover.main:call("get_TargetCharacter()")==active.player
                        and hover.main._CurrentCameraController==hover.controller,"Hover camera binding changed")
                    -- Horizontal right-stick input steers the body in hover; pitch remains native.
                    hover.controller:call("setYaw(System.Single)",hover.yaw)
                end)
                if not ok then event("hover_camera_error",tostring(err)) end
            end
            local candidate=thread.get_hook_storage().griffin_yaw_controller
            if candidate then tick_camera_yaw(candidate) end
            return retval
        end)
        yaw_hook_ready=true
    end)
    if not ok then yaw_failed(err) end
    return ok
end
function read_camera_follow()
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
function restore_camera()
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
end
