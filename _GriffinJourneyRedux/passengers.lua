-- Griffin Journey Redux: passengers
return function(ctx)
local _ENV=ctx
-- Reused from OJR journey.lua: same seven nodes and 5-30s / 10-45s intervals.
local idle_nodes={"SitOnChairActions","LivSitChairCrosslegs","LivSitChairLean",
    "SitOnChairCrossArmStart","LivSitPose","LivSitChairBook01","LivSitChairLoseieus"}
local function visual_spec(a)
    local preset=settings.seat_presets[settings.seat_index]
    if a.group then return preset[a.group] and preset[a.group][a.slot] end
    return preset.player
end
passengers.clear_seat_animation=function(a)
    a.idle_next=nil;a.idle_clock=nil;a.idle_layout=nil;a.idle_base=nil;a.idle_failed=nil;a.pelvis_state=nil
end
passengers.tick_random_pose=function(a)
    local spec=visual_spec(a)
    if not spec or spec.randomIdle~=true or settings.seat_index==1 then
        a.idle_next=nil;a.idle_clock=nil;a.idle_layout=nil;a.idle_base=nil;a.idle_failed=nil
        return
    end
    local t=now()
    if not a.idle_next or a.idle_layout~=settings.seat_index or a.idle_base~=spec.anim or t<(a.idle_clock or t) then
        a.idle_next=t+5+math.random()*25;a.idle_layout=settings.seat_index;a.idle_base=spec.anim;a.idle_failed=nil
    end
    a.idle_clock=t
    if a.idle_failed or a.pose_freeze_frame or t<a.idle_next then return end
    local node=idle_nodes[math.random(1,#idle_nodes)]
    local ok,err=pcall(passengers.play_pose,a,node)
    a.idle_next=t+10+math.random()*35
    if not ok then
        a.idle_failed=true;status="随机坐姿请求失败："..tostring(err)
        if event then event("random_seat_animation_error",{group=a.group or "player",slot=a.slot,error=tostring(err)}) end
    end
end
-- OJR pelvis.lua projection/baseline compensation, merged into our single owned
-- bone write. This avoids stacking a second correction/restore callback.
passengers.lock_pelvis=function(a,original,actor,target,spec)
    if spec.pelvisCompensation~=true or settings.seat_index==1 then a.pelvis_state=nil;return target end
    if a.pose_freeze_frame then return target end
    local _,up=passengers.basis(a,spec,true)
    local offset=(original.x-actor.x)*up.x+(original.y-actor.y)*up.y+(original.z-actor.z)*up.z
    local s=a.pelvis_state
    if not s or s.hip~=a.hip_joint or s.layout~=settings.seat_index then
        s={hip=a.hip_joint,layout=settings.seat_index,baseline=offset};a.pelvis_state=s
    end
    local delta=s.baseline-offset
    if math.abs(delta)>0.0001 then
        target={x=target.x+up.x*delta,y=target.y+up.y*delta,z=target.z+up.z*delta}
    end
    return target
end
passengers.play_pose=function(a,node)
    assert((active or passengers.held) and alive and not menu.gameplay_paused(),"请开始驾驶并关闭暂停菜单后播放")
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
    if event then event("seat_animation_requested",{group=a.group or "player",slot=a.slot,node=node}) end
end
passengers.tick_pose=function(a)
    if menu.gameplay_paused() then return end
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
        if not ok then if event then event("seat_animation_error",{group=a.group or "player",slot=a.slot,error=tostring(err)}) end;status="动画请求失败："..tostring(err) end
    end
    passengers.tick_random_pose(a)
end

passengers.visual_seat=function(group,index)
    if settings.seat_index==1 then return passengers.seat(group,index,settings.seat_presets[1]) end
    return passengers.seat(group,index)
end
passengers.restore_one=function(a)
    passengers.clear_seat_animation(a)
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
            -- Manual exit synchronizes the hidden preset [1] seat before releasing FSM.
            if not apply_exit_seat(a) then sync_player(a,true) end
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
    pcall(passengers.capture_identity,a) -- ready before the first anchored game tick
    d.passengers[ch]=a -- recovery registered before the first native mutation
    if event then event("passenger_bound",{group=group,slot=index,instance=tostring(ch)}) end
    return a
end
passengers.prepare_rig=function(a,d)
    a.heading=d.heading;a.body_pitch=d.body_pitch;a.rider_griffin_transform=d.rider_griffin_transform
    a.rider_head=d.rider_head;a.rider_head_name=d.rider_head_name;a.rider_necks=d.rider_necks
end
-- Only the already controlled passengers survive a confirmed high-altitude exit.
passengers.visual_allowed=function()
    if active then return menu.visual_allowed() end
    local d,c=passengers.held,core()
    if not alive or not d or d.held_releasing or not c or c.properties.player~=d.player then return false end
    return pcall(validate_spawn,d.spawn,true)
end
passengers.release_held=function(reason)
    local d=passengers.held
    if not d then return true,{} end
    d.held_releasing=true
    local errors=passengers.restore_all(d)
    if #errors==0 then
        passengers.held=nil
        status="悬停乘客已释放："..tostring(reason)
    else status="悬停乘客释放待重试："..table.concat(errors,"; ") end
    return #errors==0,errors
end
passengers.tick_held=function()
    local d=passengers.held
    if not d or not alive or menu.gameplay_paused() then return end
    local t=now()
    if d.held_last and t<d.held_last then d.held_next=nil end
    d.held_last=t
    if d.held_releasing then
        if not d.held_next or t>=d.held_next then d.held_next=t+.2;passengers.release_held("恢复重试") end
        return
    end
    local ok,err=pcall(function()
        local ch=validate_spawn(d.spawn)
        local tr=ch:call("get_Transform()")
        if not d.held_next or t>=d.held_next then
            d.held_next=t+.2
            assert(spawn_watch:mountable(d.spawn),"狮鹫不能继续承载乘客")
            assert(ch:call("get_IsFlight()") and not ch:call("get_IsGround()"),"狮鹫已结束悬空")
            local a=vector(d.player:call("get_Transform()"):call("get_UniversalPosition()"))
            local b=vector(tr:call("get_UniversalPosition()"))
            local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
            if x*x+y*y+z*z>225 then passengers.release_held("玩家离狮鹫超过15米");return end
        end
        if passengers.held~=d then return end
        local q=tr:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"狮鹫旋转无效")
        local norm=math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
        assert(norm>.0001,"狮鹫旋转长度无效")
        local qx,qy,qz,qw=q.x/norm,q.y/norm,q.z/norm,q.w/norm
        local x,z,length=passengers.horizontal_heading(d,qx,qy,qz,qw)
        d.heading={x=x,z=z}
        d.body_pitch=math.atan(2*(qy*qz-qw*qx),length)*180/math.pi
        if d.rider_griffin_transform~=tr or not d.rider_head or not d.rider_head:get_Valid() then prepare_rider(d) end
        passengers.tick(d)
        if not next(d.passengers) then passengers.held=nil end
    end)
    if not ok then passengers.release_held(err) end
end
passengers.tick=function(d)
    d.passengers=d.passengers or {}
    passengers.last_error=nil
    local wanted={}
    for _,group in ipairs({"pawns","companions"}) do
        for i,ch in ipairs((passengers.roster or {})[group] or {}) do
            local seat=passengers.seat(group,i)
            if seat.enabled and ch:get_Valid() and (d~=passengers.held or d.passengers[ch]) then wanted[ch]={group=group,slot=i} end
        end
    end
    for ch,a in pairs(d.passengers) do
        local valid=ch:get_Valid()
        if not wanted[ch] or not valid then
            local in_roster=false
            for _,member in ipairs((passengers.roster or {})[a.group] or {}) do if member==ch then in_roster=true end end
            local reason=not valid and "invalid_instance" or (in_roster and "seat_disabled" or "absent_from_engine_roster")
            if passengers.on_release then passengers.on_release(a,reason,valid) end
            if not valid then if event then event("passenger_unloaded",{group=a.group,slot=a.slot,instance=tostring(ch),protection=a.protection_counts,health=a.health_probe}) end end
            a.anchor_target=nil
            local ok,err=pcall(passengers.restore_one,a)
            if ok then d.passengers[ch]=nil;if event then event("passenger_released",{group=a.group,slot=a.slot}) end
            elseif not a.restore_error_logged then if event then event("passenger_restore_error",tostring(err)) end;a.restore_error_logged=true end
        end
    end
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
            if passengers.on_anchor then passengers.on_anchor(a) end
            anti_jitter:after_passenger(d,a)
            passengers.tick_pose(a)
        end)
        if not ok then
            passengers.last_error=slot.group.." "..slot.slot..": "..tostring(err)
            local key=slot.group..":"..slot.slot
            passengers.errors=passengers.errors or {}
            if now()>=(passengers.errors[key] or -math.huge) then
                passengers.errors[key]=now()+5;if event then event("passenger_control_error",{group=slot.group,slot=slot.slot,error=tostring(err)}) end
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
end
passengers.pre=function()
    local d=active or passengers.held
    if not passengers.visual_allowed() then return end
    for _,a in pairs(d.passengers or {}) do
        local ok,err=pcall(function()
            restore_bone(a)
            if a.anchor_target then passengers.orient(a,passengers.visual_seat(a.group,a.slot)) end
        end)
        if not ok then if event then event("passenger_bone_restore_error",tostring(err)) end end
    end
end
passengers.post=function()
    local d=active or passengers.held
    if not passengers.visual_allowed() then return end
    for _,a in pairs(d.passengers or {}) do
        if a.anchor_target then
            local ok,err=pcall(function()
                assert(owned_player(a,false),"Passenger changed")
                restore_bone(a)
                local actor=vector(a.transform:call("get_Position()"))
                local config=passengers.visual_seat(a.group,a.slot)
                local seat=rider_seat(a,config)
                local items={}
                for _,spec in ipairs({{joint=a.root_joint,key="root"},{joint=a.hip_joint,key="hip"}}) do
                    local joint=spec.joint
                    if joint and joint:get_Valid() then
                        local original=vector(joint:call("get_Position()"))
                        local anchor=spec.key=="hip" and seat or a.neutral_anchor
                        local target={x=anchor.x+original.x-actor.x,y=anchor.y+original.y-actor.y,z=anchor.z+original.z-actor.z}
                        if spec.key=="hip" then target=passengers.lock_pelvis(a,original,actor,target,config) end
                        items[#items+1]={joint=joint,original=original,written=target}
                    end
                end
                a.bones_applied=items
                for _,item in ipairs(items) do item.joint:call("set_Position(via.vec3)",Vector3f.new(item.written.x,item.written.y,item.written.z)) end
            end)
            if not ok and not a.pose_error_logged then if event then event("passenger_pose_error",tostring(err)) end;a.pose_error_logged=true end
        end
    end
end
end
