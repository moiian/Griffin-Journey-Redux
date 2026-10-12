-- Opt-in observations only: native calls and return values always pass through.
local Probe=require("_GriffinAnimationLab.state_probe")
local M={}
local methods={
    {type="app.ActionManager",method="update()",key="action",get=function(ch) return ch:call("get_ActionManager()") end},
    {type="app.AdjustTerrain",method="update()",key="terrain",get=function(ch) return ch:get_field("<AdjustTerrain>k__BackingField") end,
        owns=function(obj,ch) return obj:get_field("Character")==ch end},
    {type="app.AdjustTerrain",method="updateSubPosition()",key="subposition",get=function(ch) return ch:get_field("<AdjustTerrain>k__BackingField") end,
        owns=function(obj,ch) return obj:get_field("Character")==ch end},
    {type="app.CharacterPosRotAdjuster",method="writeToTransform()",key="pose",get=function(ch) return ch:get_field("<PosRotAdjuster>k__BackingField") end,
        owns=function(obj,ch) return obj:get_field("Chara")==ch end},
    {type="app.CharacterPosRotContextRollbacker",method="updateAndRollbackIfNeeded()",key="rollback",get=function(ch) return ch:get_field("PosRotContextRollbacker") end,
        owns=function(obj,ch) return obj:get_field("PosRotContext")==ch:get_field("<PosRotContext>k__BackingField") end},
}
local function delta(a,b)
    if not a or not b then return end
    local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z
    return math.sqrt(x*x+y*y+z*z)
end
function M.new(recorder)
    local self={enabled=false,epoch=0,sequence=0,status="关闭",recorder=recorder,installed={},next_sample={}}
    local data={sample_hz_per_method=20,per_method_limit=1000,heartbeat_seconds=1,change_threshold_m=0.000001,methods={},pairs={}}
    recorder.data.call_trace=data
    for _,spec in ipairs(methods) do
        data.methods[spec.key]={name=spec.type.."."..spec.method,available=false,hits=0,paired=0,stored=0,changed=0,errors=0,dropped=0}
    end
    function self:problem(key,err)
        local stat=data.methods[key]
        stat.errors=stat.errors+1;stat.last_error=tostring(err):sub(1,500)
    end
    function self:clear()
        self.context=nil;self.epoch=self.epoch+1
    end
    function self:current(ctx,spec)
        local lab=ctx.lab
        if self.context~=ctx or not self.enabled or not self.recorder.enabled or not lab.record
            or not lab.trace_calls or not lab.alive or not lab.bound or lab.instance~=ctx.instance
            or lab.revision~=ctx.revision then return false end
        local core=rawget(_G,"NickCore")
        if not core or core.properties.isPaused then return false end
        local bridge=rawget(_G,"GriffinFlightBetaBridge")
        local instance=ctx.instance
        return bridge and bridge.get_instance()==instance and instance.go:get_Valid() and instance.chara:get_Valid()
            and spec.get(instance.chara)==ctx.targets[spec.key].object
            and (not spec.owns or spec.owns(ctx.targets[spec.key].object,instance.chara))
    end
    function self:install(spec)
        if self.installed[spec.key] then return end
        local stat=data.methods[spec.key]
        local td=assert(sdk.find_type_definition(spec.type),"缺少"..spec.type)
        local method=assert(td:get_method(spec.method),"缺少"..stat.name)
        assert(thread and type(thread.get_hook_storage)=="function","缺少Hook线程存储")
        local storage_key="griffin_animation_lab_trace_"..spec.key
        sdk.hook(method,function(args)
            -- Unknown objects are never converted or inspected.
            local ctx=self.context
            if not ctx or not self.enabled or not self.recorder.enabled then return end
            local target=ctx.targets[spec.key]
            if not target or sdk.to_ptr(args[2])~=target.pointer then return end
            local ok,err=pcall(function()
                local storage=thread.get_hook_storage();storage[storage_key]=nil
                if not self:current(ctx,spec) then return end
                stat.hits=stat.hits+1
                if stat.paired>=data.per_method_limit then stat.dropped=stat.dropped+1;return end
                local now=os.clock()
                if now<(self.next_sample[spec.key] or 0) then return end
                self.next_sample[spec.key]=now+0.05
                self.sequence=self.sequence+1
                storage[storage_key]={context=ctx,epoch=self.epoch,begin_sequence=self.sequence,
                    before=Probe.boundary(ctx.instance,ctx.lab.isolation,"before_call")}
            end)
            if not ok then self:problem(spec.key,err) end
        end,function(retval)
            if not self.context or not self.enabled or not self.recorder.enabled then return retval end
            local ok,err=pcall(function()
                local storage=thread.get_hook_storage()
                local pending=storage[storage_key];storage[storage_key]=nil
                if not pending or pending.epoch~=self.epoch or not self:current(pending.context,spec) then return end
                if stat.paired>=data.per_method_limit then stat.dropped=stat.dropped+1;return end
                local after=Probe.boundary(pending.context.instance,pending.context.lab.isolation,"after_call")
                self.sequence=self.sequence+1
                local row={method=spec.key,begin_sequence=pending.begin_sequence,end_sequence=self.sequence,before=pending.before,after=after,delta_m={}}
                for _,key in ipairs({"position","scene_position","context_universal","controller_scene"}) do
                    row.delta_m[key]=delta(row.before[key],after[key])
                end
                local changed=row.before.action~=after.action or row.before.fsm_enabled~=after.fsm_enabled or row.before.root_motion~=after.root_motion
                local b,a=row.before.base_layer,after.base_layer
                if b and a and (b.bank~=a.bank or b.id~=a.id) then changed=true end
                for _,value in pairs(row.delta_m) do if value>data.change_threshold_m then changed=true end end
                row.changed=changed
                stat.paired=stat.paired+1;if changed then stat.changed=stat.changed+1 end
                if changed or not stat.last_stored_time or after.time-stat.last_stored_time>=data.heartbeat_seconds then
                    data.pairs[#data.pairs+1]=row
                    stat.stored=stat.stored+1;stat.last_stored_time=after.time
                end
            end)
            if not ok then self:problem(spec.key,err) end
            return retval
        end)
        self.installed[spec.key]=true;stat.available=true
    end
    function self:tick(lab)
        self.enabled=lab.trace_calls
        if not lab.alive or not lab.trace_calls or not lab.record or not lab.bound or not lab.instance then
            if self.context then self:clear() end
            self.status=lab.trace_calls and "等待绑定并开启状态记录" or "关闭";return
        end
        local ctx=self.context
        if ctx and (ctx.instance~=lab.instance or ctx.revision~=lab.revision) then self:clear();ctx=nil end
        if ctx or self.pending then return end
        self.pending=true
        local instance,rev,epoch=lab.instance,lab.revision,self.epoch
        run_once(function()
            self.pending=false
            local core=rawget(_G,"NickCore")
            if self.epoch~=epoch or not lab.alive or not lab.trace_calls or not lab.record or not lab.bound
                or lab.instance~=instance or lab.revision~=rev or not core or core.properties.isPaused then return end
            local ok,err=pcall(function()
                local bridge=rawget(_G,"GriffinFlightBetaBridge")
                assert(bridge and bridge.get_instance()==instance and instance.go:get_Valid() and instance.chara:get_Valid(),"实例已变化")
                local targets,count={},0
                for _,spec in ipairs(methods) do
                    local valid,value=pcall(function()
                        local obj=assert(spec.get(instance.chara),"没有对应模块")
                        assert(not spec.owns or spec.owns(obj,instance.chara),"模块归属不符")
                        self:install(spec)
                        return {object=obj,pointer=sdk.to_ptr(obj)}
                    end)
                    if valid then targets[spec.key]=value;count=count+1 else self:problem(spec.key,value) end
                end
                self.context={instance=instance,revision=rev,lab=lab,targets=targets}
                self.status="只读跟踪："..count.." / 5个入口；每入口最高20Hz"
            end)
            if not ok then self.status="跟踪未启用："..tostring(err) end
        end)
    end
    function self:shutdown()
        self.enabled=false;self:clear();self.status="关闭"
    end
    return self
end
return M
