local FallStop=require("_GriffinRouteProbe.fall_stop")
local Anchor=require("_GriffinRouteProbe.anchor")
local Probe=require("_GriffinRouteProbe.probe")
local Fine=require("_GriffinRouteProbe.fine")
local Route={};Route.__index=Route
function Route.new(env)
    local self=setmetatable({env=env,anchor=Anchor.new(),status="稳定导航锚点：关闭"},Route)
    self.fall_stop=FallStop.new(env)
    self.griffin_stop=FallStop.new(env,"griffin")
    self.probe=Probe.new(env,self.anchor,self.fall_stop);self.fine=Fine.new(env);return self
end
function Route:after_passenger(d,a) self.fall_stop:after_passenger(d,a) end
function Route:forget_passenger(a) self.fall_stop:forget_passenger(a) end
function Route:after_behavior()
    local d=self.env.driver()
    if d then self.griffin_stop:after_anchor(d) end
end
function Route:center(d,tr,head,fx,fz)
    if not self.anchor.enabled then return head,{mode="head"} end
    local ok,center,detail=pcall(function()
        assert(self.env.owned(d),"Driver ownership changed")
        return self.anchor:resolve(d,tr,head,fx,fz)
    end)
    if ok then return center,detail end
    self.anchor:set_enabled(false);self.status="稳定锚点已停用："..tostring(center)
    return head,{mode="head",error=tostring(center)}
end
function Route:capture(stage)
    self:capture_fine(stage)
    local ok,err=pcall(self.probe.capture,self.probe,stage)
    if not ok then self.probe:stop("读取异常");self.probe.status="玩家探针已停止："..tostring(err) end
end
function Route:capture_fine(stage)
    local ok,err=pcall(self.fine.capture,self.fine,stage)
    if not ok then self.fine:stop("读取异常");self.fine.status="三秒探针已停止："..tostring(err) end
end
function Route:quiet() return self.fine.running end
function Route:after_anchor(d)
    if self.fall_stop:after_anchor(d) and (self.probe.running or self.fine.running) then self:capture("player_free_fall_stop_after") end
end
function Route:draw()
    if type(imgui.checkbox)~="function" then return end
    local changed,value=imgui.checkbox("【原路线实验】稳定导航锚点（根Transform固定偏移）",self.anchor.enabled)
    if changed then
        self.anchor:set_enabled(value)
        self.status=value and "稳定锚点：开启，下次行为更新校准；不改座位和镜头" or "稳定导航锚点：关闭，使用原头部导航"
    end
    changed,value=imgui.checkbox("【原路线探针】记录玩家抖动与位置改写（60秒）",self.probe.running)
    if changed then
        if value and (self.fine.running or self.fine.pending) then self.probe.status="请等三秒探针保存完成"
        elseif value then self.probe:start() else self.probe:stop("手动停止") end
    end
    changed,value=imgui.checkbox("【原路线探针】三秒逐帧精细记录（暂停后保存）",self.fine.running)
    if changed then
        if value and (self.probe.running or self.probe.pending or #self.probe.queue>0) then self.fine.status="请先停止60秒探针并等保存完成"
        elseif value then self.fine:start() else self.fine:stop("手动停止") end
    end
    changed,value=imgui.checkbox("【原路线防抖】玩家和座位NPC停止原生自由落体",self.fall_stop.enabled)
    if changed then self.fall_stop:set_enabled(value) end
    imgui.text(self.fall_stop.status)
    if self.fall_stop.enabled then
        imgui.text("已阻止重新落体：玩家 "..self.fall_stop.start_calls.." 次；座位NPC "..self.fall_stop.passenger_start_calls.." 次")
        imgui.text("座位NPC已停止 "..self.fall_stop.passenger_calls.." 次；异常 "..self.fall_stop.passenger_errors.." 次")
        if self.fall_stop.passenger_last and self.fall_stop.passenger_last.error then imgui.text(self.fall_stop.passenger_last.error) end
    end
    changed,value=imgui.checkbox("【原路线防抖】狮鹫停止原生自由落体",self.griffin_stop.enabled)
    if changed then self.griffin_stop:set_enabled(value) end
    imgui.text(self.griffin_stop.status)
    if self.griffin_stop.enabled then imgui.text("已阻止狮鹫重新落体 "..self.griffin_stop.start_calls.." 次") end
    imgui.text(self.status);imgui.text(self.probe.status);imgui.text(self.fine.status)
end
function Route:stop()
    self.fall_stop:release_driver();self.griffin_stop:release_driver();self.probe:stop("结束驾驶");self.fine:stop("结束驾驶");self.anchor:set_enabled(false);self.status="稳定导航锚点：关闭"
end
function Route:tick() self.fine:tick();if not self:quiet() then self.probe:tick() end;self.fall_stop:tick();self.griffin_stop:tick() end
function Route:shutdown() self.fall_stop:set_enabled(false,"脚本结束");self.griffin_stop:set_enabled(false,"脚本结束");self:stop();self.fine:shutdown();self.probe:shutdown() end
return Route
