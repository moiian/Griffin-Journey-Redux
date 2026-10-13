-- Griffin Journey Redux: camera
return function(ctx)
local _ENV=ctx
function restore_follow()
    yaw_state=nil -- angle writes leave no persistent lock; native/manual control resumes
    hover_yaw_state=nil
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
-- Head binding checks are action-triggered plus a 2 Hz fallback. Healthy
-- frames only test cached Lua flags/time, and healthy bindings are never rewritten.
local follow_due,follow_next,follow_revision=true,0,0
function request_camera_follow_check()
    if alive and active and camera_mode=="griffin" then follow_due=true end
end
function change_camera_mode(key)
    follow_revision=follow_revision+1
    local revision=follow_revision
    camera_mode=key -- Explicit off takes effect before queued native restoration.
    follow_due=key=="griffin";follow_next=0
    run_once(function()
        if not alive or revision~=follow_revision then return end
        local ok,err=restore_follow()
        if not ok then camera_follow_status="镜头恢复未完成："..tostring(err);return end
        camera_follow_status=key=="original" and "镜头跟随：游戏默认" or "镜头跟随已选择，驾驶期间生效。"
        event("camera_follow_mode",key)
    end)
end
function tick_camera_follow()
    local d=active
    if not alive or not d or camera_mode~="griffin" then return end
    local t=now()
    if not follow_due and t<follow_next then return end
    if not core() or menu.gameplay_paused() then return end
    follow_due=false;follow_next=t+0.5
    local ok,err=pcall(function()
        assert(owned_player(d,true),"玩家实例变化")
        validate_spawn(d.spawn)
        local manager=assert(sdk.get_managed_singleton("app.CameraManager"),"CameraManager不可用")
        local controllers=manager._MainCameraControllers
        local main=controllers and controllers[0]
        assert(main and main:get_Valid(),"主镜头控制器暂不可用")
        assert(main:call("get_TargetCharacter()")==d.player,"等待镜头归还驾驶玩家")
        local controller=assert(main._CurrentCameraController,"镜头控制器暂不可用")
        local s=follow_state
        if s and (s.main~=main or s.manager~=manager) then
            local restored,restore_err=restore_follow()
            assert(restored,restore_err)
            s=nil
        end
        if not d.rider_head or not d.rider_head:get_Valid() then prepare_rider(d) end
        local joint=d.rider_head
        assert(joint and joint:get_Valid(),"等待狮鹫头部骨骼")
        local current=main:call("get_TargetJoint()")
        if not s then
            assert(current and current:get_Valid(),"等待可恢复的原镜头骨骼")
            s={main=main,manager=manager,player=d.player,joint=joint,
                original_joint=current,controller=controller}
            follow_state=s
        elseif s.controller~=controller or s.joint~=joint then
            s.controller=controller;s.joint=joint
            yaw_state=nil;hover_yaw_state=nil
        end
        if current~=joint then
            -- Preserve the latest native target as the release target. Do not capture
            -- our own previous head target as a new native/default joint.
            if current~=s.last_joint then
                assert(current and current:get_Valid(),"等待可恢复的原镜头骨骼")
                s.original_joint=current
            end
            assert(s.original_joint and s.original_joint:get_Valid(),"原镜头骨骼暂不可用")
            s.last_joint=joint -- Retain restoration even if the setter raises after writing.
            main:call("set_TargetJoint(via.Joint)",joint)
        else s.last_joint=joint end
        camera_follow_status="镜头跟随中：griffin"
        d.camera_follow_error=nil
    end)
    if not ok then
        -- Native cutscenes/collision/controller transitions may temporarily replace
        -- the camera. Keep the requested mode and retry, without writing user settings.
        camera_follow_status="头部镜头等待恢复："..tostring(err)
        if d.camera_follow_error~=tostring(err) then event("camera_follow_wait",tostring(err)) end
        d.camera_follow_error=tostring(err)
    end
end
-- Native manual-camera update finishes input handling before rotation is built.
-- Only the current driving player's exact controller is touched. No camera Transform writes.
function wrap_yaw(a) return (a+math.pi)%(2*math.pi)-math.pi end
local function hover_camera_active(d)
    return alive and d and d.controls_active and not d.external_control and d.gear==1
        and d.hover_motion and settings.hover_camera_yaw_speed>0
end
function yaw_failed(err)
    yaw_state=nil
    settings.camera_auto_yaw=false
    yaw_status="自动跟随已停用："..tostring(err)
    event("camera_yaw_error",tostring(err))
end
-- Shared follow policy: native-unit calibration, manual blend/override, hysteresis,
-- 0.8s recovery delay, shortest-arc easing and exact-controller scope.
local function update_camera_yaw(d,s,controller,low,steering,speed)
        local c=core()
        if not c or menu.gameplay_paused() then
            if low then hover_yaw_state=nil else yaw_state=nil end
            return
        end
        assert(owned_player(d,true) and s.main:get_Valid(),"驾驶玩家或镜头失效")
        assert(s.main:call("get_TargetCharacter()")==d.player and s.main._CurrentCameraController==controller,
            "镜头归属或控制器变化")
        assert(sdk.get_managed_singleton("app.CameraManager")==s.manager,"镜头管理器变化")
        assert(not input.right_error and finite(input.rx) and finite(input.ry),"右摇杆读取不可用")
        local angle=vector(controller:call("get_Angle()"))
        local t=now()
        local y
        if low then y=hover_yaw_state else y=yaw_state end
        if not y or y.controller~=controller or y.driver~=d or y.main~=s.main then
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
            y={controller=controller,driver=d,main=s.main,last_time=t,resume_at=t,
                scale=scale,offset=wrap_yaw(angle.y/scale-math.atan(dx,dz)),
                manual_yaw=0,previous_yaw=angle.y/scale}
            if low then hover_yaw_state=y else yaw_state=y end
            event(low and "hover_camera_yaw_bound" or "camera_yaw_bound",{scale=scale,offset=y.offset,original_yaw=angle.y})
        end
        local dt=math.max(0,math.min(0.1,t-y.last_time));y.last_time=t
        local magnitude=math.min(1,math.sqrt(input.rx*input.rx+input.ry*input.ry))
        local threshold=settings.camera_manual_threshold
        if magnitude>=threshold then y.manual_latched=true; y.resume_at=t+0.8
        elseif y.manual_latched then
            if magnitude>threshold-0.08 then y.resume_at=t+0.8
            else y.manual_latched=false end
        end
        local current=angle.y/y.scale
        local paused=y.manual_latched or t<y.resume_at
        if not steering or paused then
            y.previous_yaw=current
            yaw_status=not steering and (low and "狮鹫停止转向：自动跟随暂停" or "左摇杆回中：自动跟随暂停") or "右摇杆接管；释放后延迟恢复"
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
        local step=eased_step(wrap_yaw(desired-current),speed)
        local output=current+step
        if dt>0 and math.abs(step)>0.00001 then controller:call("setYaw(System.Single)",output*y.scale) end
        y.previous_yaw=output
        yaw_status=(low and "1档" or "2档").."转向跟随；右摇杆小幅叠加、大幅接管"
        if d.trace then d.trace.camera_yaw={manual=false,steering=true,current=angle.y,requested=output*y.scale,target=desired*y.scale,
            right_magnitude=magnitude,threshold=threshold,weight=weight,
            manual_yaw=y.manual_yaw,speed=speed,scale=y.scale,dt=dt} end

end
function tick_hover_camera_yaw(controller)
    local d=active
    if not hover_camera_active(d) or menu.gameplay_paused() then hover_yaw_state=nil;return end
    local ok,err=pcall(function()
        assert(d.hover_motion.character==validate_spawn(d.spawn),"Hover camera Griffin changed")
        local manager=assert(sdk.get_managed_singleton("app.CameraManager"),"CameraManager unavailable")
        local main=manager._MainCameraControllers and manager._MainCameraControllers[0]
        assert(main and main:get_Valid() and main:call("get_TargetCharacter()")==d.player
            and main._CurrentCameraController==controller,"Hover camera ownership changed")
        local s={main=main,manager=manager,controller=controller}
        local turning=finite(d.hover_motion.turn) and math.abs(d.hover_motion.turn)>0.001
        update_camera_yaw(d,s,controller,true,turning,settings.hover_camera_yaw_speed)
        d.hover_camera_error=nil
    end)
    if not ok then
        hover_yaw_state=nil
        if d.hover_camera_error~=tostring(err) then event("hover_camera_follow_error",tostring(err)) end
        d.hover_camera_error=tostring(err)
    end
end
function tick_camera_yaw(controller)
    local d,s=active,follow_state
    if not alive or not settings.camera_auto_yaw then return end
    if not d or not s or camera_mode~="griffin" or d.gear~=2 or not d.controls_active or d.external_control then
        yaw_state=nil; yaw_status="自动跟随待机：仅2档头部镜头生效";return
    end
    if controller~=s.controller then return end
    local ok,err=pcall(update_camera_yaw,d,s,controller,false,input.x~=0 or input.y~=0,settings.camera_yaw_speed)
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
            if not alive then return end
            local storage_ok,storage=pcall(thread.get_hook_storage)
            if not storage_ok or not storage then return end
            storage.griffin_yaw_controller=nil
            storage.griffin_hover_yaw_controller=nil
            if not hover_camera_active(active) or menu.gameplay_paused() then hover_yaw_state=nil end
            if hover_camera_active(active) and not menu.gameplay_paused() then
                pcall(function()
                    if not owned_player(active,true) then return end
                    local manager=sdk.get_managed_singleton("app.CameraManager")
                    local main=manager and manager._MainCameraControllers and manager._MainCameraControllers[0]
                    if not main or not main:get_Valid() or main:call("get_TargetCharacter()")~=active.player then return end
                    local candidate=sdk.to_managed_object(args[2])
                    if candidate==main._CurrentCameraController then storage.griffin_hover_yaw_controller=candidate end
                end)
            end
            if alive and settings.camera_auto_yaw and active and follow_state then
                local candidate=sdk.to_managed_object(args[2])
                if candidate==follow_state.controller then storage.griffin_yaw_controller=candidate end
            end
        end,function(retval)
            if not alive then return retval end
            local storage_ok,storage=pcall(thread.get_hook_storage)
            if not storage_ok or not storage then return retval end
            -- Snapshot both before any native call: the first callback may invalidate
            -- or replace the current thread hook storage through a nested hook.
            local hover,candidate=storage.griffin_hover_yaw_controller,storage.griffin_yaw_controller
            storage.griffin_hover_yaw_controller=nil;storage.griffin_yaw_controller=nil
            if hover then tick_hover_camera_yaw(hover) end
            if candidate then tick_camera_yaw(candidate) end
            return retval
        end)
        yaw_hook_ready=true
    end)
    if not ok then yaw_failed(err) end
    return ok
end
function read_camera_follow()
    if not debug_tools or not debug_tools:recording() then return end
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
