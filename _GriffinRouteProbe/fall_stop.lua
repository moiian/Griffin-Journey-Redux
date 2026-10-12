-- Opt-in intervention: stop only the current driver's native FreeFallController.
-- Disabling stops further calls; it does not reconstruct a cancelled fall trajectory.
local M={};M.__index=M
function M.new(env)
    return setmetatable({env=env,enabled=false,calls=0,attempts=0,errors=0,
        status="停止玩家自由落体：关闭"},M)
end
function M:set_enabled(value,reason)
    if not value then
        self.enabled=false;self.driver=nil
        self.status=reason and ("停止玩家自由落体："..reason) or "停止玩家自由落体：关闭"
        return
    end
    local ok,err=pcall(function()
        assert(not self.env.fall_conflict or not self.env.fall_conflict(),"请关闭跌落实验1、2、3，保持单变量")
        local td=assert(sdk.find_type_definition("app.FreeFallController"),"缺少FreeFallController")
        local method=assert(td:get_method("stop()"),"缺少FreeFallController.stop")
        assert(not method:is_static() and method:get_num_params()==0
            and method:get_return_type():get_full_name()=="System.Void","FreeFallController.stop签名变化")
    end)
    if not ok then self.enabled=false;self.driver=nil;self.status="停止玩家自由落体未开启："..tostring(err);return end
    self.driver=nil;self.enabled=true;self.calls=0;self.attempts=0;self.errors=0;self.last=nil
    self.status="停止玩家自由落体：开启，驾驶时生效（无需探针）"
end
function M:release_driver()
    self.driver=nil
    if self.enabled then self.status="停止玩家自由落体：开启，等待驾驶（无需探针）" end
end
function M:tick()
    if not self.enabled then return end
    local ok,err=pcall(function()
        if self.env.paused() then return end
        local current=self.env.driver()
        if not current then self:release_driver();return end
        assert((not self.driver or self.driver==current) and self.env.owned(current),"精确玩家或驾驶归属变化")
        assert(not self.env.fall_conflict or not self.env.fall_conflict(),"跌落实验1、2、3与防抖冲突")
    end)
    if not ok then self.errors=self.errors+1;self:set_enabled(false,"异常停用："..tostring(err)) end
end
function M:after_anchor(d)
    if not self.enabled then return false end
    local ok,did=pcall(function()
        if self.env.paused() then return false end
        assert(d and (not self.driver or d==self.driver) and self.env.driver()==d and self.env.owned(d),"精确玩家或驾驶归属变化")
        assert(not self.env.fall_conflict or not self.env.fall_conflict(),"跌落实验1、2、3与防抖冲突")
        self.driver=d
        local obj=assert(d.player:get_field("<FreeFallCtrl>k__BackingField"),"玩家自由落体控制器不可用")
        local before=obj:get_field("<IsActive>k__BackingField")
        assert(type(before)=="boolean","无法读取自由落体激活状态")
        if not before then return false end
        assert(self.env.owned(d) and d.player:get_field("<FreeFallCtrl>k__BackingField")==obj,"落体控制器归属变化")
        self.last={time=self.env.time(),active_before=before,
            frame_before=obj:get_field("Frame"),process_id=obj:get_field("<ProcessID>k__BackingField")}
        self.attempts=self.attempts+1
        obj:call("stop()")
        local after=obj:get_field("<IsActive>k__BackingField")
        self.last.active_after=after
        assert(after==false,"FreeFallController.stop读回未停止")
        self.calls=self.calls+1
        self.status="停止玩家自由落体：已停止 "..self.calls.." 次（仅当前玩家）"
        return true
    end)
    if not ok then
        self.errors=self.errors+1;self:set_enabled(false,"异常停用："..tostring(did));return false
    end
    return did
end
function M:snapshot()
    local last
    if self.last then last={};for k,v in pairs(self.last) do last[k]=v end end
    return {enabled=self.enabled,calls=self.calls,attempts=self.attempts,errors=self.errors,last=last,status=self.status}
end
return M
