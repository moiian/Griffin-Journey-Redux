return function(ctx,hook)
local _ENV=ctx
    -- Character and CharacterID overloads share their native address in this dump.
    -- Compare the raw pointer first; never cast an unknown CharacterID argument to Character.
    hook("app.PawnManager","onLostCheck(app.Character)",function(args)
        if not active then return end
        for ch,a in pairs(active.passengers or {}) do
            if a.group=="pawns" and args[3]==sdk.to_ptr(ch:get_address()) and passengers.controlled(ch) then
                passengers.record_protection(a,"onLostCheck.Character",passengers.protection.lost_check)
                if passengers.protection.lost_check then return sdk.PreHookResult.SKIP_ORIGINAL end
                return
            end
        end
    end)
    hook("app.GenerateManager","requestDestroy(app.GenerateInfo.GenerateInfoContainer, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean)",function(args)
        if not active then return end
        local a=passengers.container_actor(sdk.to_managed_object(args[3]))
        if a and a.group then
            passengers.record_protection(a,"requestDestroy.exactContainer",passengers.protection.destroy)
            if passengers.protection.destroy then return sdk.PreHookResult.SKIP_ORIGINAL end
        end
    end,true)
end
