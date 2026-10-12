-- Exact-instance animation isolation. Optional preparation runs once before freezing.
local M = {}
function M.new()
    local self = {blocked=0,serial=0}
    function self:valid(d)
        return d and d.instance.go:get_Valid() and d.instance.chara:get_Valid()
            and d.instance.chara:call("get_Motion()")==d.motion
    end
    function self:install()
        if self.hooked then return end
        local td=assert(sdk.find_type_definition("app.FlightControl"),"缺少FlightControl")
        local methods={}
        for _,name in ipairs({"update()","lateUpdate()","eventFlightUpdate(via.GameObject)"}) do
            methods[#methods+1]=assert(td:get_method(name),name)
        end
        for _,method in ipairs(methods) do
            sdk.hook(method,function(args)
                local d=self.active
                if d and not d.recovering and not d.preparing and sdk.to_ptr(args[2])==d.flight_ptr then
                    self.blocked=self.blocked+1
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end
            end,function(retval) return retval end)
        end
        self.hooked=true
    end
    function self:stop()
        local d=self.active
        if not d then return end
        d.recovering=true
        if self:valid(d) then
            if d.motion_touched then
                d.motion:call("set_RootMotion(via.motion.RootPlayMode)",d.original_root)
                d.motion_touched=false
            end
            if d.fsm_touched then
                assert(d.instance.chara:call("get_ActionManager()").Fsm==d.fsm,"FSM归属变化，恢复保留待检查")
                d.fsm:call("set_Enabled(System.Boolean)",d.original_enabled)
                d.fsm_touched=false
            end
        end
        self.active=nil
    end
    function self:play(instance,clip,before_freeze)
        assert(clip==5100 or clip==5101,"只测试已确认资源")
        local d=self.active
        if d then
            assert(not d.recovering,"恢复未完成，请先取消隔离重试")
            assert(d.instance==instance and self:valid(d),"绑定对象已变化")
        end
        local motion=d and d.motion or instance.chara:call("get_Motion()")
        assert(motion and motion:call("hasMotion(System.UInt32, System.UInt32)",0,clip),"当前狮鹫未加载该动画")
        local base=assert(motion:call("getLayer(System.UInt32)",0),"没有基础层")
        assert(base:call("get_Enabled()"),"基础层未启用")
        if not d then
            assert(instance.go:get_Valid() and instance.chara:get_Valid(),"对象失效")
            local manager=assert(instance.chara:call("get_ActionManager()"),"没有动作管理器")
            local fsm=assert(manager.Fsm,"没有FSM")
            local flight=assert(instance.chara:call("get_FlightCtrl()"),"没有飞行控制器")
            assert(flight:call("get_CachedCharacter()")==instance.chara,"控制器归属不同")
            local enum=assert(sdk.find_type_definition("via.motion.RootPlayMode"),"缺少根位移枚举")
            local none=assert(enum:get_field("None"),"缺少None"):get_data(nil)
            d={instance=instance,motion=motion,fsm=fsm,flight_ptr=sdk.to_ptr(flight),
                original_enabled=fsm:call("get_Enabled()"),original_root=motion:call("get_RootMotion()"),layers={}}
            assert(type(none)=="number" and type(d.original_root)=="number" and type(d.original_enabled)=="boolean","无法保存原状态")
            local count=motion:call("getLayerCount()")
            assert(count>0 and count<=16,"层数异常")
            for i=0,count-1 do
                local layer=motion:call("getLayer(System.UInt32)",i)
                if layer and layer:call("get_Enabled()") then
                    local bank,id=layer:call("get_MotionBankID()"),layer:call("get_MotionID()")
                    if motion:call("hasMotion(System.UInt32, System.UInt32)",bank,id) then
                        d.layers[#d.layers+1]={index=i,bank=bank,id=id}
                    end
                end
            end
            self:install()
            self.serial=self.serial+1;d.serial=self.serial
            self.active=d;self.blocked=0
            if before_freeze then
                -- Save the original control values before native reset can touch them.
                d.preparing=true;d.fsm_touched=true;d.motion_touched=true
                before_freeze(d)
                assert(self:valid(d) and manager.Fsm==d.fsm,"准备后组件变化")
                assert(motion:call("hasMotion(System.UInt32, System.UInt32)",0,clip),"准备后动画资源不可用")
                base=assert(motion:call("getLayer(System.UInt32)",0),"准备后基础层不可用")
                assert(base:call("get_Enabled()"),"准备后基础层未启用")
                d.preparing=nil
            end
            d.fsm_touched=true;fsm:call("set_Enabled(System.Boolean)",false)
            d.motion_touched=true;motion:call("set_RootMotion(via.motion.RootPlayMode)",none)
            for _,row in ipairs(d.layers) do
                if row.index~=0 then
                    motion:call("getLayer(System.UInt32)",row.index):call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",row.bank,row.id,0.0,12.0,1,1)
                end
            end
        end
        base:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",0,clip,0.0,12.0,1,1)
        d.clip=clip
    end
    return self
end
return M
