-- Stop native free fall only for an explicitly owned driving/seat instance.
-- Disabling stops further calls; it does not reconstruct a cancelled fall trajectory.
local M={};M.__index=M
function M.new(env,scope)
    local label=scope=="griffin" and "狮鹫" or "玩家／座位NPC"
    return setmetatable({env=env,scope=scope or "riders",label=label,enabled=false,calls=0,attempts=0,errors=0,
        passenger_states={},passenger_calls=0,passenger_attempts=0,passenger_errors=0,
        status="停止"..label.."自由落体：关闭"},M)
end
function M:conflict()
    local check=self.scope=="griffin" and self.env.griffin_conflict or self.env.fall_conflict
    return check and check() or false
end
function M:set_enabled(value,reason)
    if not value then
        self.enabled=false;self.driver=nil;self.character=nil;self.go=nil;self.passenger_states={}
        self.status="停止"..self.label.."自由落体："..(reason or "关闭")
        return
    end
    local ok,err=pcall(function()
        assert(not self:conflict(),"请关闭对应的旧跌落实验")
        local td=assert(sdk.find_type_definition("app.FreeFallController"),"缺少FreeFallController")
        local method=assert(td:get_method("stop()"),"缺少FreeFallController.stop")
        assert(not method:is_static() and method:get_num_params()==0
            and method:get_return_type():get_full_name()=="System.Void","FreeFallController.stop签名变化")
    end)
    if not ok then self:set_enabled(false,"未开启："..tostring(err));return end
    self.driver=nil;self.enabled=true;self.calls=0;self.attempts=0;self.errors=0;self.last=nil
    self.character=nil;self.go=nil;self.passenger_states={}
    self.passenger_calls=0;self.passenger_attempts=0;self.passenger_errors=0;self.passenger_last=nil
    self.status="停止"..self.label.."自由落体：开启，驾驶时生效（无需探针）"
end
function M:release_driver()
    self.driver=nil;self.character=nil;self.go=nil;self.passenger_states={}
    if self.enabled then self.status="停止"..self.label.."自由落体：开启，等待驾驶（无需探针）" end
end
function M:check_driver(d)
    assert(d and (not self.driver or d==self.driver) and self.env.driver()==d and self.env.owned(d),"精确玩家或驾驶归属变化")
    assert(not self:conflict(),"旧跌落实验与防抖冲突")
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
local function stop_native(character,verify,now,attempt)
    assert(verify(),"角色归属变化")
    local obj=assert(character:get_field("<FreeFallCtrl>k__BackingField"),"角色自由落体控制器不可用")
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
        if self.scope=="griffin" then
            local ch,go=self.env.griffin(d)
            assert(ch and go and (not self.character or self.character==ch and self.go==go),"精确狮鹫实例变化")
            self.character=ch;self.go=go;character=ch
            verify=function() self:check_driver(d);return self.env.griffin_owned(d,ch,go) end
        end
        local did=stop_native(character,verify,self.env.time,function(last) self.last=last;self.attempts=self.attempts+1 end)
        if not did then return false end
        self.calls=self.calls+1
        self.status="停止"..self.label.."自由落体：已停止 "..self.calls.." 次"..(self.scope=="griffin" and "" or "（玩家）")
        return true
    end)
    if not ok then
        self.errors=self.errors+1;self:set_enabled(false,"异常停用："..tostring(did));return false
    end
    return did
end
function M:forget_passenger(a) self.passenger_states[a]=nil end
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
        end)
    end)
    if not ok then
        self.passenger_states[a]=true;self.passenger_errors=self.passenger_errors+1
        self.passenger_last={time=self.env.time(),group=a.group,slot=a.slot,error=tostring(did)}
        return false
    end
    if did then self.passenger_calls=self.passenger_calls+1 end
    return did
end
function M:snapshot()
    local last
    if self.last then last={};for k,v in pairs(self.last) do last[k]=v end end
    local passenger_last
    if self.passenger_last then passenger_last={};for k,v in pairs(self.passenger_last) do passenger_last[k]=v end end
    return {enabled=self.enabled,calls=self.calls,attempts=self.attempts,errors=self.errors,last=last,status=self.status,
        passenger_calls=self.passenger_calls,passenger_attempts=self.passenger_attempts,passenger_errors=self.passenger_errors,passenger_last=passenger_last}
end
return M
