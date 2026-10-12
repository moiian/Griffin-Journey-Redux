-- Opt-in A/B intervention on one retained ActionManager; no action or position writes.
local M={}
function M.new()
    local self={blocked=0,errors=0,status="关闭"}
    function self:cancel()
        self.active=nil;self.status="关闭"
    end
    function self:validate(lab,d)
        local s=assert(self.active,"动作更新隔离已停止")
        d=d or lab.isolation.active
        assert(s.lab==lab and lab.alive and lab.bound and lab.enabled and lab.record and lab.recorder.enabled,"动作更新隔离需保持绑定、隔离与记录")
        local core=assert(rawget(_G,"NickCore"),"NickCore未就绪")
        assert(not core.properties.isPaused,"暂停时不拦截动作更新")
        assert(d and (d.ab_stage=="A" or d.ab_stage=="B") and not d.recovering and not d.released
            and d.instance==s.instance and (not s.d or s.d==d) and lab.isolation:valid(d),"动作更新隔离轮或组件变化")
        local bridge=assert(rawget(_G,"GriffinFlightBetaBridge"),"Beta桥接失效")
        local old=rawget(_G,"GriffinMountExperimentControl")
        assert(lab.instance==s.instance and bridge.get_instance()==s.instance and not bridge.is_driving()
            and not (old and old.is_driving()),"动作更新隔离实例或驾驶变化")
        assert(s.instance.chara:call("get_ActionManager()")==s.manager and s.manager.Fsm==d.fsm
            and s.manager:call("get_GameObject()")==s.instance.go,"动作管理器归属变化")
        assert(d.fsm:call("get_Enabled()")==false and d.motion:call("get_RootMotion()")==d.none,"动作更新隔离控制值变化")
        return s
    end
    function self:install()
        if self.hooked then return end
        local td=assert(sdk.find_type_definition("app.ActionManager"),"缺少ActionManager")
        local method=assert(td:get_method("update()"),"缺少ActionManager.update")
        assert(not method:is_static() and method:get_num_params()==0
            and method:get_return_type():get_full_name()=="System.Void","ActionManager.update签名变化")
        sdk.hook(method,function(args)
            local s=self.active
            if not s or sdk.to_ptr(args[2])~=s.pointer then return end
            local core=rawget(_G,"NickCore")
            if not core or core.properties.isPaused then return end
            -- A is captured before arming the effective skip; never block a native preparation.
            if not s.d or not s.lab.isolation.active or not s.lab.alive or not s.lab.bound
                or not s.lab.enabled or not s.lab.record then return end
            local ok,err=pcall(function() self:validate(s.lab) end)
            if not ok then
                self.errors=self.errors+1;self.last_error=tostring(err)
                self:cancel();self.status="已停止："..self.last_error
                return
            end
            s.blocked=s.blocked+1;self.blocked=self.blocked+1
            return sdk.PreHookResult.SKIP_ORIGINAL
        end,function(retval) return retval end)
        self.hooked=true
    end
    function self:arm(lab,instance,manager)
        assert(not self.active and not lab.isolation.active,"动作更新隔离需从新A阶段开始")
        assert(lab.ab_test and not lab.refresh_action and not lab.refresh.wait and lab.record,"动作更新隔离仅用于A/B，不与悬停刷新混用")
        assert(instance.chara:call("get_ActionManager()")==manager and manager:call("get_GameObject()")==instance.go,"动作管理器归属变化")
        self:install()
        local s={lab=lab,instance=instance,manager=manager,pointer=sdk.to_ptr(manager),blocked=0}
        self.blocked=0;self.last_error=nil;self.active=s;self.status="本轮暂停精确实例ActionManager.update"
        return s
    end
    return self
end
return M
