-- Lightweight save boundary. No settings, gameplay modules or hooks before a player exists.
return function(initialize)
local native_re=re
local world={usable=false,epoch={},resetters={},deferred={}}
local ctx
local function key(player)
    local ok,value=pcall(function() return player:get_address() end)
    return ok and value or player
end
local function reset_world()
    world.epoch={} -- Queued work from the old save must never run in the next one.
    world.deferred={}
    if not ctx then return end
    local function attempt(fn) if fn then pcall(fn) end end
    local menu=ctx.menu or {}
    attempt(menu.flush_settings)
    attempt(function() ctx.stop_driver("存档世界结束",true) end)
    attempt(function() ctx.summon:cancel("存档世界结束") end)
    attempt(function() ctx.shop_item:shutdown() end)
    attempt(function() ctx.hud:restore_all();ctx.hud:clear();ctx.hud.last=nil end)
    if menu.reset_debug_defaults then
        local applying=menu.applying_edits;menu.applying_edits=true
        attempt(menu.reset_debug_defaults)
        menu.applying_edits=applying
    end
    ctx.alive=false
    ctx.operation=nil;ctx.queued=false;ctx.exit_landing=nil
    if ctx.state then ctx.state.spawns={};ctx.state.pending_cleanup={} end
    ctx.skip_think_enabled=false;ctx.skip_think_expected=nil
    if ctx.passengers then
        ctx.passengers.roster=nil;ctx.passengers.npcs=nil
        ctx.passengers.next_roster=nil;ctx.passengers.next_npc=nil
    end
    if ctx.consumables then ctx.consumables.current=nil;ctx.consumables.verification=nil end
    menu.pending_edit=nil;menu.pending_save=nil;menu.pending_preset=nil
    if ctx.controls then ctx.controls.capture=nil;ctx.controls.release_gate=true;ctx.controls.previous={} end
    if ctx.shop_item then
        ctx.shop_item.shop=nil;ctx.shop_item.array=nil;ctx.shop_item.created=nil;ctx.shop_item.item=nil;ctx.shop_item.next_check=nil
    end
end
local function suspend_unknown()
    local ok,valid=pcall(function() return world.player and world.player:get_Valid() end)
    if world.player and ok and valid==false then reset_world();world.player=nil end
    world.usable=false
    if ctx and ctx.active then ctx.active.menu_paused=true end
end
local function poll(allow_initialize)
    if world.failed then return end
    local ok,cm,gui=pcall(function()
        return sdk.get_managed_singleton("app.CharacterManager"),sdk.get_managed_singleton("app.GuiManager")
    end)
    if not ok or not cm or not gui then
        suspend_unknown() -- Inconclusive managers retain a valid session and recovery records.
        return
    end
    world.gui=gui
    local read_ok,player=pcall(function()
        local p=cm["<ManualPlayer>k__BackingField"]
        if p and p:get_Valid() then return p end
    end)
    if not read_ok then suspend_unknown();return end
    if not player then
        if world.player then reset_world();world.player=nil end
        world.usable=false;return
    end
    local identity=key(player)
    if world.player and identity~=world.player_key then reset_world();world.player=nil end
    local flags_ok,loading,paused=pcall(function()
        return gui:call("get_IsLoadGui()"),gui:isPausedGUI()==true or gui:call("get_IsPausedGUINoLock()") == true
    end)
    world.paused=not flags_ok or loading~=false or paused
    local core=rawget(_G,"NickCore")
    if not core or not core.properties or core.properties.player~=player or not core.object
        or not core.enemySpawner or type(run_once)~="function" then suspend_unknown();return end
    if not world.player then
        if allow_initialize==false or not flags_ok or loading~=false then world.usable=false;return end
        world.player,world.player_key,world.usable=player,identity,true
        if not ctx then
            ctx=setmetatable({world=world},{__index=_G})
            local proxy=setmetatable({},{__index=native_re})
            for _,name in ipairs({"on_frame","on_draw_ui","on_pre_gui_draw_element","on_gui_draw_element"}) do
                if native_re[name] then proxy[name]=function(fn)
                    native_re[name](function(...)
                        if world.usable or name=="on_gui_draw_element" then return fn(...) end
                        if name=="on_pre_gui_draw_element" then return true end
                    end)
                end end
            end
            for _,name in ipairs({"on_application_entry","on_pre_application_entry"}) do
                proxy[name]=function(phase,fn)
                    native_re[name](phase,function(...) if world.usable then return fn(...) end end)
                end
            end
            proxy.on_script_reset=function(fn) world.resetters[#world.resetters+1]=fn end
            ctx.re=proxy
            ctx.run_once=function(fn)
                local epoch=world.epoch
                run_once(function()
                    if epoch~=world.epoch then return end
                    if world.usable then fn()
                    else world.deferred[#world.deferred+1]={fn=fn,epoch=epoch} end
                end)
            end
            local initialized,err=pcall(initialize,ctx)
            if not initialized then
                world.failed=true;reset_world();world.usable=false
                log.error("[Griffin Journey Redux] startup failed: "..tostring(err))
            end
        else
            ctx.generation={};ctx.state.generation=ctx.generation;ctx.alive=true
            ctx.menu.photo_camera_suspended=nil
            ctx.anti_jitter.fall_stop:set_enabled(ctx.settings.anti_jitter)
        end
    else world.usable=true end
    if world.usable and #world.deferred>0 then
        local pending=world.deferred;world.deferred={}
        for _,job in ipairs(pending) do if job.epoch==world.epoch then ctx.run_once(job.fn) end end
    end
end
native_re.on_frame(poll)
native_re.on_pre_application_entry("UpdateBehavior",function() poll(false) end)
native_re.on_draw_ui(function()
    if world.usable then return end
    if imgui.tree_node("Griffin Journey Redux###GriffinJourneyRedux") then
        imgui.text("等待加载存档")
        imgui.tree_pop()
    end
end)
native_re.on_script_reset(function()
    for _,fn in ipairs(world.resetters) do pcall(fn) end
    world.epoch={};world.deferred={};world.usable=false;world.player=nil
end)
poll()
return world
end
