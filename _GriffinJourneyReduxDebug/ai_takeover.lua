-- Component-level decision takeover; native flight/action/navigation remain enabled.
return function(ctx)
local _ENV=ctx
ai_takeover={enabled=false,held=state.recovery and state.recovery.ai_component_hold or nil,
    writes=0,reapplied=0,errors=0,status="方向6：关闭"}
local function signature()
    local td=assert(sdk.find_type_definition("via.Behavior"),"缺少via.Behavior")
    for _,spec in ipairs({{"get_Enabled()",0,"System.Boolean"},{"set_Enabled(System.Boolean)",1,"System.Void"}}) do
        local m=assert(td:get_method(spec[1]),"缺少组件Enabled接口")
        assert(not m:is_static() and m:get_num_params()==spec[2]
            and m:get_return_type():get_full_name()==spec[3],"组件Enabled签名变化")
    end
end
local function owned(s)
    return s.result==s.spawn.result and s.result.go==s.go and s.result.chara==s.ch
        and s.go:get_Valid() and s.ch:get_Valid()
        and s.ch:call("get_GameObject()")==s.go and s.ch:call("get_AIDecisionMaker()")==s.maker
        and s.maker:call("get_Character()")==s.ch and s.maker:call("get_GameObject()")==s.go
end
local function discard(self,s)
    if s.driver.ai_component_hold==s then s.driver.ai_component_hold=nil end
    self.held=nil
end
function ai_takeover:release()
    local s=self.held
    if not s then return true end
    local ok,err=pcall(function()
        -- Never call a saved component after its exact instance/reference has changed.
        if not owned(s) then
            discard(self,s);self.status="方向6：实例或组件已变化，旧引用未写入";return
        end
        if s.touched then
            local current=s.maker:call("get_Enabled()")
            assert(type(current)=="boolean","无法读取组件恢复状态")
            if current~=s.original then s.maker:call("set_Enabled(System.Boolean)",s.original) end
            assert(s.maker:call("get_Enabled()")==s.original,"决策组件恢复读回失败")
            s.touched=false
        end
        discard(self,s)
    end)
    if not ok then
        self.errors=self.errors+1;self.status="方向6恢复待重试："..tostring(err)
        return false,tostring(err)
    end
    return true
end
function ai_takeover:set_enabled(value)
    self.enabled=value==true
    self.status=self.enabled and "方向6：已勾选，等待驾驶行为帧" or "方向6：关闭，已有接管将在行为帧恢复"
end
function ai_takeover:tick(d)
    if not self.enabled and not self.held then return true end
    if menu.gameplay_paused() then return true end
    if self.held and (not self.enabled or self.held.driver~=d) then
        local ok,err=self:release()
        if not ok then return false,err end
    end
    if not self.enabled then self.status="方向6：关闭";return true end
    if not d then self.status="方向6：已勾选，等待驾驶";return true end
    local ok,err=pcall(function()
        local c=assert(core(),"NickCore未就绪")
        assert(alive and active==d and c.properties.player==d.player and d.spawn.owner==d.player
            and state.spawns[#state.spawns]==d.spawn and not d.spawn.delete_requested,"驾驶归属变化")
        local ch=validate_spawn(d.spawn)
        local s=self.held
        if not s then
            signature()
            s={driver=d,spawn=d.spawn,result=d.spawn.result,go=d.spawn.result.go,ch=ch,
                maker=assert(ch:call("get_AIDecisionMaker()"),"没有狮鹫决策组件")}
            assert(owned(s),"决策组件归属不符")
            s.original=s.maker:call("get_Enabled()")
            assert(type(s.original)=="boolean","无法保存原Enabled值")
            self.held=s;d.ai_component_hold=s
        end
        assert(s.ch==ch and owned(s),"决策组件引用变化")
        local current=s.maker:call("get_Enabled()")
        assert(type(current)=="boolean","无法读取Enabled")
        if current then
            if s.touched then self.reapplied=self.reapplied+1 end
            s.touched=true -- Setter may raise after writing; retain the original for recovery.
            s.maker:call("set_Enabled(System.Boolean)",false)
            self.writes=self.writes+1
        end
        assert(s.maker:call("get_Enabled()")==false,"决策组件禁用读回失败")
        self.status="方向6：当前狮鹫AIDecisionMaker已禁用；原值="..tostring(s.original)
    end)
    if not ok then
        self.errors=self.errors+1;self.enabled=false
        local restored,restore_err=self:release()
        self.status="方向6已停止："..tostring(err)..(restored and "" or "；恢复待重试："..tostring(restore_err))
        return restored,restore_err
    end
    return true
end
end
