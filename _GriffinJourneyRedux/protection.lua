-- Griffin Journey Redux: protection
return function(ctx)
local _ENV=ctx
passengers.each_controlled=function(fn)
    local d=active
    if not d then return end
    local a=passengers.controlled(d.player,true)
    if a then local value=fn(a);if value then return value end end
    for ch in pairs(d.passengers or {}) do
        a=passengers.controlled(ch)
        if a then local value=fn(a);if value then return value end end
    end
end
passengers.receiver=function(go)
    if not go then return end
    return passengers.each_controlled(function(a) if a.player_go==go then return a end end)
end
passengers.component_actor=function(component)
    if not component then return end
    local ch=component["<CachedCharacter>k__BackingField"]
    return ch and passengers.controlled(ch,true)
end
passengers.container_actor=function(container)
    if not container then return end
    -- Exact captured container only. Never walk parent/shared containers or match IDs.
    return passengers.each_controlled(function(a) if a.generate_container==container then return a end end)
end
passengers.capture_identity=function(a)
    local info=a.player:get_field("<GenerateInfo>k__BackingField")
    a.generate_info=info
    a.generate_container=info and info:call("get_Container()") or nil
end
passengers.install_protection=function()
    if passengers.protection.installed then return end
    passengers.protection.installed=true
    local errors={}
    local function hook(type_name,signature,pre,boolean_result)
        local ok,err=pcall(function()
            local td=sdk.find_type_definition(type_name)
            local m=assert(td and td:get_method(signature),signature.." unavailable")
            local key="griffin_beta_guard_"..type_name..signature
            sdk.hook(m,function(args)
                if boolean_result then thread.get_hook_storage()[key]=false end
                local success,result=pcall(pre,args)
                if success then
                    if boolean_result then thread.get_hook_storage()[key]=result==sdk.PreHookResult.SKIP_ORIGINAL end
                    return result
                end
            end,function(ret)
                if boolean_result and thread.get_hook_storage()[key] then return sdk.to_ptr(0) end
                return ret
            end)
        end)
        if not ok then errors[#errors+1]=tostring(err) end
    end
    for _,signature in ipairs({"damageProc(app.HitController.DamageInfo)","updateDamage(app.HitController.DamageInfo, System.UInt32, System.Single, System.Boolean)"}) do
        hook("app.HitController",signature,function(args)
            if not active then return end
            local info=sdk.to_managed_object(args[3])
            local a=passengers.receiver(info and info["<DamageGameObject>k__BackingField"])
            if a then
                if passengers.on_protection then passengers.on_protection(a,signature,passengers.protection.damage) end
                if passengers.protection.damage then return sdk.PreHookResult.SKIP_ORIGINAL end
            end
        end,signature=="damageProc(app.HitController.DamageInfo)")
    end
    -- Closer to HP application, covering direct routes that bypass damageProc/updateDamage.
    hook("app.HitController","updateDamageHp(app.HitController.DamageInfo, System.Single, System.Boolean)",function(args)
        if not active then return end
        local a=passengers.component_actor(sdk.to_managed_object(args[2]))
        if a then
            if passengers.on_protection then passengers.on_protection(a,"updateDamageHp",passengers.protection.damage) end
            if passengers.protection.damage then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end)
    for _,signature in ipairs({"safeWarp(app.Character, via.Position)","safeWarp(app.Character, via.Position, via.Quaternion)",
        "pawnLost(app.Character, System.Boolean, System.Boolean)","setPawnLostTimer(app.Character)"}) do
        hook("app.PawnManager",signature,function(args)
            if not active then return end
            local a=passengers.controlled(sdk.to_managed_object(args[3]))
            if a and a.group=="pawns" then
                if passengers.on_protection then passengers.on_protection(a,signature,passengers.protection.relocation) end
                if passengers.protection.relocation then return sdk.PreHookResult.SKIP_ORIGINAL end
            end
        end)
    end
    hook("app.PawnManager","pawnLost(app.InstanceInfo, app.DummyArg_2_0_0_37)",function(args)
        if not active then return end
        local info=sdk.to_managed_object(args[3])
        local a=passengers.container_actor(info and info["<Container>k__BackingField"])
        if a and a.group=="pawns" then
            if passengers.on_protection then passengers.on_protection(a,"pawnLost.InstanceInfo",passengers.protection.relocation,info) end
            if passengers.protection.relocation then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end)
    if passengers.extra_protection then passengers.extra_protection(hook) end
    passengers.protection.status=#errors==0 and "驾驶角色扣血／随从丢失保护已安装" or "部分保护不可用："..table.concat(errors,"; ")
    if event then event("passenger_protection_installed",{errors=errors}) end
end
end
