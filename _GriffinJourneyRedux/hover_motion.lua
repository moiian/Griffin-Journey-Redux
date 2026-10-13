-- Griffin Journey Redux: low-speed hover translation, scoped to the retained spawn.
return function(ctx)
local _ENV=ctx
hover_motion={}
local hover_node="Ch253HoverWaitHoHomingHeight"
local function eligible(d)
    return alive and d and active==d and state.generation==generation and d.controls_active
        and not d.external_control and d.gear<=1 and d.mode~="taking_off"
        and d.manual_hold~="landing" and not menu.gameplay_paused()
end
function hover_motion:brake(d)
    local m=d.hover_motion
    if m then m.vx=0;m.vz=0;m.turn=0;m.last_time=now() end
    d.gear=0;d.hover_wait_center=true
end
local function binding(d,m)
    local ch=validate_spawn(d.spawn)
    assert(ch==m.character and d.spawn.result.go==m.go and ch:call("get_Transform()")==m.transform,
        "Hover Griffin binding changed")
    assert(ch:get_field("<PosRotContext>k__BackingField")==m.context
        and ch:get_field("<AdjustTerrain>k__BackingField")==m.terrain
        and m.terrain.MainCharacterController==m.controller,"Hover physics binding changed")
    assert(owned_player(d,true) and player_fsm(d.player)==d.fsm,"Hover player binding changed")
    return ch
end
function hover_motion:release(d)
    local m=d and d.hover_motion
    if not m then return end
    if m.dirty and m.character:get_Valid() and m.go:get_Valid() then
        binding(d,m)
        -- A native setter may raise after changing Transform. Repair the current
        -- location; never move back to the captured hover entry point.
        local p=m.transform:call("get_UniversalPosition()")
        local q=m.transform:call("get_Rotation()")
        m.context:call("setPosRot(via.Position, via.Quaternion)",p,q)
        m.controller:call("warp()")
    end
    d.hover_motion=nil
end
local function write_pose(d,m)
    binding(d,m) -- Never write retained components after an instance/controller change.
    local p=m.transform:call("get_UniversalPosition()")
    p.x=m.position.x;p.y=m.position.y;p.z=m.position.z
    local q=Quaternion.new(math.cos(m.yaw/2),0,math.sin(m.yaw/2),0)
    m.dirty=true
    m.transform:call("set_UniversalPosition(via.Position)",p)
    m.transform:call("set_Rotation(via.Quaternion)",q)
    m.context:call("setPosRot(via.Position, via.Quaternion)",p,q)
    m.controller:call("warp()")
    m.dirty=false
end
local function damp(value,target,dt,tau)
    local a=math.exp(-dt/tau)
    -- Integrate the exponential response analytically; input is held for this step.
    return target+(value-target)*a,target*dt+(value-target)*tau*(1-a)
end
function hover_motion:tick(d,ch,tr,fx,fz,flying,ground,action)
    if not eligible(d) or not flying or ground then self:release(d);return end
    local m=d.hover_motion
    if not m then
        -- Do not pin a takeoff, landing or outgoing sprint while hover is still queued.
        if d.intent or d.pending or action~=hover_node then return end
        local terrain=ch:get_field("<AdjustTerrain>k__BackingField")
        local context=ch:get_field("<PosRotContext>k__BackingField")
        local controller=terrain and terrain.MainCharacterController
        assert(context and terrain and controller,"Hover physics interfaces unavailable")
        assert(type(Quaternion.new)=="function","Quaternion constructor unavailable")
        m={character=ch,go=d.spawn.result.go,transform=tr,context=context,terrain=terrain,
            controller=controller,position=vector(tr:call("get_UniversalPosition()")),
            yaw=math.atan(fx,fz),vx=0,vz=0,turn=0,last_time=now()}
        d.hover_motion=m
    end
    binding(d,m)
    local t=now()
    local dt=math.max(0,math.min(0.1,t-m.last_time));m.last_time=t
    local x,y=input.x,input.y
    local rx=input.rx or 0
    assert(not input.right_error and finite(rx),"Hover right-stick unavailable")
    rx=math.abs(rx)<=0.2 and 0 or (rx>0 and 1 or -1)*math.min(1,(math.abs(rx)-0.2)/0.8)
    if d.hover_wait_center then
        if x==0 and y==0 and rx==0 then d.hover_wait_center=nil end
        x,y,rx=0,0,0
    end
    local length=math.sqrt(x*x+y*y)
    if length>1 then x,y=x/length,y/length end
    local turn,angle=damp(m.turn,rx*math.rad(settings.hover_turn_speed),dt,0.2)
    m.turn=turn;m.yaw=wrap_yaw(m.yaw+angle)
    local forward_x,forward_z=math.sin(m.yaw),math.cos(m.yaw)
    -- HID x is left-positive in the existing navigation mapping.
    local target_x=(forward_x*y-forward_z*x)*settings.hover_speed
    local target_z=(forward_z*y+forward_x*x)*settings.hover_speed
    local dx,dz
    m.vx,dx=damp(m.vx,target_x,dt,0.2)
    m.vz,dz=damp(m.vz,target_z,dt,0.2)
    m.position.x=m.position.x+dx;m.position.z=m.position.z+dz
    if x==0 and y==0 and rx==0 and math.abs(m.vx)+math.abs(m.vz)<0.01 and math.abs(m.turn)<0.001 then
        m.vx=0;m.vz=0;m.turn=0;d.gear=0
    else d.gear=1 end
    write_pose(d,m)
    d.heading={x=forward_x,z=forward_z};d.body_pitch=0
end
function hover_motion:after_behavior()
    local d=active
    if not eligible(d) or not d.hover_motion then return end
    local ok,err=pcall(write_pose,d,d.hover_motion)
    if not ok then stop_driver("慢速悬浮同步失败");failed("慢速悬浮同步失败",err) end
end
end
