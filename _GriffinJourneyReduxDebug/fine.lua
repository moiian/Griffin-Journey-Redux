-- Three-second, every-frame stage snapshots. Never invokes native movement or installs hooks.
-- Retains numeric copies in memory; writes after recording and only when gameplay permits.
local Fine={};Fine.__index=Fine
local function vec(v)
    assert(v,"Missing position")
    local r={};for _,k in ipairs({"x","y","z"}) do
        local n=v[k];assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid position")
        r[k]=n
    end;return r
end
local function add(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
local function sub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
local function copy(v)
    if type(v)~="table" then return v end
    local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
function Fine.new(env)
    return setmetatable({env=env,running=false,status="三秒精细探针：关闭",serial=0},Fine)
end
function Fine:clock() return self.env.clock and self.env.clock() or os.clock() end
function Fine:start()
    if self.running or self.pending then return false end
    local d=self.env.driver()
    local ok,b=pcall(function()
        assert(d and self.env.owned(d) and not self.env.paused(),"请先驾驶并关闭游戏暂停菜单")
        return self.env.bind(d)
    end)
    if not ok then self.status="三秒探针未开启："..tostring(b);return false end
    self.driver=d;self.refs=b;self.serial=self.serial+1
    self.session=os.date("!%Y%m%dT%H%M%SZ").."_"..math.floor(self:clock()*1000).."_"..self.serial
    self.started=self:clock();self.deadline=self.started+3
    self.frames={};self.current=nil;self.rows=0;self.errors={};self.error_count=0
    self.expected=nil;self.reason=nil;self.retry=nil
    self.instances={player=tostring(d.player),griffin=tostring(b.character)}
    self.before=self.env.diagnostics and copy(self.env.diagnostics()) or nil
    self.running=true;self.pending=false
    self.status="三秒精细探针：逐帧记录中；结束后保存"
    return true
end
function Fine:finish_frame(partial)
    if not self.current then return end
    self.current.partial=partial
    self.frames[#self.frames+1]=self.current;self.current=nil
end
function Fine:stop(reason)
    if not self.running then return end
    self:finish_frame("stopped")
    self.running=false;self.pending=true;self.reason=reason or "手动停止";self.ended=self:clock()
    self.driver=nil;self.refs=nil
    self.status="三秒精细探针：待保存"
end
function Fine:capture(stage)
    if not self.running then return end
    if self:clock()>=self.deadline then self:stop("3秒到时");return end
    if self.env.paused() then self:stop("游戏暂停");return end
    local d,b=self.env.driver(),self.refs
    local ok,owned=pcall(function()
        return d==self.driver and self.env.owned(d) and d.spawn.result.go==b.go
            and d.spawn.result.chara==b.character and b.character:call("get_Transform()")==b.transform
    end)
    if not ok or not owned then self:stop("驾驶或精确实例已变化");return end
    if #self.frames>=1000 or self.rows>=20000 then self:stop("采样上限");return end
    if not self.current then self.current={id=#self.frames+1,stages={}} end
    if #self.current.stages>=32 then self:stop("阶段上限");return end
    local started=self:clock()
    local r={stage=stage,sequence=self.rows+1,time=self.env.time(),clock=started,
        behavior_frame=self.env.behavior_frame and self.env.behavior_frame(),mode=d.anchor_mode,
        gear=d.gear,flight_mode=d.mode,errors={}}
    local function group(name,fn)
        if self.errors[name] then r.errors[name]=self.errors[name];return end
        local success,err=pcall(fn)
        if not success then
            self.errors[name]=tostring(err);r.errors[name]=tostring(err);self.error_count=self.error_count+1
        end
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
    group("griffin",function()
        r.griffin_scene=vec(b.transform:call("get_Position()"))
        r.griffin_universal=vec(b.transform:call("get_UniversalPosition()"))
        local q=b.transform:call("get_Rotation()")
        r.griffin_rotation=vec(q);r.griffin_rotation.w=q.w
    end)
    group("bones",function()
        for key,j in pairs({hip=d.hip_joint,root=d.root_joint,head=d.rider_head}) do
            if j:get_Valid() then
                local p=vec(j:call("get_Position()"));r[key.."_scene"]=p
                if origin then r[key.."_universal"]=add(p,origin) end
            end
        end
    end)
    group("targets",function()
        assert(b.tc:call("get_Owner()")==b.go and b.tc:call("get_Chara()")==b.character
            and b.ctrl:call("get_CachedCharacter()")==b.character,"Target ownership changed")
        r.character_target_scene=vec(b.tc:call("get_TargetPosition()"))
        r.flight_target_scene=vec(b.ctrl:call("get_TargetPosition()"))
    end)
    group("free_fall",function()
        local f=d.player:get_field("<FreeFallCtrl>k__BackingField")
        r.free_fall=f and {active=f:get_field("<IsActive>k__BackingField"),frame=f:get_field("Frame"),
            initial_frame_speed=vec(f:get_field("<InitialFrameSpeed>k__BackingField"))} or {available=false}
    end)
    r.planned_scene=d.anchor_target and vec(d.anchor_target)
    if stage=="player_transform_written" and origin and r.planned_scene then self.expected=add(r.planned_scene,origin) end
    r.expected_universal=self.expected and vec(self.expected)
    r.navigation=d.route_navigation and copy(d.route_navigation)
    if r.griffin_universal then
        for _,key in ipairs({"player","hip","root","head"}) do
            local p=r[key.."_universal"];if p then r[key.."_relative"]=sub(p,r.griffin_universal) end
        end
    end
    if self.env.timing then group("timing",function() r.timing=copy(self.env.timing()) end) end
    r.read_seconds=self:clock()-started
    self.rows=self.rows+1;self.current.stages[#self.current.stages+1]=r
    if stage=="render_native_after" then self:finish_frame() end
end
function Fine:tick(force)
    if self.running and self:clock()>=self.deadline then self:stop("3秒到时") end
    if self.running or not self.pending then return end
    if not force and self.env.can_dump and not self.env.can_dump() then
        self.status="三秒探针数据已保留；暂停游戏或结束驾驶后保存";return
    end
    if not force and self.retry and self:clock()<self.retry then return end
    local payload={version="0.3.0",session=self.session,instances=self.instances,frames=self.frames,
        summary={reason=self.reason,duration_seconds=self.ended-self.started,observed_frames=#self.frames,
            observed_stages=self.rows,baseline_hz="every_render_frame",read_errors=self.error_count,
            field_errors=copy(self.errors),writes_during_capture=0,beta_periodic_writes_deferred=true,
            save_policy="paused_or_not_driving",
            diagnostics_before=self.before,diagnostics_after=self.env.diagnostics and copy(self.env.diagnostics())}}
    local ok,result=pcall(self.env.dump,"GriffinJourneyReduxFine_"..self.session..".json",payload)
    if not ok or result==false then
        self.retry=self:clock()+2;self.status="三秒探针保存失败，数据保留待重试";return false
    end
    self.pending=false;self.retry=nil;self.frames={};self.before=nil
    self.status="三秒精细探针已保存："..self.reason.."；读取错误 "..self.error_count
    return true
end
function Fine:shutdown() self:stop("脚本重置");return self:tick(true) end
return Fine
