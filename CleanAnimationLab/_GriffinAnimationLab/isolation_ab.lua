-- Opt-in, one-way A/B: freeze controls without replay; then play only base 5100.
local M={}
function M.new()
    local self={}
    function self:cancel()
        self.active=nil;self.pending=nil;self.manager=nil
    end
    function self:validate(lab)
        local d=assert(self.active,"没有A/B对照")
        assert(lab.alive and lab.bound and lab.enabled and lab.record and lab.recorder.enabled,"A/B对照需保持绑定、隔离与状态记录")
        local core=assert(rawget(_G,"NickCore"),"NickCore未就绪")
        assert(not core.properties.isPaused,"暂停时不进行A/B步骤")
        local bridge=assert(rawget(_G,"GriffinFlightBetaBridge"),"Beta桥接失效")
        local old=rawget(_G,"GriffinMountExperimentControl")
        assert(bridge.get_instance()==d.instance and lab.instance==d.instance and not bridge.is_driving()
            and not (old and old.is_driving()),"A/B实例或驾驶归属变化")
        assert(lab.isolation.active==d and not d.recovering and not d.released and lab.isolation:valid(d),"A/B隔离组件失效")
        if d.action_gate then
            assert(lab.action_gate.active==d.action_gate,"动作更新隔离提前停止，请保存记录")
            lab.action_gate:validate(lab,d)
        end
        local ch=d.instance.chara
        assert(ch:call("get_ActionManager()")==self.manager and self.manager.Fsm==d.fsm
            and self.manager:call("get_GameObject()")==d.instance.go,"A/B动作管理器归属变化")
        local flight=assert(ch:call("get_FlightCtrl()"),"A/B飞控失效")
        assert(sdk.to_ptr(flight)==d.flight_ptr and flight:call("get_CachedCharacter()")==ch,"A/B飞控归属变化")
        assert(d.fsm:call("get_Enabled()")==false and d.motion:call("get_RootMotion()")==d.none,"A/B控制状态发生变化")
    end
    function self:begin(lab,instance)
        assert(not self.active and not lab.isolation.active,"A/B必须从新一轮隔离开始")
        assert(lab.record and lab.recorder.enabled,"A/B对照需要状态记录")
        assert(not lab.refresh_action and not lab.refresh.wait,"请关闭接管时刷新旧指令，再开始A/B对照")
        local ch=instance.chara
        local manager=assert(ch:call("get_ActionManager()"),"没有动作管理器")
        assert(manager:call("get_GameObject()")==instance.go,"动作管理器归属变化")
        assert(manager.Fsm:call("get_Enabled()")==true,"原FSM已关闭，请先恢复原生控制")
        assert(manager.CurrentAction.Name=="HoverWait" and ch:call("get_IsFlight()")==true,"请先在隔离关闭时请求悬停，等动作HoverWait且飞行true")
        local base=assert(ch:call("get_Motion()"):call("getLayer(System.UInt32)",0),"没有基础层")
        local bank,id=base:call("get_MotionBankID()"),base:call("get_MotionID()")
        assert(not (bank==0 and (id==5100 or id==5101)),"基础层仍是隔离资源，请先恢复原生悬停")
        local gate
        if lab.pause_actions then gate=lab.action_gate:arm(lab,instance,manager) end
        lab.recorder:event("A前：原生悬停；准备只隔离控制",lab,"ab_before_controls")
        lab.isolation:play(instance,nil,true)
        self.active=lab.isolation.active;self.manager=manager
        if gate then gate.d=self.active;self.active.action_gate=gate end
        self:validate(lab)
        lab.recorder:event(self:status(),lab,"ab_controls")
    end
    function self:request_motion(lab)
        local d=self.active
        if not d or d.ab_stage~="A" or self.pending then return end
        self.pending=d
        lab:changed()
    end
    function self:advance(lab)
        self:validate(lab)
        local d=self.active
        if not self.pending then return end
        assert(self.pending==d and d.ab_stage=="A","A/B步骤已过期")
        self.pending=nil
        lab.recorder:event("B前：保持现有隔离，只替换基础层5100",lab,"ab_before_motion")
        lab.isolation:play(d.instance,5100)
        d.ab_stage="B"
        lab.recorder:event(self:status(),lab,"ab_motion")
    end
    function self:status()
        return self.active.ab_stage=="A" and "A：只隔离控制，所有动画层零重播；观察约2秒。"
            or "B：同一隔离轮，仅基础层换5100一次；观察约2秒。"
    end
    return self
end
return M
