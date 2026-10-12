-- One opt-in native reset per new isolation interval. No position/velocity writes.
local M={}
local option_type="app.Character.ResetActionAndAIOption"
function M.new()
    local self={attempts=0,returned=0,status="关闭"}
    function self:run(lab,d)
        assert(lab.alive and lab.bound and lab.enabled and lab.reset_task,"重置实验未启用")
        assert(lab.record and lab.recorder.enabled,"请先开启状态记录，再测试原生重置")
        local core=rawget(_G,"NickCore")
        assert(core and not core.properties.isPaused,"暂停中不重置")
        local bridge=assert(rawget(_G,"GriffinFlightBetaBridge"),"没有Beta桥接")
        assert(bridge.get_instance()==d.instance and lab.instance==d.instance and not bridge.is_driving(),"接管实例已变化或正在驾驶")
        local old=rawget(_G,"GriffinMountExperimentControl")
        assert(not (old and old.is_driving()),"旧实验工具正在驾驶")
        assert(lab.isolation:valid(d) and d.instance.chara:call("get_ActionManager()").Fsm==d.fsm,"接管组件已变化")
        assert(d.original_enabled==true,"原FSM已关闭，拒绝原生重置")
        local td=assert(sdk.find_type_definition("app.Character"),"缺少Character")
        assert(td:get_method("resetActionAndAI("..option_type..")"),"缺少精确重置接口")
        local ot=assert(sdk.find_type_definition(option_type),"缺少重置选项类型")
        assert(ot:get_method(".ctor()"),"缺少重置选项构造函数")
        for _,field in ipairs({"ActionName","IsResetAI","IsResetCatch","IsResetCaught"}) do
            assert(ot:get_field(field),"缺少重置选项字段："..field)
        end
        local option=assert(sdk.create_instance(option_type),"无法创建重置选项"):add_ref()
        assert(option:get_type_definition():get_full_name()==option_type,"重置选项类型错误")
        option:call(".ctor()")
        option:set_field("IsResetAI",true)
        option:set_field("IsResetCatch",false)
        option:set_field("IsResetCaught",false)
        option:set_field("ActionName",sdk.create_managed_string("Wait"))
        assert(option:get_field("IsResetAI")==true and option:get_field("IsResetCatch")==false
            and option:get_field("IsResetCaught")==false and tostring(option:get_field("ActionName"))=="Wait","重置选项读回不符")
        assert(bridge.get_instance()==d.instance and lab.alive and lab.instance==d.instance
            and lab.isolation:valid(d) and not core.properties.isPaused,"重置前实例或暂停状态变化")
        d.reset_option=option -- Keep the constructed option alive during the interval.
        lab.recorder:event("原生任务重置前：Wait／ResetAI",lab,"before_task_reset")
        self.attempts=self.attempts+1
        self.status="调用中"
        local ok,err=pcall(function() d.instance.chara:call("resetActionAndAI("..option_type..")",option) end)
        if not ok then
            self.status="调用失败："..tostring(err)
            lab.recorder:event(self.status,lab,"task_reset_error")
            error(self.status)
        end
        self.returned=self.returned+1
        self.status="原生重置已返回；实际效果待检查"
        lab.recorder:event(self.status,lab,"after_task_reset")
        assert(lab.isolation:valid(d) and d.instance.chara:call("get_ActionManager()").Fsm==d.fsm
            and sdk.to_ptr(d.instance.chara:call("get_FlightCtrl()"))==d.flight_ptr,"重置后组件变化，终止接管")
    end
    return self
end
return M
