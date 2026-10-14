-- Griffin Journey Redux: lifecycle
return function(ctx)
local _ENV=ctx
stop_driver = function(reason,suppress_landing,voluntary)
    local departing=active or state.recovery
    if voluntary and departing then
        departing.voluntary_exit=true
        local ok,err=pcall(capture_exit_seats,departing)
        if not ok then event("exit_seat_capture_failed",tostring(err)) end
    end
    if summon then summon:cancel(reason) end
    local early_errors={}
    local anti_ok,anti_err=pcall(anti_jitter.stop,anti_jitter)
    if not anti_ok then early_errors[#early_errors+1]="防抖释放 "..tostring(anti_err) end
    if debug_tools then
        local ok,err=pcall(debug_tools.stop,debug_tools)
        if not ok then early_errors[#early_errors+1]="调试释放 "..tostring(err) end
    end
    operation = nil
    queued = false
    local ai_call_ok,ai_ok,ai_err=pcall(ai_takeover.release,ai_takeover)
    if not ai_call_ok then ai_err=ai_ok;ai_ok=false end
    local d = active or state.recovery
    if d and not suppress_landing and request_exit_landing then pcall(request_exit_landing,d) end
    active = nil
    passengers.griffin_fall.actor=nil
    input = {x = 0, y = 0, buttons = 0}
    local camera_ok,camera_err=pcall(restore_camera)
    if not camera_ok then early_errors[#early_errors+1]="镜头恢复 "..tostring(camera_err) end
    if not d then return ai_ok end
    local sprint_ok,sprint_err=pcall(sprint_motion.clear,sprint_motion,d)
    if not sprint_ok then early_errors[#early_errors+1]="冲刺释放 "..tostring(sprint_err) end
    d.intent = nil -- queued native action callbacks must see that driving has ended
    local errors={}
    if passengers.restore_all then
        local ok,result=pcall(passengers.restore_all,d)
        if ok then errors=result else errors={"乘客释放 "..tostring(result)} end
    end
    for _,err in ipairs(early_errors) do errors[#errors+1]=err end
    local hover_ok,hover_err=pcall(hover_motion.release,hover_motion,d)
    if not hover_ok then errors[#errors+1]="慢速位置恢复 "..tostring(hover_err) end
    if not ai_ok then errors[#errors+1]="决策组件恢复 "..tostring(ai_err) end
    local bone_ok,bone_err=pcall(restore_bone,d)
    if not bone_ok then errors[#errors+1]="骨骼恢复 "..tostring(bone_err) end
    local rot_ok,rot_err=pcall(passengers.restore_rotation,d)
    if not rot_ok then errors[#errors+1]="朝向恢复 "..tostring(rot_err) end
    if d.moved then
        local ok, err = pcall(function()
            if owned_player(d, true) then
                if not apply_exit_seat(d) then sync_player(d,true) end
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
    event("driver_stopped", {reason = reason, errors = errors,release_mode=d.voluntary_exit and "current_preset_seats" or "current_physical_position",player_position=d.release_position})
    return #errors == 0
end
end
