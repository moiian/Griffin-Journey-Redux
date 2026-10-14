-- Griffin Journey Redux: player
return function(ctx)
local _ENV=ctx
passengers.reset_fall=function(d)
    local pos=d.transform:call("get_UniversalPosition()")
    d.fall:call("resetBaseHeight(via.Position)",pos)
    d.fall:call("resetFallHeight()")
    d.fall_reset_pending=false
end
function sync_player(d,reset_fall)
    local pos = d.transform:call("get_UniversalPosition()")
    d.context:call("setPos(via.Position)", pos)
    -- Normal fall reset is attach/preset/release only.
    if reset_fall or d.fall_reset_pending then passengers.reset_fall(d) end
    d.controller:call("warp()")
end
-- Voluntary exit captures all seat points before any actor/bone restoration.
function capture_exit_seats(d)
    local function capture(a,config)
        if a.exit_seat or not a.moved or not a.player:get_Valid() then return end
        local ok,target=pcall(function()
            assert(owned_player(a,not a.group),"Exit seat actor changed")
            if a.group then passengers.prepare_rig(a,d) end
            return rider_seat(a,config)
        end)
        if ok then a.exit_seat=vector(target)
        else if event then event("exit_seat_capture_failed",{group=a.group or "player",slot=a.slot,error=tostring(target)}) end end
    end
    capture(d,passengers.player_config())
    for _,a in pairs(d.passengers or {}) do capture(a,passengers.visual_seat(a.group,a.slot)) end
end
function apply_exit_seat(a)
    if not a.exit_seat or a.exit_seat_applied then return end
    assert(owned_player(a,not a.group),"Exit seat actor changed")
    local p=a.exit_seat
    a.transform:call("set_Position(via.vec3)",Vector3f.new(p.x,p.y,p.z))
    -- Read UniversalPosition after the local Transform write (floating origin).
    sync_player(a,true)
    a.exit_seat_applied=true
    if event then event("exit_seat_applied",{group=a.group or "player",slot=a.slot,position=p}) end
    return true
end
-- All layers follow a neutral Griffin anchor; only the selected layer gets stick offset.
-- Engine coupling is observed through readback, not assumed away.
anchor_mode="rider"

function close_position(a,b)
    return math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)<0.001
end
function restore_bone(d)
    local items=d.bones_applied
    if not items then return end
    if not owned_player(d,false) then d.bones_applied=nil;return end
    -- Decide ownership before any parent write changes a child's world position.
    local matches={}
    for i,a in ipairs(items) do
        matches[i]=a.joint:get_Valid() and close_position(vector(a.joint:call("get_Position()")),a.written)
    end
    -- Restore parent first, then child, using the pose captured before either write.
    for i,a in ipairs(items) do
        if matches[i] then a.joint:call("set_Position(via.vec3)",Vector3f.new(a.original.x,a.original.y,a.original.z)) end
    end
    d.bones_applied=nil
end

function discover_joints(d)
    if d.joints_searched then return end
    d.joints_searched=true
    d.display_roots={}
    local joints=d.transform:call("get_Joints()")
    assert(joints,"Player joints unavailable")
    for _,joint in pairs(joints:get_elements() or {}) do
        if joint and joint:get_Valid() then
            local name=tostring(joint:call("get_Name()"))
            if name:lower()=="hip" then d.hip_joint=joint;d.hip_name=name end
            if name:lower()=="root" then d.root_joint=joint;d.root_name=name end
            local parent=joint:call("get_Parent()")
            if not parent or not parent:get_Valid() then
                d.display_roots[#d.display_roots+1]=joint
                if not d.root_joint then d.root_joint=joint;d.root_name=name end
            end
        end
    end
    if event then event("anchor_joint_inventory",{root=d.root_name,hip=d.hip_name,display_roots=#d.display_roots}) end
end
function prepare_rider(d)
    discover_joints(d)
    assert(d.hip_joint and d.hip_joint:get_Valid(),"玩家Hip骨骼不可用，未开启固定")
    local ch=d.spawn.result.chara
    local tr=ch:call("get_Transform()")
    assert(tr,"Griffin Transform unavailable")
    d.rider_griffin_transform=tr
    d.rider_head=nil;d.rider_head_name=nil;d.rider_necks={}
    local joints=tr:call("get_Joints()")
    local candidates={}
    if joints then
        for _,joint in pairs(joints:get_elements() or {}) do
            if joint and joint:get_Valid() then
                local name=tostring(joint:call("get_Name()"))
                local lower=name:lower()
                if lower:find("neck",1,true) and not lower:find("end",1,true)
                    and not lower:find("target",1,true) and not lower:find("eff",1,true) then
                    d.rider_necks[#d.rider_necks+1]={name=name,joint=joint}
                end
                if lower:find("head",1,true) then
                    candidates[#candidates+1]=name
                    if lower=="head" then d.rider_head=joint;d.rider_head_name=name
                    elseif not d.rider_head and not lower:find("end",1,true) and not lower:find("target",1,true)
                        and not lower:find("eff",1,true) then d.rider_head=joint;d.rider_head_name=name end
                end
            end
        end
    end
    table.sort(d.rider_necks,function(a,b) return a.name<b.name end)
    local neck_names={};for _,entry in ipairs(d.rider_necks) do neck_names[#neck_names+1]=entry.name end
    if event then event("rider_head_binding",{head=d.rider_head_name,candidates=candidates,neck_candidates=neck_names,
        fallback=not d.rider_head and "Griffin root + forward 3m / up 4m" or nil}) end
end
function prepare_anchor_mode(d,key)
    assert(key=="rider" or key=="full","Unsupported display mode")
    if key=="rider" then prepare_rider(d) end
end
function write_anchor(d,target,neutral)
    restore_bone(d)
    d.anchor_target=target;d.neutral_anchor=neutral;d.moved=true
    d.transform:call("set_Position(via.vec3)",Vector3f.new(target.x,target.y,target.z))
    passengers.orient(d,passengers.player_config())
    sync_player(d)
    if passengers.on_anchor then passengers.on_anchor(d) end
    anti_jitter:after_anchor(d)
    d.anchor_plan={transform=target,context=target,controller=target}
end

end
