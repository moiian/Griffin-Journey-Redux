-- Experimental preflight guard. Own native queries; accepted poses only.
return function(ctx)
local _ENV=ctx
hover_collision={enabled=false,radius=1.5,height=2.5,span=2,margin=0.15,
    casts=0,blocks=0,contacts=0,cost=0,status="1档防穿模：关闭"}
local guard=hover_collision
local adapter=nil
local function plain(v) return {x=v.x,y=v.y,z=v.z} end
local function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
local function init()
    if adapter then return adapter end
    local system=assert(sdk.find_type_definition("via.physics.System"),"physics.System unavailable")
    local method=assert(system:get_method("castSphere(via.Sphere, via.vec3, via.vec3, System.UInt32, via.physics.FilterInfo, via.physics.ShapeCastResult)"),"castSphere unavailable")
    local sphere_type=assert(sdk.find_type_definition("via.Sphere"),"Sphere unavailable")
    local query=assert(sdk.create_instance("via.physics.CastRayQuery")):add_ref()
    local filter=assert(query:call("get_FilterInfo()"))
    filter:call("set_Group(System.UInt32)",0)
    -- Matches installed NickCore's get_no_enemy_ray_cast_position world query.
    filter:call("set_Layer(System.UInt32)",2)
    filter:call("set_MaskBits(System.UInt32)",0)
    local result=assert(sdk.create_instance("via.physics.ShapeCastResult")):add_ref()
    local sphere=ValueType.new(sphere_type)
    sphere:set_Center(Vector3f.new(0,0,0))
    adapter={query=query,filter=filter,result=result,sphere=sphere,method=method,
        options=1}
    return adapter
end
local function cast(start,finish,radius)
    local a=init()
    a.sphere:set_Radius(radius)
    a.result:call("clear()")
    guard.casts=guard.casts+1
    a.method:call(nil,a.sphere,Vector3f.new(start.x,start.y,start.z),
        Vector3f.new(finish.x,finish.y,finish.z),a.options,a.filter,a.result)
    local count=a.result:call("get_NumContactPoints()")
    assert(finite(count) and count>=0 and count<=64,"Too many or invalid collision contacts")
    guard.contacts=guard.contacts+count
    -- Deliberately avoid dereferencing native contact/collider pointers.
    return count>0
end
local function freeze(m)
    local safe=m.collision_safe
    if safe then m.position=plain(safe.position);m.yaw=safe.yaw end
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil
end
function guard:set_enabled(value)
    self.enabled=value==true
    self.epoch=(self.epoch or 0)+1
    self.retry_at=nil
    self.status=self.enabled and "1档防穿模：等待移动" or "1档防穿模：关闭"
end
function guard:prepare(d,m)
    if not self.enabled then return true end
    if not alive or state.generation~=generation or active~=d or d.gear~=1 or not d.controls_active
        or d.external_control or d.mode=="taking_off" or d.manual_hold=="landing"
        or d.native_action~="Ch253HoverWaitHoHomingHeight" or menu.gameplay_paused() then return false end
    if m.collision_epoch~=self.epoch or not m.collision_safe then
        local p=vector(m.transform:call("get_UniversalPosition()"))
        local q=m.transform:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"Collision rotation unavailable")
        local norm=math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
        assert(norm>0.000001,"Invalid collision rotation")
        local x,y,z,w=q.x/norm,q.y/norm,q.z/norm,q.w/norm
        local yaw=math.atan(2*(x*z+w*y),1-2*(x*x+y*y))
        local resetting=m.collision_safe~=nil
        m.collision_safe={position=plain(p),yaw=yaw};m.collision_epoch=self.epoch
        m.collision_drift=nil
        m.position=plain(p);m.yaw=yaw
        if resetting then freeze(m) end -- A fresh hover keeps the intentional LT coast.
    end
    return true
end
function guard:accepted(m)
    if self.enabled then m.collision_safe={position=plain(m.position),yaw=m.yaw} end
end
function guard:constrain(d,m,current)
    if not self.enabled then return true end
    if not self:prepare(d,m) then return false end
    local started=os.clock()
    local allowed=false
    local ok,err=pcall(function()
        assert(d.spawn and d.spawn.result and d.spawn.result.go==m.go and d.spawn.result.chara==m.character,
            "Collision instance changed")
        local safe=m.collision_safe
        local drift={x=current.x-safe.position.x,y=current.y-safe.position.y,z=current.z-safe.position.z}
        vector(drift)
        -- Never silently adopt an unapproved native position after a rejection.
        if m.collision_drift or dot(drift,drift)>0.05*0.05 then
            m.collision_drift=true
            self.status="1档防穿模：原生位置偏离，已暂停位移；关闭再开启可重置"
            freeze(m);return
        end
        local delta={x=m.position.x-safe.position.x,y=m.position.y-safe.position.y,z=m.position.z-safe.position.z}
        vector(delta)
        local angle=(m.yaw-safe.yaw+math.pi)%(2*math.pi)-math.pi
        if dot(delta,delta)==0 and math.abs(angle)<0.000000001 then return end
        if self.retry_at and now()<self.retry_at then freeze(m);return end
        local local_p=m.transform:call("get_Position()")
        vector(local_p)
        local local_safe={x=local_p.x-drift.x,y=local_p.y-drift.y,z=local_p.z-drift.z}
        local oldx,oldz,newx,newz=math.sin(safe.yaw),math.cos(safe.yaw),math.sin(m.yaw),math.cos(m.yaw)
        for _,offset in ipairs({0,self.span,-self.span}) do
            local start={x=local_safe.x+oldx*offset,y=local_safe.y+self.height,z=local_safe.z+oldz*offset}
            local finish={x=local_safe.x+delta.x+newx*offset,y=local_safe.y+delta.y+self.height,z=local_safe.z+delta.z+newz*offset}
            local move={x=finish.x-start.x,y=finish.y-start.y,z=finish.z-start.z}
            if dot(move,move)>0.000000000000000001 then
                local radius=self.radius+self.margin+math.abs(offset)*(1-math.cos(math.abs(angle)/2))
                -- Sweep both ways to avoid relying on a mesh's facing direction.
                if cast(start,finish,radius) or cast(finish,start,radius) then
                    freeze(m);self.blocks=self.blocks+1
                    self.status="1档防穿模：环境接触，已拒绝整步位移"
                    return
                end
            end
        end
        allowed=true;self.retry_at=nil;self.status="1档防穿模：路径畅通"
    end)
    self.cost=self.cost+math.max(0,os.clock()-started)
    if not ok then
        freeze(m);self.retry_at=now()+0.5
        self.status="1档防穿模检测失败，已暂停代码移动："..tostring(err)
    end
    return ok and allowed
end
function guard:draw()
    if not imgui.tree_node("1档防穿模测试") then return end
    local changed,value=menu.toggle("启用1档防穿模（实验）",self.enabled)
    if changed then self:set_enabled(value) end
    for _,spec in ipairs({{"radius","检测球半径（米）",0.25,6},{"height","检测球中心高度（米）",0,8},
        {"span","前后检测球偏移（米）",0,6},{"margin","额外安全余量（米）",0.02,1}}) do
        local edit,result=imgui.slider_float(spec[2],self[spec[1]],spec[3],spec[4])
        if edit and finite(result) then self[spec[1]]=math.max(spec[3],math.min(spec[4],result));self.retry_at=nil end
    end
    imgui.text(self.status)
    imgui.text(string.format("球体查询：%d；拦截：%d；接触点：%d",self.casts,self.blocks,self.contacts))
    if self.casts>0 then imgui.text(string.format("粗略Lua计时／查询：%.3f 毫秒",self.cost*1000/self.casts)) end
    imgui.text("仅1档；2档不查询。会话测试参数，重载后关闭。")
    imgui.tree_pop()
end
end
