local Isolation=require("_GriffinAnimationLab.isolation")
local Recorder=require("_GriffinAnimationLab.recorder")
local CallTrace=require("_GriffinAnimationLab.call_trace")
local ActionRefresh=require("_GriffinAnimationLab.action_refresh")
local IsolationAB=require("_GriffinAnimationLab.isolation_ab")
local M={}
function M.new()
    local self={bound=false,enabled=false,flap=false,record=false,trace_calls=false,refresh_action=false,ab_test=false,revision=0,alive=true,
        status="全部关闭。先用Beta生成狮鹫并结束驾驶；停止旧工具的隔离播放。",
        isolation=Isolation.new(),recorder=Recorder.new()}
    self.call_trace=CallTrace.new(self.recorder)
    self.refresh=ActionRefresh.new()
    self.ab=IsolationAB.new()
    function self:changed()
        self.revision=self.revision+1
    end
    function self:apply()
        local polling=self.refresh.wait and self.enabled and self.bound and self.applied==self.revision
        if not polling then self.recorder:event("应用前",self,"before_apply") end
        if not self.enabled or not self.bound then
            self.refresh:cancel(self,"刷新取消，恢复原生控制")
            self.ab:cancel()
            self.isolation:stop()
        end
        if not self.bound then self.enabled=false;self.instance=nil;self.status="未绑定；测试关闭。";return end
        local bridge=assert(rawget(_G,"GriffinFlightBetaBridge"),"需要Beta生成的当前实例")
        assert(not bridge.is_driving(),"请先结束Beta驾驶")
        local old=rawget(_G,"GriffinMountExperimentControl")
        assert(not (old and old.is_driving()),"请先结束旧实验工具驾驶")
        local r=assert(bridge.get_instance(),"Beta当前没有有效狮鹫")
        assert(r.go:get_Valid() and r.chara:get_Valid(),"狮鹫无效")
        if self.instance and self.instance~=r then
            self.isolation:stop();self.instance=nil;self.bound=false;self.enabled=false
            error("Beta实例变化，请重新勾选绑定")
        end
        self.instance=r
        if self.enabled then
            if self.ab.active then self.ab:advance(self)
            elseif not self.isolation.active and self.ab_test then self.ab:begin(self,r)
            elseif self.refresh.wait then self.refresh:advance(self)
            else
                local first=not self.isolation.active
                self.isolation:play(r,self.flap and 5101 or 5100)
                if first and self.refresh_action then self.refresh:begin(self,self.isolation.active) end
            end
            self.status=self.ab.active and self.ab:status() or self.refresh.wait and self.refresh.status
                or "隔离播放："..(self.flap and "挥翅5101" or "滑翔5100").."；未锁定位置。"
        else self.status="已绑定；隔离播放关闭，原生控制生效。" end
        if not polling then self.recorder:event(self.status,self,"after_apply") end
    end
    function self:tick()
        if not self.alive then return end
        local core=rawget(_G,"NickCore")
        if not core or not core.properties or type(rawget(_G,"run_once"))~="function" then
            self.status="等待NickCore与run_once。";return
        end
        self.recorder.enabled=self.record
        self.call_trace:tick(self)
        if core.properties.isPaused then self.refresh:pause();return end
        if self.ab.active and not self.record and self.enabled then self.enabled=false;self:changed() end
        if self.isolation.active and self.applied==self.revision then
            local b=rawget(_G,"GriffinFlightBetaBridge")
            local old=rawget(_G,"GriffinMountExperimentControl")
            local ok,valid=pcall(function()
                if self.ab.active then self.ab:validate(self) end
                return b and b.get_instance()==self.instance and not b.is_driving()
                    and not (old and old.is_driving()) and self.isolation:valid(self.isolation.active)
            end)
            if not ok or not valid then self.bound=false;self.enabled=false;self:changed() end
        end
        if not self.pending and (self.applied~=self.revision or self.refresh.wait) then
            self.pending=true
            local rev=self.revision
            run_once(function()
                self.pending=false
                if not self.alive or rev~=self.revision then return end
                if core.properties.isPaused then self.refresh:pause();return end
                local ok,err=pcall(function() self:apply() end)
                self.applied=rev
                if not ok then
                    self.enabled=false
                    self.ab:cancel()
                    self.refresh:cancel(self,tostring(err),true)
                    local restored,restore_err=pcall(function() self.isolation:stop() end)
                    self.status=tostring(err)..(restored and "" or "；恢复失败："..tostring(restore_err))
                    self.recorder:event(self.status,self,"apply_error")
                end
            end)
        end
        self.recorder:tick(self)
    end
    function self:draw()
        if not imgui.tree_node("狮鹫动画实验室 0.1.6") then return end
        imgui.text("A/B分步对照保持同一轮隔离；关闭隔离恢复原生控制。")
        local changed,value=imgui.checkbox("绑定Beta当前狮鹫",self.bound)
        if changed then self.bound=value;if not value then self.enabled=false end;self:changed() end
        changed,value=imgui.checkbox("启用隔离播放",self.enabled)
        if changed then self.enabled=value;self:changed() end
        changed,value=imgui.checkbox("使用挥翅5101（关闭为滑翔5100）",self.flap)
        if changed then self.flap=value;self:changed() end
        changed,value=imgui.checkbox("分步对照：先只隔离控制，不换动画（下次开启生效）",self.ab_test)
        if changed then
            self.ab_test=value
            self.recorder:event(value and "A/B对照已开启，下次接管生效" or "A/B对照已关闭，下次接管生效")
        end
        imgui.text("需状态记录、关闭悬停刷新；先准备原生空中HoverWait。A/B内挥翅选项不生效。")
        if self.ab.active and self.ab.active.ab_stage=="A" then
            if imgui.button("进入B：只换基础层5100（保持隔离）") then self.ab:request_motion(self) end
        end
        if self.ab.active then imgui.text(self.ab:status()) end
        changed,value=imgui.checkbox("接管时刷新旧指令（悬停后重新隔离，实验）",self.refresh_action)
        if changed then
            self.refresh_action=value
            self.recorder:event(value and "悬停刷新已开启，下次接管执行" or "悬停刷新已关闭，下次接管生效")
        end
        imgui.text("需状态记录；分帧请求、放行，原生动作与坐标稳定后复隔离。")
        changed,value=imgui.checkbox("启用状态与坐标记录（20Hz，隔离关闭也记录）",self.record)
        if changed then
            self.record=value;self.recorder.enabled=value
            if value then self.recorder:event("开始记录") else self.recorder:flush() end
        end
        changed,value=imgui.checkbox("记录原生方法前后坐标（需开启状态记录）",self.trace_calls)
        if changed then
            self.trace_calls=value
            if not value then self.call_trace:shutdown() end
            self.recorder:event(value and "开启方法跟踪" or "关闭方法跟踪")
        end
        imgui.text(self.status)
        imgui.text("隔离调用数："..self.isolation.blocked)
        imgui.text("悬停刷新："..self.refresh.requests.."次请求／"..self.refresh.returned.."次返回／"..self.refresh.completed.."次复隔离；"..self.refresh.status)
        imgui.text("记录："..self.recorder.status)
        imgui.text("方法跟踪："..self.call_trace.status.."；保存调用对："..#self.recorder.data.call_trace.pairs.." / 5000")
        imgui.text("状态样本："..#self.recorder.data.samples.." / 3000（满额后动画继续）")
        local row=self.recorder.latest
        if row then
            imgui.text("着地："..tostring(row.ground).."；飞行："..tostring(row.flight).."；动作："..tostring(row.action))
            local base=row.base_layer
            if base then imgui.text("基础层读数：Bank "..tostring(base.bank).." / Motion "..tostring(base.id)) end
        end
        imgui.tree_pop()
    end
    function self:shutdown()
        self.recorder:event("Reset恢复前",self,"before_reset")
        self.call_trace:shutdown()
        self.alive=false;self:changed()
        self.refresh:cancel(self,"Reset取消刷新")
        self.ab:cancel()
        local ok,err=pcall(function() self.isolation:stop() end)
        if not ok then log.error("GriffinAnimationLab restore: "..tostring(err)) end
        self.recorder:event("Reset恢复后",self,"after_reset")
        self.recorder:flush()
    end
    return self
end
return M
