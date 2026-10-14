-- Experimental swept volume guard. Own native query objects; no hooks/shared edits.
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
    local contact=assert(sdk.find_type_definition("via.physics.ContactPoint"),"ContactPoint unavailable")
    local sphere_type=assert(sdk.find_type_definition("via.Sphere"),"Sphere unavailable")
    local query=assert(sdk.create_instance("via.physics.CastRayQuery")):add_ref()
    query:call("clearOptions()")
    for _,name in ipairs({"enableAllHits()","enableNearSort()","enableInsideHits()",
        "enableFrontFacingTriangleHits()","enableBackFacingTriangleHits()"}) do query:call(name) end
    local filter=assert(query:call("get_FilterInfo()"))
    filter:call("set_Group(System.UInt32)",0)
    -- Matches installed NickCore's get_no_enemy_ray_cast_position world query.
    filter:call("set_Layer(System.UInt32)",2)
    filter:call("set_MaskBits(System.UInt32)",0)
    local result=assert(sdk.create_instance("via.physics.ShapeCastResult")):add_ref()
    local sphere=ValueType.new(sphere_type)
    sphere:set_Center(Vector3f.new(0,0,0))
    adapter={query=query,filter=filter,result=result,sphere=sphere,method=method,
        contact=contact,options=query:call("get_Options()")}
    return adapter
end
local function cast(start,finish,radius,d,m)
    local a=init()
    a.sphere:set_Radius(radius)
    a.result:call("clear()")
    guard.casts=guard.casts+1
    a.method:call(nil,a.sphere,Vector3f.new(start.x,start.y,start.z),
        Vector3f.new(finish.x,finish.y,finish.z),a.options,a.filter,a.result)
    local count=a.result:call("get_NumContactPoints()")
    assert(finite(count) and count>=0 and count<=64,"Too many or invalid collision contacts")
    local step={x=finish.x-start.x,y=finish.y-start.y,z=finish.z-start.z}
    local distance=math.sqrt(dot(step,step))
    local dir={x=step.x/distance,y=step.y/distance,z=step.z/distance}
    for index=0,count-1 do
        guard.contacts=guard.contacts+1
        local collider=a.result:call("getContactCollidable(System.UInt32)",index)
        local object=collider and collider:call("get_GameObject()")
        -- Characters are excluded by the environment layer; exact self/player
        -- checks are additional exclusions, not broad names/Character-ID rules.
        if not object or (object~=m.go and object~=d.player_go) then
                local point=a.result:call("getContactPoint(System.UInt32)",index)
                assert(point,"Missing collision contact")
                local normal=sdk.get_native_field(point,a.contact,"Normal")
                assert(normal and finite(normal.x) and finite(normal.y) and finite(normal.z),"Invalid collision normal")
                local size=math.sqrt(dot(normal,normal))
                assert(size>0.000001,"Zero collision normal")
                local approach=dot(dir,normal)/size
                -- Separating/tangent movement may leave an initially overlapping
                -- volume; approaching contacts block the entire proposed step.
                if approach < -0.0001 then
                    local name="环境碰撞体"
                    if object then
                        local ok,value=pcall(function() return object:call("get_Name()") end)
                        if ok and type(value)=="string" then name=value end
                    end
                    return true,name
                end
        end
    end
    return false
end
local function freeze(m,p,yaw)
    m.position=plain(p);m.yaw=yaw
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil
end
function guard:set_enabled(value)
    self.enabled=value==true
    self.retry_at=nil
    self.status=self.enabled and "1档防穿模：等待移动" or "1档防穿模：关闭"
end
function guard:constrain(d,m,current)
    if not self.enabled or not alive or state.generation~=generation or active~=d or d.gear~=1 or not d.controls_active
        or d.external_control or d.mode=="taking_off" or d.manual_hold=="landing"
        or d.native_action~="Ch253HoverWaitHoHomingHeight" or menu.gameplay_paused() then return end
    local started=os.clock()
    local yaw=m.safe_yaw or m.yaw
    local ok,err=pcall(function()
        assert(d.spawn and d.spawn.result and d.spawn.result.go==m.go and d.spawn.result.chara==m.character,
            "Collision instance changed")
        local delta={x=m.position.x-current.x,y=m.position.y-current.y,z=m.position.z-current.z}
        vector(delta)
        if dot(delta,delta)==0 and math.abs(m.turn)<0.0001
            and (not m.safe_yaw or math.abs(m.yaw-m.safe_yaw)<0.0001) then return end
        local q=m.transform:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"Collision rotation unavailable")
        local norm=math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
        assert(norm>0.000001,"Invalid collision rotation")
        local x,y,z,w=q.x/norm,q.y/norm,q.z/norm,q.w/norm
        yaw=math.atan(2*(x*z+w*y),1-2*(x*x+y*y))
        if self.retry_at and now()<self.retry_at then freeze(m,current,yaw);return end
        local angle=(m.yaw-yaw+math.pi)%(2*math.pi)-math.pi
        if dot(delta,delta)==0 and math.abs(angle)<0.0001 then return end
        local local_p=m.transform:call("get_Position()")
        vector(local_p)
        local oldx,oldz,newx,newz=math.sin(yaw),math.cos(yaw),math.sin(m.yaw),math.cos(m.yaw)
        for _,offset in ipairs({0,self.span,-self.span}) do
            local start={x=local_p.x+oldx*offset,y=local_p.y+self.height,z=local_p.z+oldz*offset}
            local finish={x=local_p.x+delta.x+newx*offset,y=local_p.y+delta.y+self.height,z=local_p.z+delta.z+newz*offset}
            local move={x=finish.x-start.x,y=finish.y-start.y,z=finish.z-start.z}
            local length=math.sqrt(dot(move,move))
            if length>0.000000001 then
                -- Chord sweep plus angular sagitta conservatively covers rotation
                -- between the endpoints of a front/rear sphere's curved path.
                local radius=self.radius+math.abs(offset)*(1-math.cos(math.abs(angle)/2))
                local blocked,name=cast(start,finish,radius+self.margin,d,m)
                if blocked then
                    freeze(m,current,yaw);self.blocks=self.blocks+1
                    self.status="1档防穿模：已拦截 → "..name
                    return
                end
            end
        end
        m.safe_yaw=m.yaw
        self.retry_at=nil;self.status="1档防穿模：路径畅通"
    end)
    self.cost=self.cost+math.max(0,os.clock()-started)
    if not ok then
        freeze(m,current,yaw);self.retry_at=now()+0.5
        self.status="1档防穿模检测失败，已暂停代码移动："..tostring(err)
    end
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
