-- Griffin Journey Redux: low-speed hover translation, scoped to the retained spawn.
return function(ctx)
local _ENV=ctx
hover_motion={}
local hover_node="Ch253HoverWaitHoHomingHeight"
local function eligible(d)
    return alive and d and active==d and state.generation==generation and d.controls_active
        and not d.external_control and d.gear==1 and d.mode~="taking_off"
        and d.manual_hold~="landing" and not menu.gameplay_paused()
end
function hover_motion:brake(d)
    -- Suppress held input, but let existing translation/rotation decay normally.
    d.gear=1;d.hover_wait_center=true
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
    hover_yaw_state=nil
    if d then d.sprint_handoff=nil end
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
    if dt<=0 then return value,0 end
    if tau<=0 then return target,target*dt end
    local a=math.exp(-dt/tau)
    -- Integrate the exponential response analytically; input is held for this step.
    return target+(value-target)*a,target*dt+(value-target)*tau*(1-a)
end
-- Opposing input brakes to the exact zero crossing, then accelerates away.
-- Split the integral at that crossing to keep the result independent of frame rate.
local function velocity_step(value,target,dt,vertical)
    local acceleration=vertical and (target>=0 and settings.hover_up_accel_tau or settings.hover_down_accel_tau) or settings.hover_accel_tau
    local deceleration=vertical and (value>=0 and settings.hover_up_decel_tau or settings.hover_down_decel_tau) or settings.hover_decel_tau
    if value*target<0 then
        local braking=vertical and deceleration or settings.hover_reverse_tau
        local crossing=braking*math.log(1+math.abs(value/target))
        if dt<=crossing then return damp(value,target,dt,braking) end
        local _,distance=damp(value,target,crossing,braking)
        local speed,remainder=damp(0,target,dt-crossing,acceleration)
        return speed,distance+remainder
    end
    local tau=math.abs(target)<math.abs(value) and deceleration or acceleration
    return damp(value,target,dt,tau)
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
            yaw=math.atan(fx,fz),vx=0,vy=0,vz=0,turn=0,last_time=now()}
        m.coast=sprint_motion:consume(d,ch,tr)
        d.hover_motion=m
    end
    binding(d,m)
    local t=now()
    local dt=math.max(0,math.min(0.1,t-m.last_time));m.last_time=t
    local x,y=input.hover_x or input.x,input.y
    local climb=held(input.buttons,masks.hover_up)
    local descend=held(input.buttons,masks.hover_down)
    if d.hover_wait_center then
        if x==0 and y==0 and not climb and not descend then d.hover_wait_center=nil end
        x,y,climb,descend=0,0,false,false
    end
    -- The old right-stick raw sign was reversed in-game. Use the corrected
    -- left-stick slow-flight axis for yaw only; x adds no lateral velocity.
    local turn,angle=damp(m.turn,x*math.rad(settings.hover_turn_speed),dt,0.2)
    m.turn=turn;m.yaw=wrap_yaw(m.yaw+angle)
    local forward_x,forward_z=math.sin(m.yaw),math.cos(m.yaw)
    local longitudinal=y*(y>=0 and settings.hover_forward_speed or settings.hover_backward_speed)
    local target_x=forward_x*longitudinal
    local target_z=forward_z*longitudinal
    local dx,dy,dz
    m.vx,dx=velocity_step(m.vx,target_x,dt)
    local vertical=0
    if climb~=descend then vertical=climb and settings.hover_climb_speed or -settings.hover_descend_speed end
    m.vy,dy=velocity_step(m.vy,vertical,dt,true)
    m.vz,dz=velocity_step(m.vz,target_z,dt)
    if m.coast then
        local cx,cy,cz
        m.coast.x,cx=damp(m.coast.x,0,dt,settings.sprint_stop_tau)
        m.coast.y,cy=damp(m.coast.y,0,dt,settings.sprint_stop_tau)
        m.coast.z,cz=damp(m.coast.z,0,dt,settings.sprint_stop_tau)
        dx=dx+cx;dy=dy+cy;dz=dz+cz
        if math.abs(m.coast.x)+math.abs(m.coast.y)+math.abs(m.coast.z)<0.01 then m.coast=nil end
    end
    m.position.x=m.position.x+dx;m.position.y=m.position.y+dy;m.position.z=m.position.z+dz
    if x==0 and y==0 and not climb and not descend and math.abs(m.vx)+math.abs(m.vy)+math.abs(m.vz)<0.01 and math.abs(m.turn)<0.001 then
        m.vx=0;m.vy=0;m.vz=0;m.turn=0
    end
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
