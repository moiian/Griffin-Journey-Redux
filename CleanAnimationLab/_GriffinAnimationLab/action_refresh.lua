-- Separate isolated request processing from native release and measured settling.
local M={}
local NODE="HoverWait"
local REQUEST="requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)"
local SETTLE_SECONDS=0.3
local POSITION_RADIUS=0.01
local TIMEOUT_SECONDS=5
local function position(ch)
    local p=assert(ch:call("get_Transform()"):call("get_UniversalPosition()"),"刷新坐标不可用")
    local copy={x=p.x,y=p.y,z=p.z}
    for _,v in pairs(copy) do assert(type(v)=="number" and v==v and math.abs(v)<math.huge,"刷新坐标异常") end
    assert(copy.x and copy.y and copy.z,"刷新坐标字段缺失")
    return copy
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
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
        local w={d=d,manager=d.instance.chara:call("get_ActionManager()"),elapsed=0,
            stage="isolated",stage_behavior=self.behavior,last_time=os.clock(),stable_seconds=0}
        self:validate(lab,w)
        assert(d.original_enabled==true,"原FSM已关闭，拒绝放行刷新")
        assert(not d.released and d.fsm:call("get_Enabled()")==false,"请先进入隔离再请求悬停")
        self.wait=w
        self.status="已隔离；下个实际行为更新后发送悬停"
        lab.recorder:event(self.status,lab,"refresh_isolated")
    end
    function self:advance(lab)
        local w=assert(self.wait,"没有待确认刷新")
        self:validate(lab,w)
        assert(w.elapsed<TIMEOUT_SECONDS,"刷新超时：原生动作与坐标尚未稳定，已退出隔离")
        if self.behavior<=w.stage_behavior or w.checked_behavior==self.behavior then return end
        w.checked_behavior=self.behavior
        if w.stage=="isolated" then
            assert(not w.d.released and not w.d.fsm:call("get_Enabled()"),"请求前隔离状态被改变")
            lab.recorder:event("隔离中请求原生悬停："..NODE,lab,"before_refresh_request")
            self.requests=self.requests+1
            w.manager:call(REQUEST,10,NODE,0)
            self.returned=self.returned+1
            w.stage="requested";w.stage_behavior=self.behavior
            self.status="悬停已请求；保持隔离处理两个实际行为更新，再放行"
            lab.recorder:event(self.status,lab,"after_refresh_request")
            return
        end
        if w.stage=="requested" then
            assert(not w.d.released and not w.d.fsm:call("get_Enabled()"),"请求处理期隔离状态被改变")
            if self.behavior-w.stage_behavior<2 then return end
            lab.recorder:event("请求后已保持隔离两个行为更新，准备解除隔离",lab,"before_refresh_release")
            lab.isolation:release()
            w.stage="released";w.stage_behavior=self.behavior
            self.status="已解除隔离；等待实际原生动作及坐标稳定，不要求持续悬停"
            lab.recorder:event(self.status,lab,"refresh_released")
            return
        end
        assert(w.d.fsm:call("get_Enabled()")==w.d.original_enabled
            and w.d.motion:call("get_RootMotion()")==w.d.original_root,"放行期间控制状态被改变")
        local action=w.manager.CurrentAction
        local base=assert(w.d.motion:call("getLayer(System.UInt32)",0),"基础层失效")
        local bank,id=base:call("get_MotionBankID()"),base:call("get_MotionID()")
        -- HoverWait may immediately transition to falling/landing. Never freeze its first transient label.
        if not action or not action.Name or not base:call("get_Enabled()")
            or type(bank)~="number" or type(id)~="number"
            or (bank==0 and (id==5100 or id==5101)) then
            w.stable=nil;w.stable_seconds=0;return
        end
        local p=position(w.d.instance.chara)
        local name=tostring(action.Name)
        local s=w.stable
        -- Anchor the whole window: slow cumulative movement cannot pass by small per-frame deltas.
        if not s or s.action~=name or s.bank~=bank or s.id~=id or distance(p,s.anchor)>POSITION_RADIUS then
            w.stable={action=name,bank=bank,id=id,anchor=p,elapsed=w.elapsed,observations=1}
            w.stable_seconds=0;return
        end
        s.observations=s.observations+1
        w.stable_seconds=w.elapsed-s.elapsed
        if s.observations<3 or w.stable_seconds<SETTLE_SECONDS then return end
        lab.recorder:event("原生阶段动作与坐标已稳定，准备重新隔离；实际动作："..name,lab,"refresh_settled")
        lab.isolation:play(w.d.instance,lab.flap and 5101 or 5100)
        self.wait=nil;self.completed=self.completed+1
        self.status="已完成复隔离；原生阶段动作："..name.."；画面效果待实测"
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
