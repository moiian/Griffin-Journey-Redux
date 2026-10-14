-- Dedicated opt-in collision/landing journal; only plain Lua values reach JSON.
return function(ctx)
local _ENV=ctx
collision_debug={enabled=false,path="GriffinJourneyRedux_Collision_Log.json",status="专属LOG：关闭",seq=0,ring={},capacity=1200}
local dbg=collision_debug
local function plain(v,depth)
    if type(v)=="number" then return finite(v) and v or nil end
    if type(v)=="boolean" or type(v)=="string" then return v end
    if type(v)~="table" or (depth or 0)>7 then return nil end
    local out={}
    for k,item in pairs(v) do
        if type(k)=="number" or type(k)=="string" then out[k]=plain(item,(depth or 0)+1) end
    end
    return out
end
function dbg:flush(force)
    if not self.enabled or not self.dirty then return end
    local t=os.clock()
    if not force and self.last_flush and t-self.last_flush<1 then return end
    local list={}
    for i=math.max(1,self.seq-self.capacity+1),self.seq do list[#list+1]=self.ring[(i-1)%self.capacity+1] end
    local ok,result=pcall(json.dump_file,self.path,{version=VERSION,session=self.session,records=list,
        total_records=self.seq,limit=self.capacity,game_time=now()})
    self.last_flush=t
    if ok and result~=false then self.dirty=false;self.status="专属LOG：已写入 "..self.path
    else self.status="专属LOG写入失败："..tostring(result) end
end
function dbg:record(name,detail,urgent)
    if not self.enabled then return end
    self.seq=self.seq+1
    self.ring[(self.seq-1)%self.capacity+1]={seq=self.seq,time=now(),clock=os.clock(),kind=name,detail=plain(detail)}
    self.dirty=true
    if urgent then self:flush(true) end
end
function dbg:set_enabled(value)
    if value then
        if self.enabled then return end
        self.enabled=true;self.ring={};self.seq=0;self.session=tostring(os.time());self.last_sample=nil;self.last_flush=nil
        self:record("recording_started",{version=VERSION},true)
    else
        self:record("recording_stopped",{},true);self.enabled=false
        self.status="专属LOG：已停止，文件保留"
    end
end
function dbg:tick()
    if not self.enabled then return end
    local t=os.clock()
    if not self.last_sample or t-self.last_sample>=0.25 then
        self.last_sample=t
        local g=hover_collision;local d=active;local m=d and d.hover_motion
        self:record("sample",{driver=g.driver_state,collision={enabled=g.enabled,status=g.status,phase=g.last_phase,
            radius=g.radius,height=g.height,span=g.span,margin=g.margin,drift=g.drift,max_drift=g.max_drift,
            request=g.request,actual=g.actual,target=g.target,probes=g.probes,last_query=g.last_query,casts=g.casts,blocks=g.blocks,contacts=g.contacts,
            ball=g.last_ball,direction=g.last_direction,writes=g.writes},
            landing={enabled=g.auto_land,status=g.ground_status,distance=g.land_distance,grace=g.land_grace,
                hits=g.land_hits,within=g.ground_within,checked_at=g.ground_checked_at},
            motion=m and {position=m.position,yaw=m.yaw,vx=m.vx,vy=m.vy,vz=m.vz,turn=m.turn,coast=m.coast,
                pending=m.pending_pose,dirty=m.dirty,accepted=m.collision_safe},
            inertia={horizontal_accel=settings.hover_accel_tau,horizontal_stop=settings.hover_decel_tau,
                up_accel=settings.hover_up_accel_tau,up_stop=settings.hover_up_decel_tau,
                down_accel=settings.hover_down_accel_tau,down_stop=settings.hover_down_decel_tau,sprint_stop=settings.sprint_stop_tau}})
    end
    self:flush(false)
end
local function pos(v)
    return v and string.format("%.3f, %.3f, %.3f",v.x,v.y,v.z) or "无"
end
function dbg:draw()
    local changed,value=menu.toggle("记录防穿模/近地降落专属LOG",self.enabled)
    if changed then self:set_enabled(value) end
    if beta_button("立即保存专属LOG###BetaCollisionLogSave") then self:flush(true) end
    imgui.text(self.status)
    if not imgui.tree_node("位移与降落 DEBUG") then return end
    local g=hover_collision;local s=g.driver_state;local d=active;local m=d and d.hover_motion
    imgui.text("驾驶："..tostring(d~=nil).."；采样时状态："..tostring(s and s.mode).."；档位："..tostring(s and s.gear))
    imgui.text("动作："..tostring(s and s.action))
    imgui.text("Flight/Ground/外部接管："..tostring(s and s.flying).." / "..tostring(s and s.ground).." / "..tostring(s and s.external))
    if s then imgui.text(string.format("左摇杆：%.3f, %.3f；上移/下移：%s / %s",s.stick.x or 0,s.stick.y or 0,tostring(s.up),tostring(s.down))) end
    imgui.text("当前观测位置（Universal）："..pos(s and s.position))
    imgui.text("通过检测后的原生位置写入次数："..tostring(g.writes or 0))
    imgui.text("最后检测实际位置（Universal）："..pos(g.actual))
    imgui.text("最后检测目标位置（Universal）："..pos(g.target))
    imgui.text("最后请求位移："..pos(g.request))
    local pre=g.probes and g.probes.pre_behavior;local post=g.probes and g.probes.post_behavior
    imgui.text("行为前位移/结果："..pos(pre and pre.request).." / "..tostring(pre and pre.result))
    imgui.text("行为后修正/结果："..pos(post and post.request).." / "..tostring(post and post.result))
    imgui.text(string.format("最后原生偏移：%.4f米；最大：%.4f米（仅记录，不锁输入）",g.drift or 0,g.max_drift or 0))
    imgui.text("检测阶段/球偏移/方向："..tostring(g.last_phase).." / "..tostring(g.last_ball).." / "..tostring(g.last_direction))
    if m then imgui.text(string.format("速度 XYZ：%.3f, %.3f, %.3f；转速：%.3f",m.vx,m.vy,m.vz,m.turn)) end
    imgui.text("近地结果采样时间："..tostring(g.ground_checked_at).."；确认次数："..tostring(g.land_hits or 0))
    imgui.text("近地检查：根节点直下细球扫掠，显示阈值范围；屋顶也算下方表面。")
    imgui.text("LOG约4次/秒采样，每秒写盘；最多1200条，重新开启LOG覆盖上次记录。")
    imgui.tree_pop()
end
end
