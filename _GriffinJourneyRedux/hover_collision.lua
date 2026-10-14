-- Fixed directional look-ahead guard. Own native queries; accepted poses only.
return function(ctx)
local _ENV=ctx
hover_collision={enabled=false,return_to_safe=false,radius=4,height=4,span=8,lateral=0,margin=0.15,center_margin=0,center_distance=3,end_distance=3,side_distance=3,
    auto_land=false,land_distance=2,land_grace=3,ground_status="近地降落：关闭",
    casts=0,blocks=0,contacts=0,cost=0,status="1档防穿模：关闭"}
local guard=hover_collision
local config_numbers={
    {"radius",0.25,20},{"height",-15,20},{"span",0,30},{"lateral",0,30},{"margin",0.02,1},
    {"center_margin",0,20},{"center_distance",0.25,50},{"end_distance",0.25,50},{"side_distance",0.25,50},{"land_distance",0.25,15},{"land_grace",0,10}}
local config_flags={"enabled","return_to_safe","auto_land"}
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
guard.ground_status=guard.auto_land and "近地降落：等待1档悬停" or "近地降落：关闭"
function guard:persist()
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
    guard.casts=guard.casts+1
    guard.last_query={start=plain(start),finish=plain(finish),radius=radius,sequence=guard.casts}
    a.method:call(nil,a.sphere,Vector3f.new(start.x,start.y,start.z),
        Vector3f.new(finish.x,finish.y,finish.z),a.options,a.filter,a.result)
    local count=a.result:call("get_NumContactPoints()")
    assert(finite(count) and count>=0 and count<=64,"Too many or invalid collision contacts")
    guard.contacts=guard.contacts+count
    -- Deliberately avoid dereferencing native contact/collider pointers.
    guard.last_query.contacts=count
    return count>0,count
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
    if guard.return_to_safe then
        if safe then m.position=plain(safe.position);m.yaw=safe.yaw end
        m.rebase_after_block=nil
    else
        m.position=plain(current)
        m.yaw=m.collision_actual_yaw or m.yaw
        m.rebase_after_block=true
    end
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil
end
function guard:record(name,detail,urgent)
    if collision_debug then collision_debug:record(name,detail,urgent) end
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
        if not ok then self.status="切换位置同步失败："..tostring(err);self:record("toggle_error",tostring(err),true);return end
    end
    self.enabled=value==true;self.epoch=(self.epoch or 0)+1;self.retry_at=nil
    self.status=self.enabled and "1档防穿模：等待位移" or "1档防穿模：关闭"
    self:record("collision_toggle",{enabled=self.enabled},true)
    self:persist()
end
function guard:set_return_to_safe(value)
    -- Reset both A/B choices at the current native pose; never revive a stale target.
    local previous=self.return_to_safe
    self.return_to_safe=value==true
    self:set_enabled(self.enabled)
    self:record("return_to_safe_toggle",{previous=previous,enabled=self.return_to_safe},true)
end
function guard:latch(m,reason)
    if self.return_to_safe or m.input_lock then return end
    m.input_lock=command();m.rebase_after_block=true
    self:record("input_block_latched",{reason=reason,command=m.input_lock,actual=self.actual,target=self.target,
        probe=self.probes and self.probes[m.write_phase or "direct"],query=self.last_query},true)
end
function guard:hold_input(d,m)
    local locked=m.input_lock
    if not self.enabled or self.return_to_safe or not locked then return false end
    local c=command()
    local same=locked.vertical==c.vertical and locked.longitudinal==c.longitudinal and locked.turn==c.turn
    m.vx=0;m.vy=0;m.vz=0;m.turn=0;m.coast=nil;m.pending_pose=nil
    if not same then
        m.input_lock=nil;m.rebase_after_block=true;m.collision_resume_pending=true
        self:record("input_block_released",{previous=locked,current=c,position=m.position},true)
        return false
    end
    m.last_time=now()
    self.held_blocks=(self.held_blocks or 0)+1
    local safe=m.collision_safe and m.collision_safe.position
    if safe then
        local diff={x=m.position.x-safe.x,y=m.position.y-safe.y,z=m.position.z-safe.z}
        self.drift=math.sqrt(dot(diff,diff));self.max_drift=math.max(self.max_drift or 0,self.drift)
    end
    self.actual=plain(m.position);self.target=plain(m.position);self.request={x=0,y=0,z=0,yaw=0}
    self.last_phase="pre_behavior"
    self.probes=self.probes or {}
    self.probes.pre_behavior={time=now(),actual=plain(m.position),target=plain(m.position),
        request={x=0,y=0,z=0},drift=self.drift,result="held_block",command=c}
    self.status="1档防穿模：同向输入已阻断，请松开或改变方向后重试"
    d.heading={x=math.sin(m.yaw),z=math.cos(m.yaw)}
    return true
end
function guard:skip_post(m)
    self.probes=self.probes or {}
    self.probes.post_behavior={time=now(),result=m.input_lock and "skipped_input_block" or "skipped_no_accepted_pose"}
end
function guard:prepare(d,m,planning)
    if not self.enabled then return true end
    if not alive or state.generation~=generation or active~=d or d.gear~=1 or not d.controls_active
        or d.external_control or d.mode=="taking_off" or d.manual_hold=="landing"
        or d.native_action~="Ch253HoverWaitHoHomingHeight" or menu.gameplay_paused() then return false end
    if m.collision_epoch~=self.epoch or not m.collision_safe then
        m.position=vector(m.transform:call("get_UniversalPosition()"));m.yaw=yaw_of(m)
        m.collision_safe={position=plain(m.position),yaw=m.yaw};m.collision_epoch=self.epoch
        self:record("hover_reference",{position=plain(m.position),yaw=m.yaw},true)
    end
    if planning and m.rebase_after_block and not self.return_to_safe then
        -- Keep following the actual native pose while rejected; releasing input
        -- must not revive the pre-collision absolute target on a later frame.
        m.position=vector(m.transform:call("get_UniversalPosition()"));m.yaw=yaw_of(m)
    end
    return true
end
function guard:accepted(m)
    if self.enabled and m.collision_resume_pending then
        m.collision_resume_pending=nil
        self:record("motion_resumed",{position=m.position,actual=self.actual,request=self.request},true)
    end
    if self.enabled then m.collision_safe={position=plain(m.position),yaw=m.yaw};self.writes=(self.writes or 0)+1;m.rebase_after_block=nil end
end
function guard:constrain(d,m,current)
    if not self.enabled then return true end
    if not self:prepare(d,m) then return false end
    local started=os.clock();local allowed=false
    local ok,err=pcall(function()
        assert(d.spawn and d.spawn.result and d.spawn.result.go==m.go and d.spawn.result.chara==m.character,
            "Collision instance changed")
        local safe=m.collision_safe
        local drift={x=current.x-safe.position.x,y=current.y-safe.position.y,z=current.z-safe.position.z}
        self.drift=math.sqrt(dot(drift,drift));self.max_drift=math.max(self.max_drift or 0,self.drift)
        -- Native drift is telemetry, not an unconditional lockout. Check the actual path.
        local delta={x=m.position.x-current.x,y=m.position.y-current.y,z=m.position.z-current.z}
        vector(delta)
        local yaw=yaw_of(m)
        m.collision_actual_yaw=yaw
        local angle=(m.yaw-yaw+math.pi)%(2*math.pi)-math.pi
        self.request={x=delta.x,y=delta.y,z=delta.z,yaw=angle}
        self.actual=plain(current);self.target=plain(m.position)
        self.last_phase=m.write_phase
        self.probes=self.probes or {}
        local probe={time=now(),actual=plain(current),target=plain(m.position),request=plain(delta),drift=self.drift,result="checking",balls={}}
        self.probes[m.write_phase or "direct"]=probe
        if dot(delta,delta)<1e-10 and math.abs(angle)<1e-5 then
            probe.result="idle";self.status="1档防穿模：等待位移";return
        end
        if self.retry_at and now()<self.retry_at then probe.result="retry_wait";freeze(m,current);return end
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
                local ball={time=now(),center=point.center==true,forward=offset,right=side,
                    distance=distance,requested_step=length}
                probe.balls[#probe.balls+1]=ball
                if length>distance+0.00001 then
                    ball.result="step_exceeds_fixed_distance";probe.result=ball.result
                    self.actual=plain(current);self.target=plain(m.position);self.last_query=nil
                    freeze(m,current);self:latch(m,ball.result);self.blocks=self.blocks+1
                    self.status="1档防穿模：本次位移超过固定探测距离，请调大距离"
                    return
                end
                -- Direction follows the pose request; look-ahead length never
                -- follows step length. Rotation keeps the existing arc margin.
                local direction={x=move.x/length,y=move.y/length,z=move.z/length}
                local finish={x=start.x+direction.x*distance,y=start.y+direction.y*distance,z=start.z+direction.z*distance}
                local radius=self.radius+self.margin+(point.center and self.center_margin or 0)+math.sqrt(offset*offset+side*side)*(1-math.cos(math.abs(angle)/2))
                ball.radius=radius;ball.direction=direction;ball.result="checking"
                self.last_center=point.center==true;self.last_ball=offset;self.last_lateral=side;self.last_direction="forward"
                local hit,count=cast(start,finish,radius)
                ball.forward_hits=count
                if not hit then
                    -- Reverse traverses the SAME forward segment, so a thin mesh
                    -- facing the opposite way can still be found; no rearward probe.
                    self.last_direction="reverse"
                    hit,count=cast(finish,start,radius);ball.reverse_hits=count
                end
                ball.result=hit and "blocked" or "clear"
                if point.center then self.center_probe=ball end
                if hit then
                    probe.result="blocked";freeze(m,current);self:latch(m,"fixed_probe_contact");self.blocks=self.blocks+1
                    self.status="1档防穿模：固定距离内有障碍，已拒绝位移"
                    return
                end
            end
        end
        probe.result="clear";allowed=true;self.retry_at=nil;self.status="1档防穿模：路径畅通"
    end)
    self.cost=self.cost+math.max(0,os.clock()-started)
    if not ok then
        freeze(m,current);self:latch(m,"query_error");self.retry_at=now()+0.5
        self.status="1档防穿模检测失败，已暂停代码移动："..tostring(err)
        self:record("query_error",tostring(err),true)
    end
    return ok and allowed
end
function guard:set_auto_land(value)
    self.auto_land=value==true;self.land_driver=nil;self.land_since=nil;self.land_hits=0;self.land_next=nil
    self.ground_status=self.auto_land and "近地降落：等待1档悬停" or "近地降落：关闭"
    self:record("auto_land_toggle",{enabled=self.auto_land,distance=self.land_distance},true)
    self:persist()
end
function guard:observe(d,ch,tr,flying,ground,action)
    if not self.enabled and not self.auto_land and not (collision_debug and collision_debug.enabled) then return end
    self.driver_state={position=vector(tr:call("get_UniversalPosition()")),gear=d.gear,mode=d.mode,action=action,flying=flying,ground=ground,
        controls=d.controls_active,external=d.external_control,hold=d.manual_hold,
        stick={x=input.hover_x or input.x,y=input.y},up=held(input.buttons,masks.hover_up),down=held(input.buttons,masks.hover_down)}
    if self.enabled and (not flying or ground) then self.status="1档防穿模：等待位移（地面）"
    elseif self.enabled and d.mode=="taking_off" then self.status="1档防穿模：起飞中，等待悬停" end
    if not self.auto_land then return end
    local valid=alive and state.generation==generation and active==d and d.gear==1 and d.controls_active
        and flying and not ground and not d.external_control and d.mode~="taking_off"
        and action=="Ch253HoverWaitHoHomingHeight" and not d.pending
        and not d.intent and not d.action_transition and not d.manual_hold and not menu.gameplay_paused()
    if not valid then
        self.land_since=nil;self.land_driver=nil;self.land_hits=0
        self.ground_status=d.manual_hold=="landing" and "近地降落：降落中" or "近地降落：等待1档稳定悬停"
        return
    end
    if self.land_driver~=d then self.land_driver=d;self.land_since=now();self.land_hits=0;self.land_next=nil end
    if now()-self.land_since<self.land_grace then
        self.ground_status=string.format("近地降落：起飞/切入保护剩余 %.1f 秒",self.land_grace-(now()-self.land_since));return
    end
    if held(input.buttons,masks.hover_up) then
        self.land_hits=0;self.ground_status="近地降落：上升输入，暂缓降落";return
    end
    if self.land_next and now()<self.land_next then return end
    self.land_next=now()+0.2
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
        self.ground_status="近地检测失败："..tostring(hit);self:record("ground_query_error",tostring(hit),true);return
    end
    self.ground_within=hit;self.ground_checked_at=now()
    self.land_hits=hit and self.land_hits+1 or 0
    self.ground_status=hit and string.format("近地降落：直下表面约≤%.2f米，确认%d/3",self.land_distance,self.land_hits)
        or string.format("近地降落：直下%.2f米内未命中",self.land_distance)
    if self.land_hits>=3 then
        request_hover_landing(d,"near_ground")
        self.ground_status="近地降落：已提交原生降落"
        self:record("auto_land_requested",{distance=self.land_distance,hits=self.land_hits},true)
        self.land_since=nil;self.land_driver=nil;self.land_hits=0
    end
end
function guard:draw()
    if not imgui.tree_node("1档防穿模测试") then return end
    local changed,value=menu.toggle("启用1档防穿模（实验）",self.enabled)
    if changed then self:set_enabled(value) end
    changed,value=menu.toggle("受阻后拉回最后安全位置（对照）",self.return_to_safe)
    if changed then self:set_return_to_safe(value) end
    imgui.text("拉回关闭时：受阻同向输入保持阻断，松开或改变方向才重新检测。")
    imgui.text(self.return_to_safe and "受阻拉回：开启（0.3.17旧逻辑）" or "受阻拉回：关闭（受阻后按实际位置重新计算）")
    changed,value=menu.toggle("启用1档近地自动降落（实验）",self.auto_land)
    if changed then self:set_auto_land(value) end
    local edit,distance=imgui.slider_float("近地降落距离（根节点到下方表面/米）",self.land_distance,0.25,15)
    if edit and finite(distance) then self.land_distance=math.max(0.25,math.min(15,distance));self.land_hits=0;self.land_next=nil;self:persist() end
    local grace_edit,grace=imgui.slider_float("起飞/切入悬停保护时间（秒）",self.land_grace,0,10)
    if grace_edit and finite(grace) then self.land_grace=math.max(0,math.min(10,grace));self.land_hits=0;self.land_since=now();self:persist() end
    imgui.text("球半径表示身体体积；固定探测距离表示沿请求方向额外探测多远。")
    for _,spec in ipairs({{"center_distance","中心球固定探测距离（米）",0.25,50},
        {"end_distance","前后球固定探测距离（米）",0.25,50},{"side_distance","左右球固定探测距离（米）",0.25,50},
        {"radius","检测球半径（米）",0.25,20},{"height","检测球中心高度（米）",-15,20},
        {"span","前后检测球偏移（米）",0,30},{"lateral","左右检测球偏移（米；0关闭两侧球）",0,30},{"margin","额外安全余量（米）",0.02,1},{"center_margin","中心球额外安全余量（米）",0,20}}) do
        local edit,result=imgui.slider_float(spec[2],self[spec[1]],spec[3],spec[4])
        if edit and finite(result) then self[spec[1]]=math.max(spec[3],math.min(spec[4],result));self.retry_at=nil;self:persist() end
    end
    imgui.text(self.config_status or "检测配置：已加载；改动自动保存")
    imgui.text(self.status)
    imgui.text(self.ground_status)
    if collision_debug then collision_debug:draw() end
    imgui.text(string.format("球体查询：%d；拦截：%d；接触点：%d",self.casts,self.blocks,self.contacts))
    if self.casts>0 then imgui.text(string.format("粗略Lua计时／查询：%.3f 毫秒",self.cost*1000/self.casts)) end
    imgui.text("仅1档；2档不查询。检测参数与功能开关自动保存；LOG录制重载关闭。")
    imgui.tree_pop()
end
end
