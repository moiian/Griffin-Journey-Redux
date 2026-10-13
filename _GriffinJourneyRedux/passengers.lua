-- Griffin Journey Redux: passengers
return function(ctx)
local _ENV=ctx
passengers.play_pose=function(a,node)
    assert(active and alive and not menu.gameplay_paused(),"请开始驾驶并关闭暂停菜单后播放")
    assert(owned_player(a,false) and player_fsm(a.player)==a.fsm,"Animation actor binding changed")
    node=type(node)=="string" and node:match("^%s*(.-)%s*$") or ""
    if node=="" then return end
    local manager=assert(a.player:call("get_ActionManager()"),"Actor ActionManager unavailable")
    a.fsm_touched=true
    a.pose_freeze_frame=passengers.frame+1
    a.fsm:call("set_Enabled(System.Boolean)",true)
    local ok,err=pcall(function()
        manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",1,node,0)
    end)
    if not ok then
        local desired=false
        if not a.group and not settings.freeze_player then desired=a.original_fsm end
        a.fsm:call("set_Enabled(System.Boolean)",desired)
        a.pose_freeze_frame=nil;error(err)
    end
    a.fall_reset_pending=true
    event("seat_animation_requested",{group=a.group or "player",slot=a.slot,node=node})
end
passengers.tick_pose=function(a)
    if a.pose_freeze_frame and passengers.frame>=a.pose_freeze_frame then
        local desired=false
        if not a.group and not settings.freeze_player then desired=a.original_fsm end
        a.fsm:call("set_Enabled(System.Boolean)",desired)
        assert(a.fsm:call("get_Enabled()")==desired,"Animation FSM freeze readback mismatch")
        a.pose_freeze_frame=nil
    end
    if a.pose_pending~=nil then
        local node=a.pose_pending;a.pose_pending=nil
        local ok,err=pcall(passengers.play_pose,a,node)
        if not ok then event("seat_animation_error",{group=a.group or "player",slot=a.slot,error=tostring(err)});status="动画请求失败："..tostring(err) end
    end
end

passengers.visual_seat=function(group,index)
    if settings.seat_index==1 then return passengers.seat(group,index,settings.seat_presets[1]) end
    return passengers.seat(group,index)
end
passengers.restore_one=function(a)
    anti_jitter:forget_passenger(a)
    if not a.player:get_Valid() then
        a.bones_applied=nil;a.moved=false;a.fsm_touched=false;return
    end
    assert(owned_player(a,false),"Passenger binding changed; retained for recovery")
    restore_bone(a)
    passengers.restore_rotation(a)
    local pose_enabled=a.pose_freeze_frame~=nil
    a.pose_pending=nil
    if a.moved then
        if core() and core().properties.player==a.owner then
            -- Hip display is restored above; keep the current physical location.
            sync_player(a,true)
        end
        a.moved=false
    end
    if a.fsm_touched then
        assert(player_fsm(a.player)==a.fsm,"Passenger FSM changed; retained for recovery")
        -- Preserve third-party re-enabling, except the explicit pose window we own.
        if a.fsm:call("get_Enabled()")==false or pose_enabled then a.fsm:call("set_Enabled(System.Boolean)",a.original_fsm) end
        a.fsm_touched=false
    end
    a.pose_freeze_frame=nil
end
passengers.restore_all=function(d)
    local errors={}
    for ch,a in pairs(d.passengers or {}) do
        local ok,err=pcall(passengers.restore_one,a)
        if ok then d.passengers[ch]=nil else errors[#errors+1]=tostring(err) end
    end
    return errors
end
passengers.bind=function(d,ch,group,index)
    assert(ch:get_Valid(),"Passenger unloaded")
    local terrain=ch:get_field("<AdjustTerrain>k__BackingField")
    local a={player=ch,owner=d.player,spawn=d.spawn,fall_reset_pending=true,player_go=ch:call("get_GameObject()"),
        transform=ch:call("get_Transform()"),context=ch:get_field("<PosRotContext>k__BackingField"),terrain=terrain,
        controller=terrain and terrain.MainCharacterController,fall=ch:get_field("<FallInfo>k__BackingField"),
        fsm=player_fsm(ch),group=group,slot=index,anchor_mode="rider"}
    assert(a.player_go and a.transform and a.context and a.controller and a.fall and a.fsm,"Passenger interfaces unavailable")
    assert(owned_player(a,false),"Passenger interface ownership mismatch")
    a.original_fsm=a.fsm:call("get_Enabled()")
    assert(type(a.original_fsm)=="boolean","Passenger original state unavailable")
    discover_joints(a)
    assert(a.hip_joint and a.hip_joint:get_Valid(),"Passenger Hip unavailable")
    a.pose_pending=passengers.visual_seat(group,index).anim
    pcall(passengers.capture_probe_refs,a) -- ready before the first anchored game tick
    d.passengers[ch]=a -- recovery registered before the first native mutation
    event("passenger_bound",{group=group,slot=index,instance=tostring(ch)})
    return a
end
passengers.prepare_rig=function(a,d)
    a.heading=d.heading;a.body_pitch=d.body_pitch;a.rider_griffin_transform=d.rider_griffin_transform
    a.rider_head=d.rider_head;a.rider_head_name=d.rider_head_name;a.rider_necks=d.rider_necks
end
passengers.tick=function(d)
    d.passengers=d.passengers or {}
    passengers.last_error=nil
    local wanted={}
    for _,group in ipairs({"pawns","companions"}) do
        for i,ch in ipairs((passengers.roster or {})[group] or {}) do
            local seat=passengers.seat(group,i)
            if seat.enabled and ch:get_Valid() then wanted[ch]={group=group,slot=i} end
        end
    end
    for ch,a in pairs(d.passengers) do
        local valid=ch:get_Valid()
        if not wanted[ch] or not valid then
            local in_roster=false
            for _,member in ipairs((passengers.roster or {})[a.group] or {}) do if member==ch then in_roster=true end end
            local reason=not valid and "invalid_instance" or (in_roster and "seat_disabled" or "absent_from_engine_roster")
            passengers.record_release_context(a,reason,valid)
            if not valid then event("passenger_unloaded",{group=a.group,slot=a.slot,instance=tostring(ch),protection=a.protection_counts,health=a.health_probe}) end
            a.anchor_target=nil
            local ok,err=pcall(passengers.restore_one,a)
            if ok then d.passengers[ch]=nil;event("passenger_released",{group=a.group,slot=a.slot})
            elseif not a.restore_error_logged then event("passenger_restore_error",tostring(err));a.restore_error_logged=true end
        end
    end
    d.passenger_trace=debug_tools and debug_tools:recording() and {} or nil
    for ch,slot in pairs(wanted) do
        local ok,err=pcall(function()
            local a=d.passengers[ch] or passengers.bind(d,ch,slot.group,slot.slot)
            assert(not a.recovery_pending,"Passenger recovery pending")
            assert(owned_player(a,false) and player_fsm(ch)==a.fsm,"Passenger binding changed")
            assert(a.hip_joint and a.hip_joint:get_Valid(),"Passenger Hip unavailable")
            a.group=slot.group;a.slot=slot.slot
            passengers.prepare_rig(a,d)
            restore_bone(a)
            local current=a.fsm:call("get_Enabled()")
            if current~=false and not a.pose_freeze_frame then
                a.fsm_touched=true;a.fsm:call("set_Enabled(System.Boolean)",false)
                assert(a.fsm:call("get_Enabled()")==false,"Passenger freeze readback mismatch")
            end
            -- Each passenger always uses its own slot in preset [1] for real position.
            local physical=rider_seat(a,passengers.seat(a.group,a.slot,settings.seat_presets[1]))
            a.moved=true;a.anchor_target=physical;a.neutral_anchor=physical
            a.transform:call("set_Position(via.vec3)",Vector3f.new(physical.x,physical.y,physical.z))
            passengers.orient(a,passengers.visual_seat(a.group,a.slot))
            sync_player(a)
            passengers.apply_fall_experiment(a)
            anti_jitter:after_passenger(d,a)
            passengers.tick_pose(a)
            if d.passenger_trace then d.passenger_trace[#d.passenger_trace+1]={group=a.group,slot=a.slot,physical=physical,fsm_enabled=a.fsm:call("get_Enabled()"),protection=a.protection_counts,health=a.health_probe,orientation=a.orientation_trace,orientation_failed=a.orientation_failed or false} end
        end)
        if not ok then
            passengers.last_error=slot.group.." "..slot.slot..": "..tostring(err)
            local key=slot.group..":"..slot.slot
            passengers.errors=passengers.errors or {}
            if now()>=(passengers.errors[key] or -math.huge) then
                passengers.errors[key]=now()+5;event("passenger_control_error",{group=slot.group,slot=slot.slot,error=tostring(err)})
            end
            -- A partial write must recover before retrying. Keep failures for stop/reset recovery.
            local a=d.passengers[ch]
            if a then
                a.anchor_target=nil;a.recovery_pending=true
                local restored=pcall(passengers.restore_one,a)
                if restored then d.passengers[ch]=nil end
            end
        end
    end
    if d.trace then d.trace.passengers=d.passenger_trace end
end
passengers.pre=function()
    if not alive or not active or not menu.visual_allowed() then return end
    for _,a in pairs(active.passengers or {}) do
        local ok,err=pcall(function()
            restore_bone(a)
            if a.anchor_target then passengers.orient(a,passengers.visual_seat(a.group,a.slot)) end
        end)
        if not ok then event("passenger_bone_restore_error",tostring(err)) end
    end
end
passengers.post=function()
    local d=active
    if not alive or not d or not menu.visual_allowed() then return end
    for _,a in pairs(d.passengers or {}) do
        if a.anchor_target then
            local ok,err=pcall(function()
                assert(owned_player(a,false),"Passenger changed")
                restore_bone(a)
                local actor=vector(a.transform:call("get_Position()"))
                local seat=rider_seat(a,passengers.visual_seat(a.group,a.slot))
                local items={}
                for _,spec in ipairs({{joint=a.root_joint,key="root"},{joint=a.hip_joint,key="hip"}}) do
                    local joint=spec.joint
                    if joint and joint:get_Valid() then
                        local original=vector(joint:call("get_Position()"))
                        local anchor=spec.key=="hip" and seat or a.neutral_anchor
                        items[#items+1]={joint=joint,original=original,
                            written={x=anchor.x+original.x-actor.x,y=anchor.y+original.y-actor.y,z=anchor.z+original.z-actor.z}}
                    end
                end
                a.bones_applied=items
                for _,item in ipairs(items) do item.joint:call("set_Position(via.vec3)",Vector3f.new(item.written.x,item.written.y,item.written.z)) end
            end)
            if not ok and not a.pose_error_logged then event("passenger_pose_error",tostring(err));a.pose_error_logged=true end
        end
    end
end
end
