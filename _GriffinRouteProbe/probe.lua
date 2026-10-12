local Fall=require("_GriffinRouteProbe.fall")
-- Reads every observed stage; stores 20 Hz complete frames plus bounded anomaly windows.
-- Native callbacks enqueue numeric snapshots only. File output is tick/shutdown only.
local Probe={};Probe.__index=Probe
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function vec(v)
    assert(v and finite(v.x) and finite(v.y) and finite(v.z),"Invalid position")
    return {x=v.x,y=v.y,z=v.z}
end
local function add(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
local function sub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
local function gap(a,b)
    if not a or not b then return nil end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function clone(v)
    if type(v)~="table" then return v end
    local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r
end
function Probe.new(env,anchor,fall_stop)
    return setmetatable({env=env,anchor=anchor,fall_stop=fall_stop,running=false,status="玩家位置探针：关闭",queue={},part=0},Probe)
end
function Probe:start()
    if self.running then return end
    if self.pending or #self.queue>0 then self.status="上一轮正在保存，请稍后再勾选";return end
    local d=self.env.driver()
    local ok,refs=pcall(function()
        assert(d and self.env.owned(d) and not self.env.paused(),"请先开始 Beta 驾驶并关闭游戏菜单")
        return self.env.bind(d)
    end)
    if not ok then self.status="探针未开启："..tostring(refs);return end
    self.driver=d;self.refs=refs;self.running=true;self.pending=false
    self.instances={player=tostring(d.player),griffin=tostring(refs.character)}
    self.session=os.date("!%Y%m%dT%H%M%SZ").."_"..math.floor(os.clock()*1000).."_"..tostring((self.serial or 0)+1)
    self.serial=(self.serial or 0)+1;self.part=0;self.frames=0;self.rows=0
    self.saved_frames=0;self.queued_frames=0;self.windows=0;self.read_errors=0;self.errors={}
    self.ring={};self.seen={};self.last={};self.edges={};self.queue={};self.current=nil
    self.events={};self.next_regular=-math.huge;self.burst=0;self.cooldown=-math.huge
    self.deadline=self.env.wall()+60;self.last_flush=self.env.wall();self.expected=nil;self.retry_wall=nil
    self.status="玩家位置探针：记录中（60秒）；关闭勾选即保存"
end
function Probe:stop(reason)
    if not self.running then return end
    self.running=false
    if self.current and #self.current.stages>0 then self:enqueue(self.current);self.current=nil end
    self.pending=true;self.reason=reason or "手动停止";self.driver=nil;self.refs=nil
    self.status="玩家位置探针：待保存（"..self.reason.."）"
end
function Probe:read(d,stage)
    local r={stage=stage,time=self.env.time(),clock=os.clock(),sequence=self.rows+1,
        behavior_frame=self.env.behavior_frame and self.env.behavior_frame() or nil,
        errors={},anchor=self.anchor.enabled and "root_fixed_offset" or "head"}
    local function group(name,fn)
        if self.errors[name] then r.errors[name]=self.errors[name];return end
        local ok,err=pcall(fn)
        if not ok then self.errors[name]=tostring(err);r.errors[name]=tostring(err);self.read_errors=self.read_errors+1 end
    end
    local origin
    group("player",function()
        r.player_scene=vec(d.transform:call("get_Position()"))
        r.player_universal=vec(d.transform:call("get_UniversalPosition()"))
        origin=sub(r.player_universal,r.player_scene);r.scene_origin=origin
    end)
    group("context",function() r.context_universal=vec(d.context:call("get_Pos()")) end)
    group("controller",function()
        r.controller_scene=vec(d.controller:call("get_Position()"))
        if origin then r.controller_universal=add(r.controller_scene,origin) end
    end)
    group("bones",function()
        if d.root_joint and d.root_joint:get_Valid() then r.root_scene=vec(d.root_joint:call("get_Position()")) end
        if d.hip_joint and d.hip_joint:get_Valid() then r.hip_scene=vec(d.hip_joint:call("get_Position()")) end
        if origin then
            if r.root_scene then r.root_universal=add(r.root_scene,origin) end
            if r.hip_scene then r.hip_universal=add(r.hip_scene,origin) end
        end
    end)
    local b=self.refs
    group("griffin",function()
        r.griffin_scene=vec(b.transform:call("get_Position()"))
        r.griffin_universal=vec(b.transform:call("get_UniversalPosition()"))
        local q=b.transform:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"Invalid rotation")
        r.griffin_rotation={x=q.x,y=q.y,z=q.z,w=q.w}
        if d.rider_head and d.rider_head:get_Valid() then
            r.head_scene=vec(d.rider_head:call("get_Position()"))
            r.head_relative=sub(r.head_scene,r.griffin_scene)
        end
    end)
    group("targets",function()
        assert(b.tc:call("get_Owner()")==b.go and b.tc:call("get_Chara()")==b.character
            and b.ctrl:call("get_CachedCharacter()")==b.character,"Target ownership changed")
        r.character_target_scene=vec(b.tc:call("get_TargetPosition()"))
        r.flight_target_scene=vec(b.ctrl:call("get_TargetPosition()"))
        r.target_is_player=b.tc:call("get_TargetCharacter()")==d.player
        r.target_type=tostring(b.tc:call("get_TargetType()"))
    end)
    group("state",function()
        assert(b.manager:get_Valid() and b.character:call("get_ActionManager()")==b.manager,"ActionManager changed")
        r.player_fsm=d.fsm:call("get_Enabled()");r.freeze_requested=d.freeze_requested==true
        r.player_sec_fall=d.player:get_field("SecFall")
        local action=b.manager:get_field("CurrentAction")
        r.griffin_action=action and tostring(action:get_field("Name")) or nil
    end)
    group("player_ground",function()
        r.player_ground=d.player:call("get_IsGround()")
        r.player_ground_original=d.ground_original;r.player_ground_original_time=d.ground_original_time
    end)
    group("player_action",function()
        local manager=assert(d.player:call("get_ActionManager()"),"Player ActionManager unavailable")
        assert(manager:call("get_GameObject()")==d.player_go and manager.Fsm==d.fsm,"Player ActionManager ownership changed")
        local action=manager:get_field("CurrentAction")
        r.player_action=action and tostring(action:get_field("Name")) or nil
    end)
    if stage=="behavior_before_anchor" or stage=="behavior_native_after" or stage=="render_before_seat" or stage=="player_free_fall_stop_after" then
        Fall.capture(d,r,group)
    end
    if self.fall_stop then r.native_fall_stop=self.fall_stop:snapshot() end
    r.gear=d.gear;r.mode=d.mode;r.external_control=d.external_control==true
    r.navigation=clone(d.route_navigation);r.planned_scene=d.anchor_target and vec(d.anchor_target) or nil
    if stage=="player_transform_written" and origin and r.planned_scene then self.expected=add(r.planned_scene,origin) end
    r.expected_universal=self.expected and vec(self.expected) or nil
    if r.player_universal and r.griffin_universal then r.player_relative=sub(r.player_universal,r.griffin_universal) end
    if r.griffin_scene then
        if r.root_scene then r.root_relative=sub(r.root_scene,r.griffin_scene) end
        if r.hip_scene then r.hip_relative=sub(r.hip_scene,r.griffin_scene) end
    end
    r.context_gap=gap(r.player_universal,r.context_universal)
    r.controller_gap=gap(r.player_universal,r.controller_universal)
    r.expected_gap=gap(r.player_universal,r.expected_universal)
    return r
end
function Probe:enqueue(frame)
    if self.seen[frame.id] then return end
    if #self.queue>=240 then self.current=nil;self:stop("保存队列已满");return end
    self.seen[frame.id]=true;self.queue[#self.queue+1]=frame;self.queued_frames=self.queued_frames+1
end
function Probe:capture(stage)
    if not self.running then return end
    if self.env.wall()>=self.deadline then self:stop("60秒到时");return end
    if self.env.paused() then
        if self.current then self.current.partial="paused";self:finish_frame() end
        self.last={};self.edges={};self.expected=nil;return
    end
    local d=self.env.driver();local b=self.refs
    local ok,owned=pcall(function()
        return d==self.driver and self.env.owned(d) and d.spawn.result.go==b.go
            and d.spawn.result.chara==b.character and b.character:call("get_Transform()")==b.transform
    end)
    if not ok or not owned then self:stop("驾驶或精确实例已变化");return end
    if not self.current then self.current={id=self.frames+1,time=self.env.time(),stages={},reasons={}} end
    if #self.current.stages>=32 then return end
    local row=self:read(d,stage);self.rows=self.rows+1
    self.current.stages[#self.current.stages+1]=row
    local function flag(name,value,threshold)
        local key=stage..":"..name
        local yes=value~=nil and value>threshold
        if yes and not self.edges[key] then self.current.reasons[#self.current.reasons+1]={kind=name,value=value,stage=stage} end
        self.edges[key]=yes
    end
    if stage~="behavior_before_anchor" and stage~="player_transform_written" then
        flag("player_changed_after_write",row.expected_gap,0.10)
        flag("context_gap",row.context_gap,0.10);flag("controller_gap",row.controller_gap,0.10)
    end
    if stage=="player_transform_written" then flag("planned_write_gap",row.expected_gap,0.10) end
    local prev=self.last[stage]
    if prev then
        flag("head_relative_step",gap(row.head_relative,prev.head_relative),0.50)
        flag("player_relative_step",gap(row.player_relative,prev.player_relative),2.0)
        if stage=="joint_seated_after" or stage=="render_seated_after" or stage=="render_native_after" then
            flag("root_relative_step",gap(row.root_relative,prev.root_relative),2.0)
            flag("hip_relative_step",gap(row.hip_relative,prev.hip_relative),2.0)
        end
    end
    self.last[stage]=row
    if stage=="render_native_after" then self:finish_frame() end
end
function Probe:finish_frame()
    local f=self.current;if not f then return end
    self.current=nil;self.frames=self.frames+1
    if #f.reasons>0 and self.windows<8 and self.env.time()>=self.cooldown then
        self.windows=self.windows+1;self.cooldown=self.env.time()+1;self.burst=6
        self.events[#self.events+1]={frame=f.id,time=f.time,reasons=clone(f.reasons)}
        for _,old in ipairs(self.ring) do self:enqueue(old) end
    end
    if self.env.time()>=self.next_regular or self.burst>0 then
        self:enqueue(f);self.next_regular=self.env.time()+0.05
    end
    self.burst=math.max(0,self.burst-1)
    self.ring[#self.ring+1]=f;if #self.ring>5 then table.remove(self.ring,1) end
    if self.frames>=12000 or self.rows>=200000 then self:stop("采样上限") end
end
function Probe:tick(force)
    if not self.running and not self.pending and #self.queue==0 then return end
    if not force and self.retry_wall and self.env.wall()<self.retry_wall then return end
    if self.running and self.env.wall()>=self.deadline then self:stop("60秒到时") end
    if not force and not self.pending and self.env.wall()-self.last_flush<2 then return end
    if #self.queue==0 and not self.pending then return end
    local count=math.min(#self.queue,120)
    local frames={};for i=1,count do frames[i]=self.queue[i] end
    local final=self.pending and count==#self.queue
    local payload={version="0.1.41",session=self.session,part=self.part+1,instances=self.instances,frames=frames}
    if final then payload.summary={reason=self.reason,observed_frames=self.frames,observed_stages=self.rows,
        saved_frames=self.saved_frames+count,anomaly_windows=self.windows,read_errors=self.read_errors,
        events=self.events,field_errors=self.errors,baseline_hz=20,pre_frames=5,post_frames_including_trigger=6} end
    local name="GriffinRouteProbe_"..self.session.."_"..string.format("%03d",self.part+1)..".json"
    local ok,value=pcall(self.env.dump,name,payload)
    self.last_flush=self.env.wall()
    if not ok or value==false then
        self.retry_wall=self.env.wall()+2
        self:stop("写盘失败，保留队列等待重试");self.status="探针保存失败，已停止采样并保留待保存数据";return false
    end
    self.retry_wall=nil
    self.part=self.part+1;self.saved_frames=self.saved_frames+count
    for _=1,count do table.remove(self.queue,1) end
    if final then
        self.pending=false;self.ring={};self.last={};self.seen={}
        self.status="探针已保存："..self.reason.."；异常窗 "..self.windows.."；读取错误 "..self.read_errors
    end
    return true
end
function Probe:shutdown()
    self:stop("脚本重置")
    while #self.queue>0 or self.pending do if not self:tick(true) then break end end
end
return Probe
