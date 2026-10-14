-- Stop current free fall and prevent new trajectories for precisely owned instances.
-- Native hooks stay installed; disabled/released/invalid actors always pass through.
local M={};M.__index=M
local start_signatures={
    {"start(app.FreeFallController.StartParameter)",1},
    {"start(via.vec3, via.vec3, System.Single, System.Single)",4},
    {"start(via.vec3, via.vec3, System.Single, System.Single, app.FreeFallController.StartParameter.ParabolicTypeEnum, System.Single)",6},
    {"startWithFrame(System.Single, via.vec3, System.Single)",3},
    {"startWithFrame(via.vec3, System.Single)",2},
    {"startWithFrameKeepGravityAccel(via.vec3)",1},
    {"startWithSec(System.Single, via.vec3, System.Single)",3},
    {"startWithSec(via.vec3, System.Single)",2},
}
local installed,managers={},setmetatable({},{__mode="k"})
local function install_hooks(td)
    assert(sdk.hook and sdk.to_ptr and sdk.PreHookResult and sdk.PreHookResult.SKIP_ORIGINAL,"缺少落体启动拦截接口")
    local entries,groups={},{}
    -- Validate every overload before installing anything. Shared native entries get one hook.
    for _,sig in ipairs(start_signatures) do
        local method=assert(td:get_method(sig[1]),"缺少"..sig[1])
        assert(not method:is_static() and method:get_num_params()==sig[2]
            and method:get_return_type():get_full_name()=="System.Void","落体启动签名变化："..sig[1])
        local address=assert(method:get_function(),"落体启动原生入口不可用："..sig[1])
        assert(address~=0,"落体启动原生入口为空："..sig[1])
        local entry=groups[address]
        if entry then entry.label=entry.label.." | "..sig[1]
        else entry={address=address,method=method,label=sig[1]};groups[address]=entry;entries[#entries+1]=entry end
    end
    for _,entry in ipairs(entries) do
        if not installed[entry.address] then
            local label=entry.label
            sdk.hook(entry.method,function(args)
                for manager in pairs(managers) do
                    if manager:before_start(args[2],label) then return sdk.PreHookResult.SKIP_ORIGINAL end
                end
            end,function(retval) return retval end)
            installed[entry.address]=true
        end
    end
    return #entries
end
function M.new(env)
    local label=env.label or "玩家／座位NPC"
    return setmetatable({env=env,scope=env.group or "riders",label=label,enabled=false,calls=0,attempts=0,errors=0,
        bindings={},start_calls=0,start_counts={},passenger_start_calls=0,
        passenger_states={},passenger_calls=0,passenger_attempts=0,passenger_errors=0,
        status="停止"..label.."自由落体：关闭"},M)
end
function M:set_enabled(value,reason)
    if not value then
        self.enabled=false;self.driver=nil;self.character=nil;self.go=nil;self.passenger_states={};self.bindings={}
        self.status="停止"..self.label.."自由落体："..(reason or "关闭")
        return
    end
    local ok,err=pcall(function()
        local td=assert(sdk.find_type_definition("app.FreeFallController"),"缺少FreeFallController")
        local method=assert(td:get_method("stop()"),"缺少FreeFallController.stop")
        assert(not method:is_static() and method:get_num_params()==0
            and method:get_return_type():get_full_name()=="System.Void","FreeFallController.stop签名变化")
        self.hook_entries=install_hooks(td)
    end)
    if not ok then self:set_enabled(false,"未开启："..tostring(err));return end
    self.driver=nil;self.enabled=true;self.calls=0;self.attempts=0;self.errors=0;self.last=nil
    self.character=nil;self.go=nil;self.passenger_states={};self.bindings={}
    self.start_calls=0;self.passenger_start_calls=0;self.start_counts={};self.start_last=nil;managers[self]=true
    self.passenger_calls=0;self.passenger_attempts=0;self.passenger_errors=0;self.passenger_last=nil
    self.status="停止"..self.label.."自由落体：开启，驾驶时生效（无需探针）"
end
function M:release_driver()
    self.driver=nil;self.character=nil;self.go=nil;self.passenger_states={};self.bindings={}
    if self.enabled then self.status="停止"..self.label.."自由落体：开启，等待驾驶（无需探针）" end
end
function M:bind_controller(actor,character,obj,verify,is_passenger)
    assert(verify() and character:get_field("<FreeFallCtrl>k__BackingField")==obj,"落体启动拦截归属变化")
    local pointer=sdk.to_ptr(obj:get_address())
    assert(pointer,"落体控制器指针不可用")
    self.bindings[actor]={actor=actor,character=character,obj=obj,pointer=pointer,verify=verify,passenger=is_passenger}
end
function M:before_start(pointer,label)
    if not self.enabled then return false end
    local binding,key
    for actor,b in pairs(self.bindings) do if pointer==b.pointer then binding=b;key=actor;break end end
    if not binding then return false end
    local ok,valid=pcall(function()
        if self.env.paused() then return false end
        return binding.verify() and binding.character:get_field("<FreeFallCtrl>k__BackingField")==binding.obj
    end)
    if not ok then
        if binding.passenger then
            self.bindings[key]=nil;self.passenger_states[key]=true;self.passenger_errors=self.passenger_errors+1
            self.passenger_last={group=key.group,slot=key.slot,error=tostring(valid)}
        else self.errors=self.errors+1;self:set_enabled(false,"启动拦截异常停用："..tostring(valid)) end
        return false
    end
    if not valid then return false end
    if binding.passenger then self.passenger_start_calls=self.passenger_start_calls+1
    else self.start_calls=self.start_calls+1 end
    local group=binding.passenger and (key.group..":"..key.slot) or self.env.group or "player"
    local count_key=group..":"..label
    self.start_counts[count_key]=(self.start_counts[count_key] or 0)+1
    self.start_last={group=group,entry=label}
    return true
end
function M:check_driver(d)
    assert(d and (not self.driver or d==self.driver) and self.env.driver()==d and self.env.owned(d),"精确玩家或驾驶归属变化")
end
function M:tick()
    if not self.enabled then return end
    local ok,err=pcall(function()
        if self.env.paused() then return end
        local current=self.env.driver()
        if not current then self:release_driver();return end
        self:check_driver(current)
    end)
    if not ok then self.errors=self.errors+1;self:set_enabled(false,"异常停用："..tostring(err)) end
end
local function stop_native(character,verify,now,attempt,bind)
    assert(verify(),"角色归属变化")
    local obj=assert(character:get_field("<FreeFallCtrl>k__BackingField"),"角色自由落体控制器不可用")
    bind(obj)
    local before=obj:get_field("<IsActive>k__BackingField")
    assert(type(before)=="boolean","无法读取自由落体激活状态")
    if not before then return false end
    assert(verify() and character:get_field("<FreeFallCtrl>k__BackingField")==obj,"落体控制器归属变化")
    local last={time=now(),active_before=before,
        frame_before=obj:get_field("Frame"),process_id=obj:get_field("<ProcessID>k__BackingField")}
    attempt(last)
    obj:call("stop()")
    last.active_after=obj:get_field("<IsActive>k__BackingField")
    assert(last.active_after==false,"FreeFallController.stop读回未停止")
    return true
end
function M:after_anchor(d)
    if not self.enabled then return false end
    local ok,did=pcall(function()
        if self.env.paused() then return false end
        self:check_driver(d)
        self.driver=d
        local character=d.player
        local function verify() self:check_driver(d);return true end
        if self.env.resolve_actor then
            character,verify=self.env.resolve_actor(d)
        end
        local did=stop_native(character,verify,self.env.time,function(last) self.last=last;self.attempts=self.attempts+1 end,
            function(obj) self:bind_controller(d,character,obj,verify,false) end)
        if not did then return false end
        self.calls=self.calls+1
        self.status="停止"..self.label.."自由落体：已停止 "..self.calls.." 次"
        return true
    end)
    if not ok then
        self.errors=self.errors+1;self:set_enabled(false,"异常停用："..tostring(did));return false
    end
    return did
end
function M:forget_passenger(a) self.passenger_states[a]=nil;self.bindings[a]=nil end
function M:after_passenger(d,a)
    if not self.enabled or self.scope~="riders" or not a or self.passenger_states[a] then return false end
    local ok,did=pcall(function()
        if self.env.paused() then return false end
        self:check_driver(d)
        local function verify()
            self:check_driver(d)
            return a~=d and self.env.passenger_owned(d,a)
        end
        return stop_native(a.player,verify,self.env.time,function(last)
            last.group=a.group;last.slot=a.slot;self.passenger_last=last;self.passenger_attempts=self.passenger_attempts+1
        end,function(obj) self:bind_controller(a,a.player,obj,verify,true) end)
    end)
    if not ok then
        self.bindings[a]=nil;self.passenger_states[a]=true;self.passenger_errors=self.passenger_errors+1
        self.passenger_last={time=self.env.time(),group=a.group,slot=a.slot,error=tostring(did)}
        return false
    end
    if did then self.passenger_calls=self.passenger_calls+1 end
    return did
end
return M
