-- Read-only native displacement sampling; momentum writes begin only in bound hover.
return function(ctx)
local _ENV=ctx
sprint_motion={}
local function length(v) return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z) end
local function scoped(d)
    return alive and d and active==d and state.generation==generation
        and d.controls_active and not d.external_control
end
function sprint_motion:clear(d)
    if d then d.sprint_sample=nil;d.sprint_handoff=nil end
end
function sprint_motion:pause(d)
    if d then
        d.sprint_sample=nil
        if d.sprint_handoff then d.sprint_handoff.time=now() end
    end
end
function sprint_motion:sample(d,ch,tr,flying,ground,action)
    if not scoped(d) or menu.gameplay_paused() then self:pause(d);return end
    if not flying or ground then self:clear(d);return end
    if d.gear~=2 and not d.sprint_handoff then d.sprint_sample=nil;return end
    -- The request may precede native action entry; never measure hovering as sprint.
    if type(action)~="string" or action:sub(1,15)~="Ch253WrapAround" then
        if d.gear==2 then d.sprint_sample=nil end
        return
    end
    local ok,err=pcall(function()
        local t=now();local p=vector(tr:call("get_UniversalPosition()"))
        local s=d.sprint_sample
        if not s or s.character~=ch or s.transform~=tr then
            d.sprint_sample={character=ch,transform=tr,position=p,time=t,duration=0};return
        end
        local dt=t-s.time
        if dt<=0 then return end
        local v={x=(p.x-s.position.x)/dt,y=(p.y-s.position.y)/dt,z=(p.z-s.position.z)/dt}
        s.position=p;s.time=t
        -- Gaps/teleports cannot become a launch impulse; no native velocity is written.
        if dt>0.25 or not finite(length(v)) or length(v)>200 then
            s.velocity=nil;s.duration=0;d.sprint_speed=nil;return
        end
        local a=math.exp(-dt/0.08)
        if s.velocity then
            for _,key in ipairs({"x","y","z"}) do v[key]=v[key]+(s.velocity[key]-v[key])*a end
        end
        s.velocity=v;s.duration=s.duration+dt
        d.sprint_speed={total=length(v),horizontal=math.sqrt(v.x*v.x+v.z*v.z),vertical=v.y,time=t,ready=s.duration>=0.08}
        if d.sprint_handoff and s.duration>=0.08 then
            d.sprint_handoff={velocity=vector(v),character=ch,transform=tr,time=t}
        end
    end)
    if not ok then self:clear(d);d.sprint_speed=nil;d.sprint_status="速度读取暂不可用："..tostring(err) end
end
function sprint_motion:capture(d)
    local s=d.sprint_sample
    if not s or not s.velocity or s.duration<0.08 or now()-s.time>0.15 then
        d.sprint_status="LT惯性：无新鲜有效速度样本";return nil
    end
    d.sprint_status="LT惯性：等待原生悬停接管"
    return {velocity=vector(s.velocity),character=s.character,transform=s.transform,time=s.time}
end
function sprint_motion:consume(d,ch,tr)
    local s=d.sprint_handoff;d.sprint_handoff=nil;d.sprint_sample=nil
    if not s then return nil end
    if not scoped(d) or s.character~=ch or s.transform~=tr or now()-s.time>0.5 then
        d.sprint_status="LT惯性：过期或实例变化，已丢弃";return nil
    end
    d.sprint_handoff_speed=length(s.velocity);d.sprint_status="LT惯性：已继承实测世界速度"
    return vector(s.velocity)
end
end
