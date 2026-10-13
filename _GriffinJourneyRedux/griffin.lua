-- Griffin Journey Redux: griffin
return function(ctx)
local _ENV=ctx
function target_context(r)
    local ch = validate_spawn(r)
    local c = assert(core())
    local player = c.properties.player
    assert(player == r.owner and player:get_Valid(), "Player binding changed")
    local transform = player:call("get_Transform()")
    assert(transform and transform == c.properties.transform, "Player transform changed")
    local component = c.object.get_component(r.result.go, "app.Ch253")
    local tc = component and component:call("get_TargetController()")
    assert(tc and tc:call("get_Owner()") == r.result.go and tc:call("get_Chara()") == ch,
        "TargetController binding mismatch")
    local ctrl = ch:call("get_FlightCtrl()")
    assert(ctrl and ctrl:call("get_CachedCharacter()") == ch, "FlightControl binding mismatch")
    return player, transform, tc, ctrl
end
function select_player_target(r)
    local _,_,tc=target_context(r)
    local td=sdk.find_type_definition("app.TargetController.TargetTypeEnum")
    local field=td and td:get_field("ManualPlayer")
    local value=field and field:get_data()
    assert(finite(value), "ManualPlayer enum unavailable")
    local type_def=sdk.find_type_definition("app.TargetController")
    assert(type_def and type_def:get_method("setTarget(app.TargetController.TargetTypeEnum)"), "Target selection interface unavailable")
    assert(tc:call("get_ManualPlayerTarget()"), "ManualPlayer target unavailable")
    event("manual_player_target_request",{value=value,before=debug_tools and debug_tools.enabled and target_snapshot(r) or nil})
    tc:call("setTarget(app.TargetController.TargetTypeEnum)",value)
    if debug_tools and debug_tools.enabled then event("manual_player_target_returned",target_snapshot(r)) end
end
function request_instance_skip(result, player)
    assert(result and result.go and result.chara and result.go:get_Valid() and result.chara:get_Valid(), "Griffin unavailable")
    local ch = result.chara
    assert(ch:get_CharaIDString()=="ch253000_00" and ch:call("get_GameObject()")==result.go, "Griffin binding mismatch")
    local maker=ch:call("get_AIDecisionMaker()")
    assert(maker and maker:call("get_Character()")==ch, "AIDecisionMaker mismatch")
    local module=maker:call("get_DecisionModule()")
    assert(module and module:call("get_Chara()")==ch and module:call("get_Owner()")==result.go
        and module:call("get_AIDecisionMaker()")==maker, "DecisionModule mismatch")
    local td=sdk.find_type_definition("app.AIDecisionModule")
    assert(td and td:get_method("requestSkipThink()") and td:get_method("get_IsSkipThink()"), "SkipThink interface unavailable")
    module:call("requestSkipThink()")
    assert(module:call("get_IsSkipThink()")==true, "SkipThink flag readback failed")
end

function set_skip_think(enabled)
    skip_think_enabled, skip_think_expected = false, nil
    if not enabled then skip_think_status="已停止请求跳过狮鹫思考。";event("skip_think_disabled",true);return true end
    local r=active and active.spawn or state.spawns[#state.spawns]
    if not alive or not r or not r.ready or r.delete_requested then return false,"请先生成并等待狮鹫就绪" end
    r.skip_retry_at=nil
    skip_think_expected=r
    skip_think_enabled=true
    skip_think_status="已开启逐帧跳过思考，等待首次请求。"
    event("skip_think_enabled",true)
    return true
end
function tick_skip_think()
    if not skip_think_enabled or not alive then return end
    local c,r=core(),skip_think_expected
    if not c or menu.gameplay_paused() then return end
    if not r or r.owner~=c.properties.player or r.delete_requested or state.spawns[#state.spawns]~=r then
        skip_think_enabled=false;skip_think_expected=nil;skip_think_status="跳过思考：实例已退出";return
    end
    if now()<(r.skip_retry_at or 0) then return end
    local ok,err=pcall(request_instance_skip,r.result,r.owner)
    if ok then
        r.skip_retry_at=nil;r.skip_last_error=nil;r.skip_applied=true
        skip_think_status="跳过思考：已生效"
    else
        r.skip_applied=false;r.skip_retry_at=now()+0.25
        skip_think_status="跳过思考：等待模块就绪，自动重试"
        if not r.skip_error_time or now()-r.skip_error_time>=5 then
            r.skip_error_time=now();event("skip_think_retry",tostring(err))
        end
    end

end

fall_hook_installed,fall_hook_tried=false,false
block_player_fall=true
fall_hits,fall_blocked,fall_logged,fall_log_at=0,0,0,-math.huge
fall_hook_status="坠落死亡请求拦截：默认开启（驾驶玩家与接管乘客）"
function install_fall_hook()
    if fall_hook_installed or fall_hook_tried then return end
    fall_hook_tried=true
    local ok,err=pcall(function()
        local td=sdk.find_type_definition("app.Character")
        local method=td and td:get_method("requestFallDead()")
        assert(method and sdk.PreHookResult and sdk.PreHookResult.SKIP_ORIGINAL,"Fall request hook unavailable")
        sdk.hook(method,function(args)
            local d,c=active,core()
            if alive and d and c and not menu.gameplay_paused() and c.properties.player==d.player then
                local ch=sdk.to_managed_object(args[2])
                local member=d.passengers and d.passengers[ch]
                if ch==d.player and d.moved or member and member.moved and member.anchor_target and not member.recovery_pending then
                    fall_hits=fall_hits+1
                    passengers.record_protection(ch==d.player and d or member,"fall",block_player_fall)
                    if block_player_fall then fall_blocked=fall_blocked+1;return sdk.PreHookResult.SKIP_ORIGINAL end
                end
            end
        end,function(ret) return ret end)
        fall_hook_installed=true
    end)
    if not ok then fall_hook_status="坠落请求 Hook 不可用："..tostring(err);event("fall_hook_error",fall_hook_status) end
end
end
