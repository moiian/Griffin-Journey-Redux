-- Griffin Journey Redux: tools
return function(ctx)
local _ENV=ctx
require("_GriffinJourneyReduxDebug.collision")(ctx)
require("_GriffinJourneyReduxDebug.item_probe")(ctx)
Fine=require("_GriffinJourneyReduxDebug.fine")
debug_tools={enabled=false,status="调试记录：关闭",observers_installed=false}
journal={version=VERSION,events={},samples={}}
journal_dirty=false
part,last_flush,next_sample=1,-math.huge,0
log_id=nil
function debug_tools:recording() return self.enabled or self.fine.running end
function debug_tools:diagnostics()
    return {normal_log_io=passengers.snapshot(menu.log_io),journal_samples=#journal.samples,journal_events=#journal.events,
        journal_dirty=journal_dirty,dropped_samples=journal.dropped_samples or 0,dropped_events=journal.dropped_events or 0,
        anti_jitter=anti_jitter.fall_stop:snapshot(),griffin_anti_jitter=anti_jitter.griffin_stop:snapshot(),
        fall_experiments=passengers.snapshot(passengers.fall_experiment)}
end
debug_tools.fine=Fine.new(setmetatable({dump=function(path,data) return json.dump_file(path,data) end,
    diagnostics=function() return debug_tools:diagnostics() end},{__index=anti_jitter.env}))
function debug_tools:capture(stage)
    if self.fine.running then
        local ok,err=pcall(self.fine.capture,self.fine,stage)
        if not ok then self.fine:stop("读取异常");self.fine.status="三秒探针已停止："..tostring(err) end
    end
end
function debug_tools:tick() self.fine:tick() end
function debug_tools:stop() self.fine:stop("结束驾驶") end
function debug_tools:shutdown() self:stop();self.fine:shutdown();self:flush() end
function debug_tools:set_enabled(value)
    if value then
        self.enabled=true
        log_id=os.date("!%Y%m%dT%H%M%SZ").."_"..math.floor(os.clock()*1000)
        part=1;journal={version=VERSION,events={},samples={}};journal_dirty=false;next_sample=0
        self:install_observers()
        self.status="调试记录：开启；暂停或结束驾驶后保存"
    else
        self.enabled=false;journal={version=VERSION,events={},samples={}};journal_dirty=false
        self.status="调试记录：关闭；未保存缓存已丢弃"
    end
end
function debug_tools:flush()
    if not self.enabled then return false end
    if self.fine.running then return false end
    -- JSON serialization and disk output block the game thread. Keep gameplay in memory.
    if active and not menu.gameplay_paused() then return false end
    if not journal_dirty then return true end
    local started=os.clock()
    local ok, result = pcall(json.dump_file, "GriffinJourneyRedux_" .. log_id .. "_" .. part .. ".json", journal)
    menu.log_io=menu.log_io or {sequence=0,recent={}}
    local io=menu.log_io;io.sequence=io.sequence+1
    io.recent[#io.recent+1]={sequence=io.sequence,start_clock=started,end_clock=os.clock(),game_time=now(),
        samples=#journal.samples,events=#journal.events,success=ok and result~=false}
    if #io.recent>8 then table.remove(io.recent,1) end
    last_flush = now()
    if not ok or result == false then log.error("[GriffinFlightBeta] Log save failed") end
    if ok and result~=false then journal_dirty=false end
    return ok and result ~= false
end
function debug_tools:rotate()
    if not self.enabled then return end
    if #journal.events < 400 and #journal.samples < 600 then return end
    if active and not menu.gameplay_paused() then return end
    if flush() then
        part = part + 1
        journal = {version = VERSION, events = {}, samples = {}}
        journal_dirty=true
    end
end
function debug_tools:event(name, detail, defer_flush)
    if not self.enabled then return end
    self:rotate()
    if #journal.events>=400 then
        table.remove(journal.events,1);journal.dropped_events=(journal.dropped_events or 0)+1
    end
    journal.events[#journal.events + 1] = {name = name, detail = detail, time = now()}
    journal_dirty=true
    -- Bounded recent history while flying; pause/end/reset are the save boundaries.
    if not defer_flush and not active then flush() end
end

target_enum_names={}
function target_type_name(value)
    local key=tostring(value)
    if target_enum_names[key] then return target_enum_names[key] end
    local td=sdk.find_type_definition("app.TargetController.TargetTypeEnum")
    if td then
        for _,name in ipairs({"ManualPlayer","CharaHighWithoutClimber","HateHigh","HateLow","LastTargetPosition","GeneratePosition","Self","Nearest","CharaHigh","CharaLow"}) do
            local field=td:get_field(name)
            if field then
                local v=field:get_data()
                if finite(v) then target_enum_names[tostring(v)]=name end
            end
        end
    end
    return target_enum_names[key] or "Unknown"
end
function target_snapshot(r)
    local player, transform, tc, ctrl = target_context(r)
    local fsm = player_fsm(player)
    local target=tc:call("get_TargetCharacter()")
    local target_type=tc:call("get_TargetType()")
    local party_index=nil
    for i,member in ipairs(r.party) do if target==member then party_index=i;break end end
    return {target_is_player=target == player, target_is_self=target == r.result.chara,
        target_party_index=party_index, target_has_character=target~=nil,
        target_character_id=target and target:get_Valid() and target:get_CharaIDString() or nil,
        target_type=tostring(target_type), target_type_name=target_type_name(target_type),
        character_target_position=vector(tc:call("get_TargetPosition()")),
        flight_target_position=vector(ctrl:call("get_TargetPosition()")),
        player_position=vector(transform:call("get_Position()")),
        player_fsm_enabled=fsm and fsm:call("get_Enabled()"),
        freeze_requested=active and active.freeze_requested or false}
end
function read_target_probe(d)
    if d.target_probe_failed then return {error=d.target_probe_failed} end
    local ok, value = pcall(function()
        assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
        return target_snapshot(d.spawn)
    end)
    if ok then return value end
    d.target_probe_failed = tostring(value)
    event("target_probe_error", d.target_probe_failed)
    return {error=d.target_probe_failed}
end
function anchor_positions(d)
    local scene=vector(d.transform:call("get_Position()"))
    local universal=vector(d.transform:call("get_UniversalPosition()"))
    local ctx=vector(d.context:call("get_Pos()"))
    return {transform=scene,controller=vector(d.controller:call("get_Position()")),
        context={x=ctx.x-universal.x+scene.x,y=ctx.y-universal.y+scene.y,z=ctx.z-universal.z+scene.z},
        root_bone=d.root_joint and d.root_joint:get_Valid() and vector(d.root_joint:call("get_Position()")) or nil,
        hip=d.hip_joint and d.hip_joint:get_Valid() and vector(d.hip_joint:call("get_Position()")) or nil}
end
menu.route_bind=function(d)
    local _,_,tc,ctrl=target_context(d.spawn)
    local result=d.spawn.result
    local manager=result.chara:call("get_ActionManager()")
    assert(manager and manager:call("get_GameObject()")==result.go,"ActionManager binding changed")
    return {go=result.go,character=result.chara,transform=result.chara:call("get_Transform()"),
        tc=tc,ctrl=ctrl,manager=manager}
end

-- Hooks only aggregate in memory. No disk I/O or per-hit snapshots in native callbacks.
passengers.record_protection=function(a,route,blocked,detail)
    if not debug_tools.enabled or not a then return end
    local key=(a.group or "player")..":"..(a.slot or 0)..":"..route..(blocked and ":blocked" or ":observed")
    local counts=passengers.protection.counts
    counts[key]=(counts[key] or 0)+1
    a.protection_counts=a.protection_counts or {}
    a.protection_counts[route]=(a.protection_counts[route] or 0)+1
    a.protection_dirty=true
    a.protection_routes=a.protection_routes or {}
    a.protection_routes[route]=blocked and "blocked" or "observed"
    if route=="fall" or route=="pawnLost.InstanceInfo" or route=="requestDestroy.exactContainer" then
        a.request_windows=a.request_windows or {}
        local w=a.request_windows[route]
        if not w then
            w={first_time=now(),first_frame=passengers.frame,hits=0,peak_per_behavior_frame=0,
                first_health=a.health_probe,instance=tostring(a.player)}
            a.request_windows[route]=w
            if detail then
                local ok,value=pcall(passengers.read_instance_info,detail,a)
                if ok then w.argument=value else w.argument_error=tostring(value) end
            end
        end
        w.hits=w.hits+1;w.last_time=now()
        if w.last_frame~=passengers.frame then w.hits_this_frame=0 end
        w.last_frame=passengers.frame;w.hits_this_frame=(w.hits_this_frame or 0)+1
        w.peak_per_behavior_frame=math.max(w.peak_per_behavior_frame,w.hits_this_frame)
    end
end
-- Called only after the controlled entity has been positioned and its controller warped.
passengers.apply_fall_experiment=function(a)
    if not passengers.fall_experiment.reset or a.fall_experiment_failed
        or passengers.controlled(a.player,true)~=a then return end
    local ok,err=pcall(function()
        assert(owned_player(a,false),"Fall reset interface ownership changed")
        passengers.reset_fall(a)
        a.player:set_field("SecFall",0.0)
        a.fall_experiment_resets=(a.fall_experiment_resets or 0)+1
    end)
    if not ok then
        a.fall_experiment_failed=true
        event("fall_reset_experiment_error",{group=a.group or "player",slot=a.slot,error=tostring(err)},true)
    end
end
passengers.set_fall_experiment=function(key,value)
    assert(key=="reset" or key=="ground")
    if key=="ground" and value then
        local ok,err=pcall(debug_tools.install_ground_hook,debug_tools)
        if not ok then debug_tools.status="着地实验未开启："..tostring(err);return false end
    end
    passengers.fall_experiment[key]=value==true
    if key=="reset" then
        passengers.each_controlled(function(a) a.fall_experiment_failed=nil end)
    end
    event("fall_experiment_mode",{reset=passengers.fall_experiment.reset,ground=passengers.fall_experiment.ground})
end
-- Griffin shares Character/FallInfoHolder APIs, but is never a seated passenger.
passengers.griffin_fall_owned=function(a)
    return alive and active and a.driver==active and a.spawn==active.spawn
        and validate_spawn(a.spawn)==a.player and a.player:call("get_Transform()")==a.transform
        and a.player:get_field("<FallInfo>k__BackingField")==a.fall
end
passengers.set_griffin_fall=function(value)
    local p=passengers.griffin_fall;p.reset=value==true
    if p.actor then p.actor.fall_experiment_failed=nil;p.actor.probe_at=nil end
    p.status=p.reset and "狮鹫跌落实验：已开启，驾驶时处理" or "狮鹫跌落实验：关闭"
    event("griffin_fall_experiment_mode",{reset=p.reset})
end
passengers.griffin_fall_tick=function()
    local p=passengers.griffin_fall;local d=active
    if not p.reset and not debug_tools.enabled then p.actor=nil;return end
    if not alive or not d then p.actor=nil;return end
    if menu.gameplay_paused() then return end
    local ok,err=pcall(function()
        local ch=validate_spawn(d.spawn)
        local a=p.actor
        if not a or a.driver~=d or a.player~=ch then
            local terrain=ch:get_field("<AdjustTerrain>k__BackingField")
            a={group="griffin",slot=0,driver=d,spawn=d.spawn,player=ch,transform=ch:call("get_Transform()"),
                fall=ch:get_field("<FallInfo>k__BackingField"),context=ch:get_field("<PosRotContext>k__BackingField"),
                controller=terrain and terrain.MainCharacterController}
            p.actor=a
        end
        assert(passengers.griffin_fall_owned(a),"Griffin fall interface changed")
        local sample=debug_tools.enabled and now()>=(a.probe_at or -math.huge)
        local before=sample and passengers.read_fall_probe(a) or nil
        if p.reset and not a.fall_experiment_failed then
            local reset_ok,reset_err=pcall(function()
                assert(a.fall,"Griffin FallInfoHolder unavailable")
                passengers.reset_fall(a)
                a.player:set_field("SecFall",0.0)
                a.fall_experiment_resets=(a.fall_experiment_resets or 0)+1
            end)
            if not reset_ok then
                a.fall_experiment_failed=true
                event("griffin_fall_reset_error",tostring(reset_err),true)
                p.status="狮鹫跌落重置失败："..tostring(reset_err)
            else p.status="狮鹫跌落重置中："..(a.fall_experiment_resets or 0).." 次" end
        end
        if sample then
            a.probe_at=now()+0.5
            a.probe={before=before,after=passengers.read_fall_probe(a),reset=p.reset}
        end
        if d.trace then d.trace.griffin_fall=a.probe end
    end)
    if not ok and now()>=(p.error_at or -math.huge) then
        p.error_at=now()+5;p.status="狮鹫跌落接口不可用："..tostring(err)
        event("griffin_fall_probe_error",tostring(err),true)
    end
end
passengers.read_instance_info=function(info,a)
    local argument_ch=info:get_field("<Chara>k__BackingField")
    local container=info:get_field("<Container>k__BackingField")
    local matches={}
    passengers.each_controlled(function(actor)
        if actor.generate_container==container then matches[#matches+1]={group=actor.group,slot=actor.slot,instance=tostring(actor.player)} end
    end)
    return {character=tostring(argument_ch),character_matches=argument_ch==a.player,container_matches=matches,
        canceled=info:get_field("<Canceled>k__BackingField"),deleted=info:get_field("<Deleted>k__BackingField"),
        failed=info:get_field("<Failed>k__BackingField")}
end
passengers.read_fall_probe=function(a)
    local value={time=now(),behavior_frame=passengers.frame,instance=tostring(a.player)}
    local is_griffin=a.group=="griffin"
    local owner_ok,owned=pcall(function() return is_griffin and passengers.griffin_fall_owned(a) or not is_griffin and owned_player(a,false) end)
    if not owner_ok or not owned then value.error="Interface ownership changed";return value end
    local function read(key,fn)
        local ok,v=pcall(fn)
        if ok then value[key]=v else value.errors=value.errors or {};value.errors[key]=tostring(v) end
    end
    read("ground",function() return a.player:call("get_IsGround()") end)
    value.ground_original=a.ground_original
    value.ground_original_time=a.ground_original_time
    value.ground_override=not is_griffin and passengers.fall_experiment.ground or false
    value.continuous_fall_reset=is_griffin and passengers.griffin_fall.reset or not is_griffin and passengers.fall_experiment.reset
    if is_griffin then read("flight",function() return a.player:call("get_IsFlight()") end) end
    value.fall_reset_count=a.fall_experiment_resets or 0
    value.fall_reset_failed=a.fall_experiment_failed or false
    read("sec_fall",function() return a.player:get_field("SecFall") end)
    read("fall",function()
        return {height=a.fall:get_field("<FallHeight>k__BackingField"),
            landing_height=a.fall:get_field("<FallHeightOnLanding>k__BackingField"),
            damage_check_height=a.fall:get_field("<HeightCheckDamageFromFall>k__BackingField"),
            base_universal=vector(a.fall:get_field("BaseFallHeight")),
            highest_universal=vector(a.fall:get_field("<HighestPositionOnAir>k__BackingField"))}
    end)
    read("positions",function()
        return {scene=vector(a.transform:call("get_Position()")),
            universal=vector(a.transform:call("get_UniversalPosition()")),
            context_universal=vector(a.context:call("get_Pos()")),
            controller_scene=vector(a.controller:call("get_Position()"))}
    end)
    read("landing",function()
        local landing=a.player:get_field("<LandingProcessor>k__BackingField")
        if not landing then return {available=false} end
        return {available=true,object_ground=landing:get_field("<IsObjectGround>k__BackingField"),
            keep_ground=landing:get_field("<IsKeepGround>k__BackingField"),
            previous_keep_ground=landing:get_field("<IsPrevKeepGround>k__BackingField"),
            last_ground_universal=vector(landing:get_field("<LastGroundPosition>k__BackingField"))}
    end)
    read("safe_position",function()
        local recorder=a.player:get_field("<FallPreventerPosRecorder>k__BackingField")
        if not recorder then return {available=false} end
        return {available=true,unsafe=recorder:get_field("IsUnsafe"),universal=vector(recorder:get_field("<Pos>k__BackingField"))}
    end)
    return value
end
passengers.probe_tick=function()
    if not active then return end
    passengers.each_controlled(function(a)
        if a.protection_dirty and now()>=(a.protection_log_at or -math.huge) then
            a.protection_log_at=now()+5;a.protection_dirty=false
            local counts,routes={},{}
            for key,value in pairs(a.protection_counts or {}) do counts[key]=value end
            for key,value in pairs(a.protection_routes or {}) do routes[key]=value end
            event("rider_protection",{group=a.group or "player",slot=a.slot,counts=counts,routes=routes,
                windows=passengers.snapshot(a.request_windows),latest_health=passengers.snapshot(a.health_probe)},true)
            a.request_windows=nil
        end
        if now()<(a.health_probe_at or -math.huge) then return end
        a.health_probe_at=now()+0.5
        local ok,value=pcall(function()
            -- Metadata-verified read-only getters; no HP refill or forced resurrection.
            passengers.capture_probe_refs(a)
            local b=a.brine
            return {hp=a.player:call("get_Hp()"),dead=a.player:call("get_IsDead()"),
                fall_dead=a.player:call("get_IsFallDead()"),cause=tostring(a.player:call("get_CauseOfDeath()")),
                brine=b and b["<IsKilledByBrine>k__BackingField"] or false,
                wall_brine=b and b["<IsKilledByWallBrine>k__BackingField"] or false,
                position=vector(a.transform:call("get_Position()")),container_available=a.generate_container~=nil,
                generate_destroyed=a.generate_info and a.generate_info:call("get_IsExecutedDestroy()") or false,
                physics=passengers.read_fall_probe(a)}
        end)
        if not ok then
            if not a.health_probe_error then event("rider_health_probe_error",{group=a.group or "player",slot=a.slot,error=tostring(value)},true);a.health_probe_error=true end
            return
        end
        local previous=a.health_probe
        a.health_probe=value
        if not previous or previous.hp~=value.hp or previous.dead~=value.dead or previous.fall_dead~=value.fall_dead
            or previous.cause~=value.cause or previous.brine~=value.brine or previous.wall_brine~=value.wall_brine
            or previous.generate_destroyed~=value.generate_destroyed then
            event("rider_health_changed",{group=a.group or "player",slot=a.slot,before=previous,after=value},true)
        end
    end)
end
passengers.record_release_context=function(a,reason,valid)
    if not debug_tools.enabled then return end
    local value={group=a.group,slot=a.slot,instance=tostring(a.player),reason=reason,valid=valid,
        health=a.health_probe,protection=passengers.snapshot(a.protection_counts or {})}
    if valid then
        local ok,detail=pcall(function()
            local info=a.player:get_field("<GenerateInfo>k__BackingField")
            return {hp=a.player:call("get_Hp()"),dead=a.player:call("get_IsDead()"),
                gameobject_valid=a.player_go:get_Valid(),interfaces_match=owned_player(a,false),
                generate_destroyed=info and info:call("get_IsExecutedDestroy()") or false,
                generate_info_unchanged=info==a.generate_info,
                position=vector(a.transform:call("get_Position()"))}
        end)
        if ok then value.current=detail else value.read_error=tostring(detail) end
    end
    event("passenger_release_context",value)
end

function debug_tools:sample()
    if self.enabled and active and active.trace and now() >= next_sample then
        next_sample = now()+0.5
        active.trace.rider_health=active.health_probe
        active.trace.target_probe = read_target_probe(active)
        local positions_ok,positions=pcall(anchor_positions,active)
        active.trace.anchor_positions=positions_ok and positions or {error=tostring(positions)}
        local sphere=active.trace.navigation_sphere
        if sphere and positions_ok then
            local p,h=positions.transform,sphere.center
            sphere.sampled_player_distance=math.sqrt((p.x-h.x)^2+(p.y-h.y)^2+(p.z-h.z)^2)
        end
        self:rotate()
        if #journal.samples>=600 then
            table.remove(journal.samples,1);journal.dropped_samples=(journal.dropped_samples or 0)+1
        end
        journal.samples[#journal.samples+1] = {time=now(), data=passengers.snapshot(active.trace)}
        journal_dirty=true
    end

    if self.enabled and not active and journal_dirty then self:flush() end
end
function debug_tools:install_ground_hook()
    if self.ground_installed then return end
    local errors={}
    -- IsGround has no setter/backing field in app.Character. Override only this query,
    -- retaining the native result in telemetry; do not forge collision/landing contacts.
    local ground_ok,ground_err=pcall(function()
        local td=sdk.find_type_definition("app.Character")
        local method=assert(td and td:get_method("get_IsGround()"),"Character.IsGround unavailable")
        sdk.hook(method,function(args)
            local storage=thread.get_hook_storage()
            storage.griffin_beta_ground_actor=nil
            if alive and active and passengers.fall_experiment.ground then
                local ch=sdk.to_managed_object(args[2])
                storage.griffin_beta_ground_actor=passengers.controlled(ch,true)
            end
        end,function(ret)
            local a=thread.get_hook_storage().griffin_beta_ground_actor
            if a and passengers.fall_experiment.ground and passengers.controlled(a.player,true)==a then
                a.ground_original=sdk.to_int64(ret)~=0
                a.ground_original_time=now()
                return sdk.to_ptr(1)
            end
            return ret
        end)
    end)
    if not ground_ok then errors[#errors+1]="Ground experiment: "..tostring(ground_err) end

    assert(ground_ok,ground_err)
    self.ground_installed=true
end
function debug_tools:install_observers()
    if self.observers_installed then return end
    self.observers_installed=true
    local function hook(type_name,signature,pre)
        local ok=pcall(function()
            local td=sdk.find_type_definition(type_name)
            local method=assert(td and td:get_method(signature))
            sdk.hook(method,function(args)
                if alive and debug_tools.enabled then pcall(pre,args) end
            end,function(ret) return ret end)
        end)
        if not ok then self.status="部分诊断接口不可用" end
    end
    for _,signature in ipairs({"setHp(System.Single, System.Boolean, System.Int32)","setHpValue(System.Single, System.Boolean)"}) do
        hook("app.HitController",signature,function(args)
            if not active then return end
            local a=passengers.component_actor(sdk.to_managed_object(args[2]))
            if a then passengers.record_protection(a,signature,false) end -- healing/setup must pass
        end)
    end
    hook("app.BrineProcessor","onKillCommon()",function(args)
        if not active then return end
        local processor=sdk.to_managed_object(args[2])
        if not processor then return end
        local a=passengers.each_controlled(function(actor) if actor.brine==processor then return actor end end)
        if a then passengers.record_protection(a,"BrineProcessor.onKillCommon",false) end
    end)
    -- Observe execution/notification only. Never skip destructors or destruction callbacks.
    hook("app.GenerateInfo","applyDestroy()",function(args)
        if not active then return end
        local info=sdk.to_managed_object(args[2])
        if not info then return end
        local a=passengers.each_controlled(function(actor) if actor.generate_info==info then return actor end end)
        if a then passengers.record_protection(a,"GenerateInfo.applyDestroy",false) end
    end)
    hook("app.Character","onDestroyCharacterByGenerator()",function(args)
        if not active then return end
        local a=passengers.controlled(sdk.to_managed_object(args[2]),true)
        if a then passengers.record_protection(a,"Character.onDestroyCharacterByGenerator",false) end
    end)

end
function debug_tools:draw()
    if not imgui.tree_node("DEBUG") then return end
    imgui.text("默认不采样、不写调试日志；用户设置照常保存。")
    local changed,value=menu.toggle("禁止跨阶段动作",menu.block_cross_phase)
    if changed then menu.block_cross_phase=value end
    imgui.text("默认开启：地面不发悬停／冲刺／降落，空中不发起飞；仅本次脚本会话。")
    changed,value=menu.toggle("开启调试记录（暂停／结束驾驶后写盘）",self.enabled)
    if changed then self:set_enabled(value) end
    imgui.text(self.status)
    changed,value=menu.toggle("三秒逐帧精细记录（暂停后保存）",self.fine.running)
    if changed then if value then self.fine:start() else self.fine:stop("手动停止") end end
    imgui.text(self.fine.status)
    imgui.text(anti_jitter.fall_stop.status);imgui.text(anti_jitter.griffin_stop.status)
    imgui.text("已阻止重新落体：玩家 "..anti_jitter.fall_stop.start_calls.." 次；座位NPC "..anti_jitter.fall_stop.passenger_start_calls.." 次")
    for _,mode in ipairs(anchor_modes) do
        local changed,value=menu.toggle(mode.label.."###BetaAnchor_"..mode.key,anchor_mode==mode.key)
        if changed then change_anchor_mode(value and mode.key or (mode.key=="full" and "rider" or "full")) end
    end
        local changed,value=menu.toggle("显示预设[1]（仅手动调试）",menu.show_physical)
        if changed then
            menu.show_physical=value
            if not value then
                if settings.seat_index==1 or menu.selected_index==1 then menu.queue_preset(menu.last_normal or 2) end
                if menu.pending_preset==settings.seat_presets[1] then menu.pending_preset=nil end
            end
        end
        if menu.show_physical then imgui.text("在座位预设的当前布局中选择[1]，编辑实体位置。") end
        changed,value=menu.toggle("【实验1】持续重置跌落高度＋SecFall",passengers.fall_experiment.reset)
        if changed then passengers.set_fall_experiment("reset",value) end
        changed,value=menu.toggle("【实验2】强制IsGround返回着地",passengers.fall_experiment.ground)
        if changed then passengers.set_fall_experiment("ground",value) end
        changed,value=menu.toggle("【实验3】狮鹫持续重置跌落高度＋SecFall",passengers.griffin_fall.reset)
        if changed then passengers.set_griffin_fall(value) end
        imgui.text(passengers.griffin_fall.status)
        local griffin_probe=passengers.griffin_fall.actor and passengers.griffin_fall.actor.probe
        if griffin_probe then
            local before,after=griffin_probe.before or {},griffin_probe.after or {}
            imgui.text("狮鹫 SecFall："..tostring(before.sec_fall).." → "..tostring(after.sec_fall)
                .."；跌落高度："..tostring(before.fall and before.fall.height).." → "..tostring(after.fall and after.fall.height))
        end
        changed,value=menu.toggle("驾驶玩家／乘客扣血拦截",passengers.protection.damage)
        if changed then passengers.protection.damage=value end
        changed,value=menu.toggle("阻止落座乘客自动传送／丢失",passengers.protection.relocation)
        if changed then passengers.protection.relocation=value end
        changed,value=menu.toggle("跳过随从丢失检查",passengers.protection.lost_check)
        if changed then passengers.protection.lost_check=value;event("lost_check_guard_mode",value) end
        changed,value=menu.toggle("阻止乘客被生成器销毁",passengers.protection.destroy)
        if changed then passengers.protection.destroy=value;event("destroy_guard_mode",value) end
        imgui.text("两项额外拦截仅在驾驶期间生效；诊断记录需要手动开启。")
        imgui.text(passengers.protection.status or "乘客保护：开始驾驶后安装")
        if imgui.tree_node("运行诊断") then
            for key,count in pairs(passengers.protection.counts) do imgui.text(key.."："..count) end
            imgui.tree_pop()
        end
        if beta_button((skip_think_enabled and "关闭跳过狮鹫思考" or "开启跳过狮鹫思考").."###BetaThinkToggle") then set_skip_think(not skip_think_enabled) end
        imgui.text(skip_think_status)
        local changed,value=menu.toggle("拦截驾驶角色坠落死亡请求",block_player_fall)
        if changed then block_player_fall=value;if active then install_fall_hook() end;event("fall_request_block_mode",value) end
        changed,value=menu.toggle("冻结玩家 FSM",settings.freeze_player)
        if changed then change_player_freeze(value) end
        imgui.text("坠落请求："..fall_hits.."；拦截："..fall_blocked)
        imgui.text(yaw_status);imgui.text(camera_follow_status)
        if active and active.trace then imgui.text("当前动作："..active.trace.action) end
        imgui.text("LB／RB超过59°时曾出现黑屏；是否由过快坠落引起尚未确认。")

    imgui.tree_pop()
end
end
