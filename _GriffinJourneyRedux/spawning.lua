-- Griffin Journey Redux: spawning
return function(ctx)
local _ENV=ctx
function spawn(options)
    if consumables and consumables.current then return false end
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
        if operation ~= token then
            if hud and not options then hud:cancel_summon(token) end
            return
        end
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
            if event then event("spawn_requested", "NickCore Griffin; ThinkStop requested; exact returned reference") end
        end)
        if not ok then
            if hud and not options then hud:cancel_summon(token) end
            failed("生成失败", err)
        end
    end)
    if hud and not options then hud:notify_summon(core().properties.player,token) end
    return true
end
function tick_cleanup_departures()
    local t=now()
    for _,r in ipairs(state.spawns) do
        local departure=r.departure
        if departure then
            local dt=t-departure.last;departure.last=t
            if not menu.gameplay_paused() and finite(dt) and dt>=0 then departure.elapsed=departure.elapsed+dt end
        end
    end
end
local function native_flag(ch,name)
    local ok,value=pcall(ch.call,ch,name.."()")
    if ok and type(value)=="boolean" then return value end
end
local function departure_action(r,ch,go,node)
    local ok,err=pcall(function()
        assert(ch:get_Valid() and go:get_Valid() and ch:call("get_GameObject()")==go,"离场实例已变化")
        local manager=ch:call("get_ActionManager()")
        assert(manager and manager:call("get_GameObject()")==go,"离场动作管理器归属不符")
        manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",10,node,0)
        if event then event("cleanup_departure_action",{node=node,elapsed=r.departure and r.departure.elapsed}) end
    end)
    if not ok then if event then event("cleanup_departure_action_failed",tostring(err)) end end
    return ok
end
delete_one = function(r)
    if r.destroy_queued then return end
    local result = r.result
    if not result or not result.go then return end -- retain pending table; delete when NickCore fills it
    r.destroy_queued = true
    local go = result.go
    run_once(function()
        if not alive then r.destroy_queued = false; return end
        if menu.gameplay_paused() then r.destroy_queued=false;return end
        local ok, err = pcall(function()
            assert(not (active and active.spawn==r) and not (passengers.held and passengers.held.spawn==r) and not (state.recovery and state.recovery.spawn==r), "End this Griffin driving before deletion")
            assert(r.result == result and result.go == go, "Spawn reference changed")
            if go:get_Valid() then
                if result.chara and result.chara:get_Valid() then
                    local ch=result.chara
                    assert(ch:call("get_GameObject()") == go
                        and ch:get_CharaIDString() == "ch253000_00", "Spawn identity mismatch")
                    local healthy=not r.sinking and native_flag(ch,"get_IsDead")==false
                        and native_flag(ch,"get_IsFallDead")==false and native_flag(ch,"get_IsDown")==false
                    if r.ready and healthy and not r.departure_skip then
                        if not r.departure and native_flag(ch,"get_IsGround")==true and native_flag(ch,"get_IsFlight")==false then
                            r.departure={elapsed=0,last=now(),go=go,ch=ch}
                            if not departure_action(r,ch,go,"Ch253TakeoffBackJump") then r.departure_skip=true;r.departure=nil end
                        end
                        local departure=r.departure
                        if departure then
                            assert(departure.go==go and departure.ch==ch,"离场归属已变化")
                            if departure.elapsed>=3 and not departure.flight_sent then
                                departure.flight_sent=true
                                departure_action(r,ch,go,"FlightTarget")
                            end
                            if departure.elapsed<4.2 then
                                status=string.format("狮鹫离场演出：%.2f / 4.20秒",departure.elapsed)
                                return
                            end
                        end
                    end
                end
                if event then event("delete_requested", "Only this Beta's returned GameObject") end
                go:destroy(go) -- same native destruction form as installed NickCore; never destroy_spawns()
            end
            r.deleted = true; r.friend = false
            status = "本 Beta 生成的狮鹫已删除。"
            if event then event("deleted", "Owned instance only") end
        end)
        r.destroy_queued = false
        if not ok then r.delete_requested = false; failed("删除失败", err) end
    end)
end
end
