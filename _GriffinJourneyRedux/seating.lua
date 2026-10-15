-- Griffin Journey Redux: seating
return function(ctx)
local _ENV=ctx
passengers.player_config=function()
    return {anchor=settings.rider_anchor,neck_joint=settings.rider_neck_joint,height=settings.rider_height,
        forward=settings.rider_forward,side=settings.rider_side,anim=settings.rider_anim,randomIdle=settings.rider_randomIdle==true,pelvisCompensation=settings.rider_pelvisCompensation==true,lookX=settings.rider_lookX,lookZ=settings.rider_lookZ,
        tilt_follow=settings.rider_tilt_follow,pitch_offset=settings.rider_pitch_offset}
end
passengers.basis=function(d,config,position_only)
    local fx,fz=d.heading.x,d.heading.z
    local strength=finite(config.tilt_follow) and math.max(0,math.min(1,config.tilt_follow)) or 1
    local trim=finite(config.pitch_offset) and math.max(-45,math.min(45,config.pitch_offset)) or 0
    if position_only then trim=0 end -- pose trim changes facing, never the calibrated seat position
    local pitch=math.max(-89,math.min(89,(d.body_pitch or 0)*strength+trim))*math.pi/180
    local cp,sp=math.cos(pitch),math.sin(pitch)
    return {x=fz,y=0,z=-fx},{x=-fx*sp,y=cp,z=-fz*sp},{x=fx*cp,y=sp,z=fz*cp},pitch*180/math.pi
end
passengers.same_rotation=function(a,b)
    if not a or not b then return false end
    local dot,na,nb=0,0,0
    for _,key in ipairs({"x","y","z","w"}) do
        if not finite(a[key]) or not finite(b[key]) then return false end
        dot=dot+a[key]*b[key];na=na+a[key]^2;nb=nb+b[key]^2
    end
    return na>0.00001 and nb>0.00001 and math.abs(dot)/math.sqrt(na*nb)>0.999999
end
passengers.restore_rotation=function(d)
    local s=d.seat_rotation
    if not s then return end
    if owned_player(d,false) and passengers.same_rotation(d.transform:call("get_Rotation()"),s.last) then
        d.transform:call("set_Rotation(via.Quaternion)",s.original)
    end
    d.seat_rotation=nil
end
passengers.orient=function(d,config)
    if d.orientation_failed then return end
    local ok,err=pcall(function()
        local right,up,forward,pitch=passengers.basis(d,config)
        local x=finite(config.lookX) and math.max(-1,math.min(1,config.lookX)) or 0
        local z=finite(config.lookZ) and math.max(-1,math.min(1,config.lookZ)) or 1
        local length=math.sqrt(x*x+z*z)
        if length<0.0001 then x,z,length=0,1,1 end
        local direction={x=(right.x*x+forward.x*z)/length,y=(right.y*x+forward.y*z)/length,z=(right.z*x+forward.z*z)/length}
        local pos=vector(d.transform:call("get_Position()"))
        if not d.seat_rotation then
            local original=d.transform:call("get_Rotation()")
            assert(passengers.same_rotation(original,original),"Seat original rotation invalid")
            d.seat_rotation={original=original,last=original}
        end
        local applied,apply_err=pcall(function()
            d.transform:call("lookAt(via.vec3, via.vec3)",Vector3f.new(pos.x+direction.x,pos.y+direction.y,pos.z+direction.z),Vector3f.new(up.x,up.y,up.z))
        end)
        -- Read back even after a Lua error raised after the native setter wrote.
        d.seat_rotation.last=d.transform:call("get_Rotation()")
        assert(applied,apply_err)
    end)
    if not ok then
        d.orientation_failed=true
        if event then event("seat_orientation_error",{group=d.group or "player",slot=d.slot,error=tostring(err)}) end
        pcall(passengers.restore_rotation,d)
    end
end

-- Seat calculation only. Bone writes use the original Hip experiment callback below.
function rider_seat(d,config)
    config=config or passengers.player_config()
    local ch=validate_spawn(d.spawn,true)
    assert(ch:call("get_Transform()")==d.rider_griffin_transform,"Griffin anchor changed")
    local base
    if config.anchor=="root" then
        base=vector(d.rider_griffin_transform:call("get_Position()"))
    elseif d.rider_head then
        assert(d.rider_head:get_Valid(),"Griffin Head unavailable")
        base=vector(d.rider_head:call("get_Position()"))
    else
        base=vector(d.rider_griffin_transform:call("get_Position()"))
        base={x=base.x+d.heading.x*3,y=base.y+4,z=base.z+d.heading.z*3}
    end
    local selected_name=config.anchor=="root" and "Transform root" or d.rider_head_name
    if config.anchor=="neck" then
        local neck=d.rider_necks and d.rider_necks[1]
        for _,candidate in ipairs(d.rider_necks or {}) do
            if candidate.name==config.neck_joint then neck=candidate;break end
        end
        if neck and neck.joint:get_Valid() then
            base=vector(neck.joint:call("get_Position()"));selected_name=neck.name
            d.rider_neck_missing=nil
        elseif not d.rider_neck_missing then
            d.rider_neck_missing=true
            status="未找到可用颈部骨骼，座位暂用头部；导航与驾驶继续。"
            if event then event("rider_neck_unavailable",config.neck_joint) end
        end
    end
    d.rider_seat_joint_name=selected_name
    local right,up,forward=passengers.basis(d,config,true)
    local seat={x=base.x+forward.x*config.forward+right.x*config.side+up.x*config.height,
        y=base.y+forward.y*config.forward+right.y*config.side+up.y*config.height,
        z=base.z+forward.z*config.forward+right.z*config.side+up.z*config.height}
    return seat,base
end
-- Passenger ownership uses live character instances, never character IDs for control.
passengers.refresh=function(force)
    local c=core()
    if not alive or not c or menu.gameplay_paused() or not c.properties.player then return end
    local needed=active or state.recovery
    if not needed then
        for _,r in ipairs(state.spawns) do
            if r.friend and not r.deleted and not r.delete_requested and r.owner==c.properties.player then needed=true;break end
        end
    end
    if not needed then
        passengers.roster=nil;passengers.npcs=nil;passengers.next_roster=nil;passengers.next_npc=nil
        return
    end
    if not force and now()<(passengers.next_roster or -math.huge) then return end
    passengers.next_roster=now()+0.25
    local ok,party=pcall(c.object.get_party)
    if not ok or type(party)~="table" or party[1]~=c.properties.player then return end
    local seen,pawns={[c.properties.player]=true},{}
    local friends={c.properties.player}
    for _,ch in ipairs(party) do
        if ch and ch:get_Valid() and not seen[ch] then
            seen[ch]=true;pawns[#pawns+1]=ch;friends[#friends+1]=ch
        end
    end
    if force or now()>=(passengers.next_npc or -math.huge) then
        passengers.next_npc=now()+1
        local scan_ok,found=pcall(function()
            local nm=assert(sdk.get_managed_singleton("app.NPCManager"),"NPCManager unavailable")
            local td=sdk.find_type_definition("app.NPCUtil")
            local method=assert(td and td:get_method("isAccompanyPLParty(app.Character)"),"NPC membership unavailable")
            local list,unique={},{}
            local prior={};for _,ch in ipairs(passengers.npcs or {}) do prior[ch]=true end
            for _,holder in pairs(assert(nm.NPCHolderDic,"NPC roster unavailable")) do
                local read_ok,ch=pcall(function() return holder and nm:getCharacter(holder.CharaID) end)
                if read_ok and ch and ch:get_Valid() and not seen[ch] and not unique[ch] then
                    local membership_ok,following=pcall(function() return method:call(nil,ch) end)
                    if membership_ok and following==true or (not membership_ok or type(following)~="boolean") and prior[ch] then
                        unique[ch]=true;list[#list+1]=ch
                    end
                end
            end
            table.sort(list,function(a,b) return a:get_address()<b:get_address() end)
            return list
        end)
        if scan_ok then
            passengers.npcs=found;passengers.npc_status="同行NPC识别正常"
        else
            passengers.npc_status="同行NPC扫描暂不可用，保留上次有效名单"
            if not passengers.npc_error_logged then if event then event("passenger_npc_scan_error",tostring(found)) end;passengers.npc_error_logged=true end
        end
    end
    local companions={}
    for _,ch in ipairs(passengers.npcs or {}) do
        if ch:get_Valid() and not seen[ch] then
            seen[ch]=true;companions[#companions+1]=ch;friends[#friends+1]=ch
        end
    end
    passengers.roster={pawns=pawns,companions=companions}
    for _,r in ipairs(state.spawns) do
        if r.friend and r.owner==c.properties.player then
            local changed=#(r.party or {})~=#friends
            for i,ch in ipairs(friends) do if (r.party or {})[i]~=ch then changed=true end end
            r.party=friends
            if changed then if event then event("friend_roster_refreshed",{pawns=#pawns,companions=#companions}) end end
        end
    end
end
passengers.seat=function(group,index,preset,physical_override)
    local key=preset and group or (group=="pawns" and "pawn_seats" or "companion_seats")
    local store=preset or settings
    if type(store[key])~="table" then store[key]={} end
    local seat=store[key][index]
    local physical=physical_override or settings.seat_presets and (preset==settings.seat_presets[1] or not preset and settings.seat_index==1)
    if type(seat)~="table" then
        seat={};store[key][index]=seat
        if physical then
            -- New roster slots inherit the former safe point once; each owns its own table.
            for _,field in ipairs({"anchor","neck_joint","height","forward","side","tilt_follow","pitch_offset"}) do seat[field]=settings.seat_presets[1].player[field] end
            seat.enabled=true;seat.anim=""
        end
    end
    if seat.enabled==nil then seat.enabled=true end
    if type(seat.anim)~="string" then seat.anim="" end
    seat.randomIdle=seat.randomIdle==true;seat.pelvisCompensation=seat.pelvisCompensation==true
    for _,spec in ipairs({{"lookX",0,-1,1},{"lookZ",1,-1,1},{"tilt_follow",physical and 0 or 1,0,1},{"pitch_offset",0,-45,45}}) do
        local key,default,lo,hi=spec[1],spec[2],spec[3],spec[4]
        seat[key]=finite(seat[key]) and math.max(lo,math.min(hi,seat[key])) or default
    end
    seat.anchor=seat.anchor=="root" and "root" or (seat.anchor=="head" and "head" or "neck")
    if type(seat.neck_joint)~="string" then seat.neck_joint="" end
    if not finite(seat.height) then seat.height=0.5 end
    if not finite(seat.forward) then seat.forward=-index*1.2-(group=="companions" and 3.6 or 0) end
    if not finite(seat.side) then seat.side=index%2==1 and -0.7 or 0.7 end
    if not physical and seat.anchor~="root" then
        seat.height=math.max(-5,math.min(15,seat.height))
        seat.forward=math.max(-15,math.min(15,seat.forward))
        seat.side=math.max(-10,math.min(10,seat.side))
    end
    return seat
end
-- Same receiver-scoped damage policy as OJR; no global invincibility fields.
passengers.controlled=function(ch,include_player)
    local d,c=active or passengers.held,core()
    if not alive or not d or not c or c.properties.player~=d.player then return end
    local a=include_player and active==d and ch==d.player and d or (d.passengers or {})[ch]
    if d.held_releasing then return end
    if a and a.moved and a.anchor_target and not a.recovery_pending and ch:get_Valid() then return a end
end
end
