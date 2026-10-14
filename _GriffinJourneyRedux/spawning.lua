-- Griffin Journey Redux: spawning
return function(ctx)
local _ENV=ctx
function spawn(options)
    if spawn_watch then spawn_watch:reap_invalid() end
    if state.pending_cleanup and #state.pending_cleanup>=4 then status="迟到生成请求仍待清理，请等待原生返回。";return false end
    if summon and summon.current and (not options or options.session~=summon.current) then return false end
    if queued or #state.spawns > 0 or state.recovery then return false end
    settings.freeze_player=true;block_player_fall=true
    passengers.protection.damage=true;passengers.protection.relocation=true
    if not core() then status = "等待 NickCore 加载。"; return false end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        if options and (not summon or summon.current~=options.session) then return end
        local ok, err = pcall(function()
            local c = assert(core(), "等待 NickCore 加载")
            assert(c.properties.player and not menu.gameplay_paused(), "请进入游戏")
            if options then assert(c.properties.player==options.owner,"Summon player changed") end
            install_hooks()
            local r = {owner = c.properties.player, party = capture_party(c,c.properties.player), friend = true,spawn_wait_started=now()}
            if options then r.summon_facing=options.facing end
            -- NickCore returns a mutable instance-reference table; never search by Character ID.
            r.result = c.enemySpawner.spawn_enemy("Griffin", options and options.position or nil, true)
            assert(type(r.result) == "table", "Spawn interface returned no reference table")
            state.spawns[#state.spawns+1] = r
            status = "正在生成狮鹫并设置友方……"
            event("spawn_requested", "NickCore Griffin; ThinkStop requested; exact returned reference")
        end)
        if not ok then failed("生成失败", err) end
    end)
    return true
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
            assert(not (active and active.spawn==r) and not (state.recovery and state.recovery.spawn==r), "End this Griffin driving before deletion")
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
end
