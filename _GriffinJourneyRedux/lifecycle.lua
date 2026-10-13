-- Griffin Journey Redux: lifecycle
return function(ctx)
local _ENV=ctx
stop_driver = function(reason)
    if summon then summon:cancel(reason) end
    anti_jitter:stop()
    if debug_tools then debug_tools:stop() end
    operation = nil
    queued = false
    local ai_ok,ai_err=ai_takeover:release()
    local d = active or state.recovery
    active = nil
    passengers.griffin_fall.actor=nil
    input = {x = 0, y = 0, buttons = 0}
    restore_camera()
    if not d then return ai_ok end
    sprint_motion:clear(d)
    d.intent = nil -- queued native action callbacks must see that driving has ended
    local errors = passengers.restore_all and passengers.restore_all(d) or {}
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
end
