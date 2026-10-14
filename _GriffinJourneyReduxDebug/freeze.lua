return function(ctx)
local _ENV=ctx
freeze_revision = 0
function change_player_freeze(freeze)
    freeze_revision = freeze_revision + 1
    local revision, d = freeze_revision, active
    if not d then
        settings.freeze_player = freeze
        -- Developer mode is session-only; no configuration write.
        return
    end
    run_once(function()
        if not alive or active ~= d or revision ~= freeze_revision then return end
        local ok, err = pcall(function()
            validate_spawn(d.spawn)
            apply_player_freeze(d, freeze)
            settings.freeze_player = freeze
            -- Developer mode is session-only; no configuration write.
        end)
        if not ok then stop_driver("FSM 对照切换失败"); failed("FSM 对照切换失败", err) end
    end)
end

end
