return function(ctx)
local _ENV=ctx
function change_anchor_mode(key)
    local d=active
    if not d then anchor_mode=key;settings.anchor_mode=key;event("anchor_mode_selected",key);return end
    run_once(function()
        if not alive or active~=d then return end
        local mutating=false
        local ok,err=pcall(function()
            validate_spawn(d.spawn)
            assert(owned_player(d,true),"Player binding changed")
            prepare_anchor_mode(d,key)
            mutating=true
            restore_bone(d)
            -- Normalize layers to the current player Transform once, at the boundary.
            sync_player(d)
            d.anchor_mode=key;anchor_mode=key;settings.anchor_mode=key;d.anchor_target=nil;d.neutral_anchor=nil;d.anchor_plan=nil;d.target_probe_failed=nil
            event("anchor_mode_changed",{mode=key,baseline=anchor_positions(d)})
        end)
        if not ok then
            if mutating then stop_driver("位置实验切换未完成") end
            failed("位置实验切换失败",err)
        end
    end)
end
-- Head-joint camera follow; independent of navigation.
end
