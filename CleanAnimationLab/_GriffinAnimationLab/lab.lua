local Isolation=require("_GriffinAnimationLab.isolation")
local Recorder=require("_GriffinAnimationLab.recorder")
local M={}
function M.new()
    local self={bound=false,enabled=false,flap=false,record=false,revision=0,alive=true,
        status="全部关闭。先用Beta生成狮鹫并结束驾驶；停止旧工具的隔离播放。",
        isolation=Isolation.new(),recorder=Recorder.new()}
    function self:changed()
        self.revision=self.revision+1
    end
    function self:apply()
        if not self.enabled or not self.bound then self.isolation:stop() end
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
            self.isolation:play(r,self.flap and 5101 or 5100)
            self.status="隔离播放："..(self.flap and "挥翅5101" or "滑翔5100").."；未锁定位置。"
        else self.status="已绑定；隔离播放关闭，原生控制生效。" end
        self.recorder:event(self.status)
    end
    function self:tick()
        if not self.alive then return end
        local core=rawget(_G,"NickCore")
        if not core or not core.properties or type(rawget(_G,"run_once"))~="function" then
            self.status="等待NickCore与run_once。";return
        end
        self.recorder.enabled=self.record
        if core.properties.isPaused then return end
        if self.isolation.active and self.applied==self.revision then
            local b=rawget(_G,"GriffinFlightBetaBridge")
            local old=rawget(_G,"GriffinMountExperimentControl")
            local ok,valid=pcall(function()
                return b and b.get_instance()==self.instance and not b.is_driving()
                    and not (old and old.is_driving()) and self.isolation:valid(self.isolation.active)
            end)
            if not ok or not valid then self.bound=false;self.enabled=false;self:changed() end
        end
        if not self.pending and self.applied~=self.revision then
            self.pending=true
            local rev=self.revision
            run_once(function()
                self.pending=false
                if not self.alive or rev~=self.revision then return end
                local ok,err=pcall(function() self:apply() end)
                self.applied=rev
                if not ok then
                    self.enabled=false
                    local restored,restore_err=pcall(function() self.isolation:stop() end)
                    self.status=tostring(err)..(restored and "" or "；恢复失败："..tostring(restore_err))
                    self.recorder:event(self.status)
                end
            end)
        end
        self.recorder:tick(self.isolation)
    end
    function self:draw()
        if not imgui.tree_node("狮鹫动画实验室 0.1.0") then return end
        imgui.text("无点击冷却；切换动画保持隔离。关闭隔离才恢复原生控制。")
        local changed,value=imgui.checkbox("绑定Beta当前狮鹫",self.bound)
        if changed then self.bound=value;if not value then self.enabled=false end;self:changed() end
        changed,value=imgui.checkbox("启用隔离播放",self.enabled)
        if changed then self.enabled=value;self:changed() end
        changed,value=imgui.checkbox("使用挥翅5101（关闭为滑翔5100）",self.flap)
        if changed then self.flap=value;self:changed() end
        changed,value=imgui.checkbox("启用坐标记录（5Hz）",self.record)
        if changed then self.record=value;self.recorder.enabled=value;self.recorder:flush() end
        imgui.text(self.status)
        imgui.text("隔离调用数："..self.isolation.blocked)
        imgui.text("记录："..self.recorder.status)
        imgui.tree_pop()
    end
    function self:shutdown()
        self.alive=false;self:changed()
        local ok,err=pcall(function() self.isolation:stop() end)
        if not ok then log.error("GriffinAnimationLab restore: "..tostring(err)) end
        self.recorder:flush()
    end
    return self
end
return M
