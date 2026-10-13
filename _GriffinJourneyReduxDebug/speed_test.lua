-- Scoped instance-vector A/B test; shared speed-rate getter is observed only.
return function(ctx)
local _ENV=ctx
local test={status="原生位移向量对照：未运行",installed={},factor=0.8,scopes={},pending=state.native_speed_repair}
local scope_key="griffin_native_speed_scope"
local getter_key="griffin_native_speed_getter"
local function valid(r)
    return alive and test.run==r and active==r.driver and state.generation==generation
        and r.driver.gear==2 and r.driver.controls_active and not r.driver.external_control
        and not menu.gameplay_paused() and owned_player(r.driver,true)
        and r.driver.spawn.result.chara==r.character
end
local function storage()
    local ok,s=pcall(thread.get_hook_storage)
    return ok and type(s)=="table" and s or nil
end
local function thread_id()
    local ok,id=pcall(thread.get_id)
    return ok and (type(id)=="number" or type(id)=="string") and id or nil
end
local function same(a,b)
    return a and b and finite(a.x) and finite(a.y) and finite(a.z)
        and math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)<0.00001
end
local function restore(r)
    local p=r.patch;if not p then return end
    if not r.character:get_Valid() or not r.driver.spawn.result.go:get_Valid() then r.patch=nil;return end
    local ch=r.character
    assert(r.driver.spawn.result.chara==ch and ch:call("get_GameObject()")==r.driver.spawn.result.go
        and ch:call("get_FlightCtrl()")==r.controller
        and r.controller:call("get_CachedCharacter()")==ch,"Speed repair binding changed")
    local current=r.controller:get_field("FlightMoveVector")
    if same(current,p.applied) then
        r.controller:set_field("FlightMoveVector",Vector3f.new(p.original.x,p.original.y,p.original.z))
    end -- A changed native value belongs to the engine; never overwrite it with our old snapshot.
    r.patch=nil
end
function test:repair()
    local r=self.pending;if not r then return true end
    local ok,err=pcall(restore,r)
    if ok then self.pending=nil;state.native_speed_repair=nil;return true end
    self.status="位移向量恢复待重试："..tostring(err);return false
end
local function signature(type_name,name,returns)
    local td=assert(sdk.find_type_definition(type_name),"Type unavailable: "..type_name)
    local m=assert(td:get_method(name),"Method unavailable: "..name)
    assert(not m:is_static() and m:get_num_params()==0 and m:get_return_type():get_full_name()==returns,
        "Unexpected native signature: "..name)
    return m
end
function test:install()
    for _,name in ipairs({"update()","lateUpdate()","updatePosition()"}) do
        if not self.installed[name] then
            local m=signature("app.FlightControl",name,"System.Void")
            sdk.hook(m,function(args)
                local r=self.run
                if not r or not alive then return end
                r.entries[name]=(r.entries[name] or 0)+1
                local s,id=storage(),thread_id();if not s or not id then r.context_misses=r.context_misses+1;return end
                local node={parent=self.scopes[id],run=r,method=name,thread=id}
                s[scope_key]=node;self.scopes[id]=node
                -- Hook storage is per call; cross-hook scopes must also be per native thread.
                local ok,err=pcall(function()
                    local fc=sdk.to_managed_object(args[2])
                    if fc==r.controller and valid(r) and fc:call("get_CachedCharacter()")==r.character then
                        r.owned_entries[name]=(r.owned_entries[name] or 0)+1
                        node.parameter=fc:get_field("StatusParameter")
                        if name=="updatePosition()" then
                            local value=vector(fc:get_field("FlightMoveVector"))
                            r.last_vector=value
                            if r.phase=="B" and not r.patch then
                                local applied={x=value.x*self.factor,y=value.y*self.factor,z=value.z*self.factor}
                                if math.abs(value.x)+math.abs(value.y)+math.abs(value.z)>0.000001 then
                                    r.patch={original=value,applied=applied};node.patch=r.patch
                                    fc:set_field("FlightMoveVector",Vector3f.new(applied.x,applied.y,applied.z))
                                    r.bhits=r.bhits+1
                                end
                            end
                        end
                    end
                end)
                if not ok then
                    r.last_error=tostring(err)
                    node.parameter=nil
                    if r.patch then self:stop("实例向量写入异常，已停止") end
                end
            end,function(ret)
                if not self.run then return ret end
                if not alive then self:stop("脚本已停止");return ret end
                local s=storage();local node=s and s[scope_key]
                if node and node.method==name then
                    if node.patch and self.run and self.run.patch==node.patch then
                        local ok=pcall(restore,self.run)
                        if not ok then self:stop("实例向量恢复异常，已停止") end
                    end
                    if self.scopes[node.thread]==node then self.scopes[node.thread]=node.parent
                    else self.scopes[node.thread]=nil end
                else
                    local id=thread_id();if id then self.scopes[id]=nil end
                    if self.run and self.run.patch then self:stop("回调上下文失效，已取消") end
                end
                return ret
            end)
            self.installed[name]=true
        end
    end
    if not self.installed.getter then
        local m=signature("app.FlightControlStatusParameter","get_FlySpeedRate()","System.Single")
        sdk.hook(m,function(args)
            local r=self.run
            if not r or not alive then return end
            r.getter_entries=r.getter_entries+1
            local s,id=storage(),thread_id();if not s or not id then r.context_misses=r.context_misses+1;return end
            local node={run=r};s[getter_key]=node
            local scope=self.scopes[id]
            local ok=pcall(function()
                if scope and scope.run==r and scope.parameter==sdk.to_managed_object(args[2]) then node.scope=scope end
            end)
            if not ok then node.scope=nil end
        end,function(ret)
            local r=self.run
            if not r or not alive then return ret end
            local s=storage();local node=s and s[getter_key]
            if not node then return ret end
            local ok,value=pcall(function()
                if node.run~=r or not node.scope or not valid(r) then return ret end
                local number=sdk.to_float(ret)
                if not finite(number) or number<=0 then return ret end
                r.hits=r.hits+1
                return ret -- The failed 037 getter route is diagnostic-only now.
            end)
            return ok and value or ret
        end)
        self.installed.getter=true
    end
end
function test:stop(reason)
    if not self.run then self:repair();return end
    local r=self.run;self.run=nil;self.scopes={}
    if r.patch then self.pending=r;state.native_speed_repair=r end
    self.status="原生位移向量对照："..(reason or "已停止").."；临时修改已结束"
    self:repair()
end
function test:start()
    if self.run or not self:repair() then return end
    local d=active
    if not d or d.gear~=2 or not d.sprint_speed or not d.sprint_speed.ready then
        self.status="请先稳定2档平飞约2秒，再开始倍率对照。";return
    end
    local ok,err=pcall(function()
        local ch=validate_spawn(d.spawn)
        local fc=assert(ch:call("get_FlightCtrl()"),"FlightControl unavailable")
        assert(fc:call("get_CachedCharacter()")==ch,"FlightControl ownership changed")
        assert(fc:get_field("StatusParameter"),"Flight status parameter unavailable")
        self:install()
        self.scopes={};self.result=nil;self.verified=false
        self.run={driver=d,character=ch,controller=fc,phase="A",started=now(),hits=0,bhits=0,getter_entries=0,context_misses=0,entries={},owned_entries={},stats={}}
        assert(valid(self.run),"Driver unavailable")
        self.status="倍率对照 A：原速采样中；保持平飞，勿转向／升降。"
    end)
    if not ok then self.run=nil;self.status="倍率对照未启动："..tostring(err) end
end
local durations={A=1.5,B=2.5,R=1.5}
local settling={A=0.3,B=0.6,R=0.6}
local function mean(s) return s and s.time>0 and s.sum/s.time or nil end
function test:finish(r)
    if r.patch then self:stop("位移调用尚未结束，已取消");return end
    local a,b,c=mean(r.stats.A),mean(r.stats.B),mean(r.stats.R)
    self.run=nil;self.scopes={};self.verified=false
    if not a or not b or not c or a<=0 then self.status="倍率对照：有效样本不足；临时修改已结束";return end
    local ratio,recovery=b/a,c/a
    self.verified=r.bhits>0 and ratio>=0.72 and ratio<=0.88 and recovery>=0.92 and recovery<=1.08
        and r.stats.A.max/r.stats.A.min<1.08
    local verdict=self.verified and "已观察到降速及恢复" or (r.bhits==0 and "未命中实例向量写入位置" or "未证实按倍率调速")
    self.result={baseline=a,reduced=b,recovery=c,ratio=ratio,hits=r.bhits,verified=self.verified,entries=r.entries,owned_entries=r.owned_entries,getter_entries=r.getter_entries,scoped_getter=r.hits,last_vector=r.last_vector,context_misses=r.context_misses,last_error=r.last_error}
    self.status=string.format("水平速度对照：A %.2f → 0.8倍 %.2f → 恢复 %.2f 米／秒；命中 %d；%s",a,b,c,r.bhits,verdict)
end
function test:tick()
    if not self:repair() then return end
    local r=self.run;if not r then return end
    local ok,err=pcall(function()
        if not valid(r) then self:stop("驾驶／档位／暂停变化，已取消");return end
        local ch=validate_spawn(r.driver.spawn)
        if ch~=r.character or ch:call("get_FlightCtrl()")~=r.controller then self:stop("实例或控制器变化，已取消");return end
        local speed=r.driver.sprint_speed
        if not speed or not speed.ready or now()-speed.time>0.15 then self:stop("速度样本失效，已取消");return end
        if not finite(speed.horizontal) or speed.horizontal<1
            or math.abs(speed.vertical)>math.max(1,speed.horizontal*0.2) or math.abs(input.x)>0.15
            or held(input.buttons,masks.rb) or held(input.buttons,masks.lb) then
            self:stop("检测到转向／升降，已取消");return
        end
        if r.last_time==speed.time then return end
        local dt=r.last_time and math.max(0,math.min(0.25,speed.time-r.last_time)) or 0
        r.last_time=speed.time
        local elapsed=now()-r.started
        if elapsed>=settling[r.phase] and dt>0 then
            local s=r.stats[r.phase] or {sum=0,time=0,min=math.huge,max=0};r.stats[r.phase]=s
            s.sum=s.sum+speed.horizontal*dt;s.time=s.time+dt;s.min=math.min(s.min,speed.horizontal);s.max=math.max(s.max,speed.horizontal)
        end
        if elapsed>=durations[r.phase] then
            if r.phase=="A" then r.phase="B";r.started=now();self.status="倍率对照 B：临时缩小当前实例位移向量为0.8倍，自动恢复；保持平飞。"
            elseif r.phase=="B" then r.phase="R";r.started=now();self.status="倍率对照：已恢复原倍率，采样恢复速度。"
            else self:finish(r) end
        end
    end)
    if not ok then self:stop("测试异常："..tostring(err)) end
end
return test
end
