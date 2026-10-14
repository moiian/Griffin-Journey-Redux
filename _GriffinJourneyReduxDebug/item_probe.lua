-- Optional exact-item observation. Hooks never change native eligibility results.
return function(ctx)
local _ENV=ctx
item_probe={enabled=false,path="GriffinJourneyRedux_ItemProbe.json",records={},counts={},last={},status="道具使用探针：关闭"}
local probe=item_probe
local function scoped() return probe.enabled and alive and state.generation==generation end
local function fields(value)
    return value and {id=value._Id,effect=value._UseEffect,category=value._Category,subcategory=value._SubCategory,use_attr=value._UseAttr}
end
local function entity_snapshot()
    local uc=rawget(_G,"usercontent");local db=uc and uc.database
    local item=db and db.get_entity("item_data",58990)
    local script=db and db.get_entity("custom_script",67608110)
    local native
    local ok,err=pcall(function()
        local manager=sdk.get_managed_singleton("app.ItemManager")
        local dict=manager and manager._ItemDataDict
        native=dict and fields(dict[58990])
    end)
    return {ce_loaded=db~=nil,item_loaded=item~=nil,script_loaded=script~=nil,script_function=script and type(script.script_func)=="function" or false,
        editor_param=item and fields(item.runtime_instance),native_param=native,native_read_error=not ok and tostring(err) or nil,
        spawns=#state.spawns,driving=active~=nil,recovery=state.recovery~=nil,queued=queued,summon_stage=summon.current and summon.current.stage,
        paused=menu.gameplay_paused(),generation_current=alive and state.generation==generation}
end
function probe:add(kind,detail)
    if not scoped() then return end
    self.records[#self.records+1]={time=now(),kind=kind,detail=detail}
    if #self.records>200 then table.remove(self.records,1) end
    self.dirty=true
end
function probe:actor_info(from,to)
    local c=core();local player=c and c.properties.player
    return {from_nil=from==nil,to_nil=to==nil,from_player=player~=nil and from==player,to_player=player~=nil and to==player}
end
function probe:effect_check(from,to,data)
    if not scoped() or not data or data._Id~=58990 then return end
    local label="isUseEnableSub"
    self.counts[label]=(self.counts[label] or 0)+1;self.dirty=true
    if self.last[label] and now()-self.last[label]<.25 then return end
    self.last[label]=now()
    self:add(label,{param=fields(data),actors=self:actor_info(from,to)})
end
-- Common already has an exact-item adapter hook; observe there without a second hook.
function probe:common_check(from,to,native,result,override)
    if not scoped() then return end
    local label="isUseEnableNoLockCommon(app.ItemDefine.StorageData, app.Character, app.Character, System.Boolean)"
    self.counts[label]=(self.counts[label] or 0)+1;self.dirty=true
    if self.last[label] and now()-self.last[label]<.25 then return end
    self.last[label]=now()
    local record=self:actor_info(from,to)
    local function boolean(v) if type(v)=="boolean" then return v end;return (sdk.to_int64(v)&0xff)~=0 end
    local ok,value=pcall(boolean,native)
    record.native_result=ok and value or false;record.return_readable=ok
    local valid,effective=pcall(boolean,result)
    record.effective_result=valid and effective or false;record.override=override
    self:add(label,record)
end
function probe:install()
    if self.installed then return end
    self.installed=true
    local td=sdk.find_type_definition("app.ItemManager")
    local signatures={
        {"isUseEnable(System.Int32, app.Character, app.Character)",false},
        {"isUseEnable(app.ItemDefine.StorageData, app.Character, app.Character)",true},
        {"isUseEnableNoLock(System.Int32, app.Character, app.Character)",false},
        {"isUseEnableNoLockBase(app.ItemDefine.StorageData, app.Character, app.Character)",true}}
    for index,spec in ipairs(signatures) do
        local label,storage_arg=spec[1],spec[2]
        local method=td and td:get_method(label)
        if method then
            local key="griffin_probe_"..index
            sdk.hook(method,function(args)
                local s=thread.get_hook_storage();s[key]=nil
                if not scoped() then return end
                local ok,record=pcall(function()
                    local id
                    if storage_arg then
                        local data=sdk.to_valuetype(args[3],"app.ItemDefine.StorageData");id=data and data._ItemId
                    else id=sdk.to_int64(args[3]) & 0xffffffff end
                    if id~=58990 then return end
                    return self:actor_info(sdk.to_managed_object(args[4]),sdk.to_managed_object(args[5]))
                end)
                if ok then s[key]=record else self:add("hook_read_error",{method=label,error=tostring(record)}) end
            end,function(ret)
                local s=thread.get_hook_storage();local record=s[key];s[key]=nil
                if record and scoped() then
                    self.counts[label]=(self.counts[label] or 0)+1;self.dirty=true
                    if not self.last[label] or now()-self.last[label]>=.25 then
                        self.last[label]=now()
                        local ok,value=pcall(function()
                            if type(ret)=="boolean" then return ret end
                            return (sdk.to_int64(ret) & 0xff)~=0
                        end)
                        record.native_result=ok and value or false;record.return_readable=ok
                        self:add(label,record)
                    end
                end
                return ret -- Observation only, including all unrelated items.
            end)
        else self:add("missing_method",label) end
    end
end
function probe:flush()
    if not self.enabled or not self.dirty then return end
    local ok,result=pcall(json.dump_file,self.path,{version=VERSION,records=self.records,counts=self.counts})
    self.status=ok and result~=false and "道具使用探针：记录中" or "道具使用探针：保存失败"
    if ok and result~=false then self.dirty=false end
end
function probe:set_enabled(value)
    if value then
        self.enabled=true;self.records={};self.counts={};self.last={};self.next_snapshot=nil;self.next_flush=nil
        self:install();local ok,detail=pcall(entity_snapshot);self:add("enabled",ok and detail or {error=tostring(detail)});self:flush()
    else self:flush();self.enabled=false;self.status="道具使用探针：关闭" end
end
function probe:tick()
    if not scoped() then return end
    local t=os.clock()
    if not self.next_snapshot or t>=self.next_snapshot then
        self.next_snapshot=t+1
        local ok,detail=pcall(entity_snapshot)
        self:add("snapshot",ok and detail or {error=tostring(detail)})
    end
    if not self.next_flush or t>=self.next_flush then self.next_flush=t+1;self:flush() end
end
function probe:draw()
    local changed,value=menu.toggle("记录道具使用探针（只观察）",self.enabled)
    if changed then self:set_enabled(value) end
    imgui.text(self.status)
    if self.enabled then imgui.text("开启后在背包选中巧克力、打开使用菜单，再关闭探针保存。") end
end
end

