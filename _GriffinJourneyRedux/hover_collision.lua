-- Fixed directional look-ahead guard. Own native queries; accepted poses only.
return function(ctx)
local _ENV=ctx
hover_collision={enabled=true,radius=4,height=4,span=8,lateral=0,margin=0.15,center_margin=0,center_distance=6,end_distance=3,side_distance=3,
    auto_land=true,land_distance=3.662,land_grace=3,ground_status="近地降落：关闭",
    status="1档防穿模：关闭"}
local guard=hover_collision
local config_numbers={
    {"radius",0.25,20},{"height",-15,20},{"span",0,30},{"lateral",0,30},{"margin",0.02,1},
    {"center_margin",0,20},{"center_distance",0.25,50},{"end_distance",0.25,50},{"side_distance",0.25,50},{"land_distance",0.25,15},{"land_grace",0,10}}
local config_flags={"enabled","auto_land"}
menu.default_seed.hover_collision_config={version=2,mode="fixed_directional",return_to_safe=false}
for _,spec in ipairs(config_numbers) do menu.default_seed.hover_collision_config[spec[1]]=guard[spec[1]] end
for _,key in ipairs(config_flags) do menu.default_seed.hover_collision_config[key]=guard[key] end
local saved_config=loaded_settings and loaded_settings.hover_collision_config
if type(saved_config)=="table" then
    for _,spec in ipairs(config_numbers) do
        local v=saved_config[spec[1]]
        if finite(v) then guard[spec[1]]=math.max(spec[2],math.min(spec[3],v)) end
    end
    for _,key in ipairs(config_flags) do if type(saved_config[key])=="boolean" then guard[key]=saved_config[key] end end
end
function guard:configuration()
    local out={version=2,mode="fixed_directional"}
    for _,spec in ipairs(config_numbers) do out[spec[1]]=self[spec[1]] end
    for _,key in ipairs(config_flags) do out[key]=self[key] end
    return out
end
settings.hover_collision_config=guard:configuration()
guard.status=guard.enabled and "1档防穿模：等待位移" or "1档防穿模：关闭"
guard.ground_status=guard.auto_land and "近地降落：等待1/2档飞行" or "近地降落：关闭"
function guard:persist()
    if menu.applying_edits then return true end
    settings.hover_collision_config=self:configuration()
    local ok=controls.save()
    self.config_status=ok and "检测配置：已保存" or "检测配置：保存失败，请查看菜单错误"
    return ok
end
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
    a.method:call(nil,a.sphere,Vector3f.new(start.x,start.y,start.z),
        Vector3f.new(finish.x,finish.y,finish.z),a.options,a.filter,a.result)
    local count=a.result:call("get_NumContactPoints()")
    assert(finite(count) and count>=0 and count<=64,"Too many or invalid collision contacts")
    -- Deliberately avoid dereferencing native contact/collider pointers.
    if guard.on_cast then guard.on_cast(start,finish,radius,count) end
    return count>0,count
end
-- One query on voluntary exit, independent of both experimental toggles.
function guard:ground_within(transform,distance)
    local p=vector(transform:call("get_Position()"))
    local radius=0.01
    -- Bottom of the final sphere is exactly distance below the root.
    return cast({x=p.x,y=p.y+radius,z=p.z},
        {x=p.x,y=p.y-distance+radius,z=p.z},radius)
end
local function yaw_of(m)
    local q=m.transform:call("get_Rotation()")
    assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"Collision rotation unavailable")
    local norm=math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
    assert(norm>0.000001,"Invalid collision rotation")
    local x,y,z,w=q.x/norm,q.y/norm,q.z/norm,q.w/norm
    return math.atan(2*(x*z+w*y),1-2*(x*x+y*y))
end
local function command()
    local up,down=held(input.buttons,masks.hover_up),held(input.buttons,masks.hover_down)
    local function sign(v) return v>0 and 1 or (v<0 and -1 or 0) end
    return {vertical=up~=down and (up and 1 or -1) or 0,
        longitudinal=sign(input.y or 0),turn=sign(input.hover_x or input.x or 0)}
end
local function freeze(m,current)
    local safe=m.collision_safe
    if guard.block_policy then
        guard.block_policy(m,current)
    else
        m.position=plain(current)
        m.yaw=m.collision_actual_yaw or m.yaw
        m.rebase_after_block=true
    end
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil
end
function guard:record(name,detail,urgent)
    if guard.on_event then guard.on_event(name,detail,urgent) end
end
function guard:set_enabled(value)
    -- Switching either way must discard an old rejected/pending absolute target.
    local d=active
    local m=d and d.hover_motion
    if m then
        local ok,err=pcall(function()
            assert(validate_spawn(d.spawn)==m.character,"Collision binding changed")
            m.position=vector(m.transform:call("get_UniversalPosition()"));m.yaw=yaw_of(m)
            m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil
            m.collision_safe=nil;m.pending_pose=nil;m.rebase_after_block=nil;m.input_lock=nil;m.collision_resume_pending=nil;m.last_time=now()
            d.heading={x=math.sin(m.yaw),z=math.cos(m.yaw)}
        end)
        if not ok then self.status="切换位置同步失败："..tostring(err);if self.on_event then self:record("toggle_error",tostring(err),true) end;return end
    end
    self.enabled=value==true;self.epoch=(self.epoch or 0)+1;self.retry_at=nil
    self.status=self.enabled and "1档防穿模：等待位移" or "1档防穿模：关闭"
    if self.on_event then self:record("collision_toggle",{enabled=self.enabled},true) end
    self:persist()
end
function guard:latch(m,reason)
    if self.block_policy or m.input_lock then return end
    m.input_lock=command();m.rebase_after_block=true
    if self.on_event then self:record("input_block_latched",{reason=reason,command=m.input_lock,actual=self.actual,target=self.target,
        },true) end
end
function guard:hold_input(d,m)
    local locked=m.input_lock
    if not self.enabled or self.block_policy or not locked then return false end
    local c=command()
    local same=locked.vertical==c.vertical and locked.longitudinal==c.longitudinal and locked.turn==c.turn
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil;m.pending_pose=nil
    if not same then
        m.input_lock=nil;m.rebase_after_block=true;m.collision_resume_pending=true
        if self.on_event then self:record("input_block_released",{previous=locked,current=c,position=m.position},true) end
        return false
    end
    m.last_time=now()
    if self.on_path then self.on_path(m,m.position,{x=0,y=0,z=0},0,"held_block") end
    self.status="1档防穿模：同向输入已阻断，请松开或改变方向后重试"
    d.heading={x=math.sin(m.yaw),z=math.cos(m.yaw)}
    return true
end
function guard:skip_post(m) end
function guard:prepare(d,m,planning)
    if not self.enabled then return true end
    if not alive or state.generation~=generation or active~=d or d.gear~=1 or not d.controls_active
        or d.external_control or d.mode=="taking_off" or d.manual_hold=="landing"
        or d.native_action~="Ch253HoverWaitHoHomingHeight" or menu.gameplay_paused() then return false end
    if m.collision_epoch~=self.epoch or not m.collision_safe then
        m.position=vector(m.transform:call("get_UniversalPosition()"));m.yaw=yaw_of(m)
        m.collision_safe={position=plain(m.position),yaw=m.yaw};m.collision_epoch=self.epoch
        if self.on_event then self:record("hover_reference",{position=plain(m.position),yaw=m.yaw},true) end
    end
    if planning and m.rebase_after_block and not self.block_policy then
        -- Keep following the actual native pose while rejected; releasing input
        -- must not revive the pre-collision absolute target on a later frame.
        m.position=vector(m.transform:call("get_UniversalPosition()"));m.yaw=yaw_of(m)
    end
    return true
end
function guard:accepted(m)
    if self.enabled and m.collision_resume_pending then
        m.collision_resume_pending=nil
        if self.on_event then self:record("motion_resumed",{position=m.position,actual=self.actual,request=self.request},true) end
    end
    if self.enabled then m.collision_safe={position=plain(m.position),yaw=m.yaw};m.rebase_after_block=nil end
end
function guard:constrain(d,m,current)
    if not self.enabled then return true end
    if not self:prepare(d,m) then return false end
    local allowed=false
    local ok,err=pcall(function()
        assert(d.spawn and d.spawn.result and d.spawn.result.go==m.go and d.spawn.result.chara==m.character,
            "Collision instance changed")
        local safe=m.collision_safe
        local delta={x=m.position.x-current.x,y=m.position.y-current.y,z=m.position.z-current.z}
        vector(delta)
        local yaw=yaw_of(m)
        m.collision_actual_yaw=yaw
        local angle=(m.yaw-yaw+math.pi)%(2*math.pi)-math.pi
        if self.on_path then self.on_path(m,current,delta,angle,"checking") end
        if dot(delta,delta)<1e-10 and math.abs(angle)<1e-5 then
            self.status="1档防穿模：等待位移";return
        end
        if self.retry_at and now()<self.retry_at then freeze(m,current);return end
        local local_p=m.transform:call("get_Position()");vector(local_p)
        local oldx,oldz,newx,newz=math.sin(yaw),math.cos(yaw),math.sin(m.yaw),math.cos(m.yaw)
        local offsets={{forward=0,right=0,center=true},{forward=self.span,right=0},{forward=-self.span,right=0}}
        if self.lateral>0 then
            offsets[#offsets+1]={forward=0,right=self.lateral}
            offsets[#offsets+1]={forward=0,right=-self.lateral}
        end
        for _,point in ipairs(offsets) do
            local offset,side=point.forward,point.right
            local start={x=local_p.x+oldx*offset+oldz*side,y=local_p.y+self.height,z=local_p.z+oldz*offset-oldx*side}
            local actual_finish={x=local_p.x+delta.x+newx*offset+newz*side,y=local_p.y+delta.y+self.height,z=local_p.z+delta.z+newz*offset-newx*side}
            local move={x=actual_finish.x-start.x,y=actual_finish.y-start.y,z=actual_finish.z-start.z}
            local length=math.sqrt(dot(move,move))
            if length>=0.00001 then
                local distance=point.center and self.center_distance or (side~=0 and self.side_distance or self.end_distance)
                if length>distance+0.00001 then
                    freeze(m,current);self:latch(m,"step_exceeds_fixed_distance")
                    self.status="1档防穿模：本次位移超过固定探测距离，请调大距离"
                    return
                end
                -- Direction follows the pose request; look-ahead length never
                -- follows step length. Rotation keeps the existing arc margin.
                local direction={x=move.x/length,y=move.y/length,z=move.z/length}
                local finish={x=start.x+direction.x*distance,y=start.y+direction.y*distance,z=start.z+direction.z*distance}
                local radius=self.radius+self.margin+(point.center and self.center_margin or 0)+math.sqrt(offset*offset+side*side)*(1-math.cos(math.abs(angle)/2))
                if self.on_query then self.on_query(point,false) end
                local hit,count=cast(start,finish,radius)
                if not hit then
                    -- Reverse traverses the SAME forward segment, so a thin mesh
                    -- facing the opposite way can still be found; no rearward probe.
                    if self.on_query then self.on_query(point,true) end
                    hit,count=cast(finish,start,radius)
                end
                if self.on_ball then self.on_ball(point,distance,length,radius,direction,hit) end
                if hit then
                    freeze(m,current);self:latch(m,"fixed_probe_contact")
                    self.status="1档防穿模：固定距离内有障碍，已拒绝位移"
                    return
                end
            end
        end
        allowed=true;self.retry_at=nil;self.status="1档防穿模：路径畅通"
    end)
    if not ok then
        freeze(m,current);self:latch(m,"query_error");self.retry_at=now()+0.5
        self.status="1档防穿模检测失败，已暂停代码移动："..tostring(err)
        if self.on_event then self:record("query_error",tostring(err),true) end
    end
    return ok and allowed
end
function guard:set_auto_land(value)
    self.auto_land=value==true;self.land_driver=nil;self.land_gear=nil;self.land_since=nil;self.land_hits=0;self.land_next=nil
    self.ground_status=self.auto_land and "近地降落：等待1/2档飞行" or "近地降落：关闭"
    if self.on_event then self:record("auto_land_toggle",{enabled=self.auto_land,distance=self.land_distance},true) end
    self:persist()
end
function guard:observe(d,ch,tr,flying,ground,action)
    if not self.enabled and not self.auto_land then return end
    if self.on_observe then self.on_observe(d,ch,tr,flying,ground,action) end
    if self.enabled and (not flying or ground) then self.status="1档防穿模：等待位移（地面）"
    elseif self.enabled and d.mode=="taking_off" then self.status="1档防穿模：起飞中，等待悬停" end
    if not self.auto_land then return end
    local stable_hover=d.gear==1 and action=="Ch253HoverWaitHoHomingHeight"
    local stable_sprint=d.gear==2 and type(action)=="string" and action:sub(1,15)=="Ch253WrapAround"
    local valid=alive and state.generation==generation and active==d and (stable_hover or stable_sprint) and d.controls_active
        and flying and not ground and not d.external_control and d.mode~="taking_off"
        and not d.pending
        and not d.intent and not d.action_transition and not d.manual_hold and not menu.gameplay_paused()
    if not valid then
        self.land_since=nil;self.land_driver=nil;self.land_gear=nil;self.land_hits=0;self.land_next=nil
        self.ground_status=d.manual_hold=="landing" and "近地降落：降落中" or "近地降落：等待1/2档稳定飞行"
        return
    end
    if self.land_driver~=d or self.land_gear~=d.gear then self.land_driver=d;self.land_gear=d.gear;self.land_since=now();self.land_hits=0;self.land_next=nil end
    if now()-self.land_since<self.land_grace then
        self.ground_status=string.format("近地降落：起飞/切入保护剩余 %.1f 秒",self.land_grace-(now()-self.land_since));return
    end
    local ascending=d.gear==1 and held(input.buttons,masks.hover_up)
    if d.gear==2 then
        local up,down=held(input.buttons,masks.rb),held(input.buttons,masks.lb)
        ascending=up~=down and up or up==down and (input.y or 0)>0
    end
    if ascending then
        self.land_hits=0;self.ground_status="近地降落：上升输入，暂缓降落";return
    end
    if self.land_next and now()<self.land_next then return end
    self.land_next=now()+(d.gear==2 and 0.05 or 0.2)
    local ok,hit=pcall(function()
        assert(validate_spawn(d.spawn)==ch and d.spawn.result.go==ch:call("get_GameObject()"),"Ground query instance changed")
        local p=vector(tr:call("get_Position()"))
        -- A narrow vertical sweep reports only whether a surface is within range.
        -- No contact pointer reads; roofs/ledges beneath the root also count.
        local start={x=p.x,y=p.y+0.1,z=p.z}
        local finish={x=p.x,y=p.y-self.land_distance,z=p.z}
        return cast(start,finish,0.05)
    end)
    if not ok then
        self.land_hits=0;self.land_next=now()+1
        self.ground_status="近地检测失败："..tostring(hit);if self.on_event then self:record("ground_query_error",tostring(hit),true) end;return
    end
    self.ground_within=hit;self.ground_checked_at=now()
    self.land_hits=hit and self.land_hits+1 or 0
    self.ground_status=hit and string.format("近地降落：直下表面约≤%.2f米，确认%d/3",self.land_distance,self.land_hits)
        or string.format("近地降落：直下%.2f米内未命中",self.land_distance)
    if self.land_hits>=3 then
        request_hover_landing(d,"near_ground")
        self.ground_status="近地降落：已提交原生降落"
        if self.on_event then self:record("auto_land_requested",{distance=self.land_distance,hits=self.land_hits,gear=self.land_gear},true) end
        self.land_since=nil;self.land_driver=nil;self.land_gear=nil;self.land_hits=0
    end
end
function guard:draw()
    if not imgui.tree_node("碰撞检测与自动降落") then return end
    local cfg=menu.draft.hover_collision_config
    for _,spec in ipairs({{"enabled","悬停防穿模"},{"auto_land","近地自动降落"}}) do
        local changed,value=menu.toggle(spec[2],cfg[spec[1]])
        if changed then cfg[spec[1]]=value;menu.changed() end
    end
    for _,spec in ipairs({{"land_distance","近地降落距离（米）",0.25,15},{"land_grace","起飞与切换模式保护时间（秒）",0,10},
        {"center_distance","中心球固定探测距离（米）",0.25,50},{"end_distance","前后球固定探测距离（米）",0.25,50},
        {"side_distance","左右球固定探测距离（米）",0.25,50},{"radius","检测球半径（米）",0.25,20},
        {"height","检测球中心高度（米）",-15,20},{"span","前后检测球偏移（米）",0,30},
        {"lateral","左右检测球偏移（米；0关闭两侧球）",0,30},{"margin","额外安全余量（米）",0.02,1},
        {"center_margin","中心球额外安全余量（米）",0,20}}) do
        local changed,value=imgui.slider_float(spec[2],cfg[spec[1]],spec[3],spec[4])
        if changed and finite(value) then cfg[spec[1]]=math.max(spec[3],math.min(spec[4],value));menu.changed() end
    end
    imgui.text(self.status);imgui.text(self.ground_status)
    imgui.tree_pop()
end
end
