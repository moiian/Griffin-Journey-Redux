-- One native request, a real behavior-update window, then acknowledged isolation.
local M={}
local NODE="HoverWait"
local REQUEST="requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)"
function M.new()
    local self={requests=0,returned=0,completed=0,failed=0,behavior=0,status="关闭"}
    function self:pause()
        if self.wait then self.wait.last_time=nil end
    end
    function self:behavior_tick()
        local w=self.wait
        if not w then return end
        local core=rawget(_G,"NickCore")
        if not core or core.properties.isPaused then self:pause();return end
        local now=os.clock()
        if w.last_time then w.elapsed=w.elapsed+math.max(0,now-w.last_time) end
        w.last_time=now
        self.behavior=self.behavior+1
    end
    function self:validate(lab,w)
        assert(lab.alive and lab.enabled and lab.bound and lab.record and lab.recorder.enabled,"刷新需要保持绑定、隔离与状态记录")
        local core=assert(rawget(_G,"NickCore"),"NickCore未就绪")
        assert(not core.properties.isPaused,"暂停时不刷新")
        local bridge=assert(rawget(_G,"GriffinFlightBetaBridge"),"Beta桥接失效")
        local old=rawget(_G,"GriffinMountExperimentControl")
        assert(bridge.get_instance()==w.d.instance and lab.instance==w.d.instance and not bridge.is_driving()
            and not (old and old.is_driving()),"刷新实例或驾驶归属变化")
        local ch=w.d.instance.chara
        assert(lab.isolation.active==w.d and lab.isolation:valid(w.d),"刷新组件失效")
        assert(ch:call("get_ActionManager()")==w.manager and w.manager.Fsm==w.d.fsm
            and w.manager:call("get_GameObject()")==w.d.instance.go,"动作管理器归属变化")
        local flight=assert(ch:call("get_FlightCtrl()"),"飞控失效")
        assert(sdk.to_ptr(flight)==w.d.flight_ptr and flight:call("get_CachedCharacter()")==ch,"飞控归属变化")
    end
    function self:begin(lab,d)
        assert(not self.wait,"刷新尚未结束")
        local w={d=d,manager=d.instance.chara:call("get_ActionManager()"),elapsed=0}
        self:validate(lab,w)
        assert(d.original_enabled==true,"原FSM已关闭，拒绝放行刷新")
        assert(not d.released and d.fsm:call("get_Enabled()")==false,"请先进入隔离再请求悬停")
        self.wait=w
        lab.recorder:event("隔离中请求原生悬停："..NODE,lab,"before_refresh_request")
        self.requests=self.requests+1
        w.manager:call(REQUEST,10,NODE,0)
        self.returned=self.returned+1
        lab.recorder:event("悬停请求已返回，尚未确认执行",lab,"after_refresh_request")
        lab.isolation:release()
        w.released_behavior=self.behavior;w.last_time=os.clock()
        self.status="已短暂解除隔离，等待原生HoverWait实际进入（最多3秒有效行为时间）"
        lab.recorder:event(self.status,lab,"refresh_released")
    end
    function self:advance(lab)
        local w=assert(self.wait,"没有待确认刷新")
        self:validate(lab,w)
        assert(w.elapsed<3,"悬停刷新超时：未确认原生动作生效，已退出隔离")
        if self.behavior<=w.released_behavior or w.checked_behavior==self.behavior then return end
        w.checked_behavior=self.behavior
        assert(w.d.fsm:call("get_Enabled()")==w.d.original_enabled
            and w.d.motion:call("get_RootMotion()")==w.d.original_root,"放行期间控制状态被改变")
        local action=w.manager.CurrentAction
        local base=assert(w.d.motion:call("getLayer(System.UInt32)",0),"基础层失效")
        local bank,id=base:call("get_MotionBankID()"),base:call("get_MotionID()")
        -- A changed action label alone is insufficient; the native layer must have replaced our clip.
        if not action or tostring(action.Name)~=NODE or not base:call("get_Enabled()")
            or type(bank)~="number" or type(id)~="number"
            or (bank==0 and (id==5100 or id==5101)) then return end
        lab.recorder:event("已观察到原生HoverWait及基础层资源，重新隔离",lab,"refresh_acknowledged")
        lab.isolation:play(w.d.instance,lab.flap and 5101 or 5100)
        self.wait=nil;self.completed=self.completed+1
        self.status="悬停已进入，已重新隔离；是否静止仍需实测"
        lab.recorder:event(self.status,lab,"refresh_completed")
    end
    function self:cancel(lab,reason,failed)
        if not self.wait then return end
        self.wait=nil
        if failed then self.failed=self.failed+1 end
        self.status=reason
        lab.recorder:event(reason,lab,failed and "refresh_failed" or "refresh_cancelled")
    end
    return self
end
return M
