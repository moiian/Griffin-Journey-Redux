-- Exact-item compatibility for the user's Content Editor summon item.
return function(ctx)
local _ENV=ctx
item_integration={id=58990,script_id=67608110,use_checks=0,description_writes=0,errors=0,status="召唤道具：适配已安装"}
local adapter=item_integration
local function current_generation()
    return alive and state.generation==generation
end
local function entities()
    local uc=rawget(_G,"usercontent")
    local db=uc and uc.database
    if not db or type(db.get_entity)~="function" then return end
    local item=db.get_entity("item_data",adapter.id)
    local script=db.get_entity("custom_script",adapter.script_id)
    return item,script
end
local function allow_use(from,to,data)
    if not current_generation() or not data or data._Id~=adapter.id or data._UseEffect~=adapter.script_id then return nil end
    local c=core()
    if not c or from~=c.properties.player or (to~=nil and to~=c.properties.player) then return nil end
    local item,script=entities()
    if not item or not script or type(script.script_func)~="function" then return nil end
    adapter.use_checks=adapter.use_checks+1
    local allowed=not active and not state.recovery and not queued and #state.spawns==0
        and not summon.current and not menu.photo_active()
    adapter.last_allowed=allowed
    return allowed
end
local function install(type_name,signature,pre,post)
    local td=sdk.find_type_definition(type_name)
    local method=td and td:get_method(signature)
    if not method then adapter.status="召唤道具：缺少接口 "..signature;adapter.errors=adapter.errors+1;return end
    sdk.hook(method,pre,post)
end
-- Preserve outer inventory/storage checks; bypass only the effect/health gate for this script item.
install("app.ItemManager","isUseEnableSub(app.Character, app.Character, app.ItemDataParam)",function(args)
    local s=thread.get_hook_storage();s.griffin_item_use=nil
    if not current_generation() then return end
    local ok,value=pcall(function()
        return allow_use(sdk.to_managed_object(args[3]),sdk.to_managed_object(args[4]),sdk.to_managed_object(args[5]))
    end)
    if not ok then adapter.errors=adapter.errors+1;adapter.status="召唤道具：使用检查失败 "..tostring(value);return end
    if value~=nil then s.griffin_item_use=value;return sdk.PreHookResult.SKIP_ORIGINAL end
end,function(ret)
    local s=thread.get_hook_storage();local value=s.griffin_item_use;s.griffin_item_use=nil
    if value~=nil and current_generation() then return sdk.to_ptr(value) end
    return ret
end)
-- Correct the final details widget, after Content Editor's generic message/name hooks.
-- All readers match a declared native argument type; never probe arbitrary pointers.
local function detail_hook(signature,reader,key)
    install("app.GUIBase.ItemWindowRef",signature,function(args)
        local s=thread.get_hook_storage();s[key]=nil
        if not current_generation() then return end
        local ok,record=pcall(function()
            if reader(args)~=adapter.id then return end
            local item=entities()
            if not item or type(item.description)~="string" then return end
            return {widget=sdk.to_managed_object(args[2]),text=item.description}
        end)
        if ok then s[key]=record else adapter.errors=adapter.errors+1 end
    end,function(ret)
        local s=thread.get_hook_storage();local record=s[key];s[key]=nil
        if record and current_generation() then
            local ok,err=pcall(function() record.widget._TxtInfo:set_Message(record.text) end)
            if ok then adapter.description_writes=adapter.description_writes+1
            else adapter.errors=adapter.errors+1;adapter.status="召唤道具：描述修正失败 "..tostring(err) end
        end
        return ret
    end)
end
local function numeric_id(args) return sdk.to_int64(args[3]) & 0xffffffff end
detail_hook("setup(System.Int32, System.Int32)",numeric_id,"griffin_detail_id_count")
detail_hook("setup(System.Int32, System.Guid, System.Guid)",numeric_id,"griffin_detail_id_guid")
detail_hook("setup(System.Int32, System.String, System.String)",numeric_id,"griffin_detail_id_text")
detail_hook("setup(app.ItemCommonParam, System.Int32, System.Boolean)",function(args)
    local data=sdk.to_managed_object(args[3]);return data and data._Id
end,"griffin_detail_param")
detail_hook("setup(app.ItemDefine.StorageData)",function(args)
    local data=sdk.to_valuetype(args[3],"app.ItemDefine.StorageData");return data and data._ItemId
end,"griffin_detail_storage")
function adapter:draw()
    if not imgui.tree_node("召唤道具适配 DEBUG") then return end
    imgui.text(self.status)
    imgui.text(string.format("道具 %d / 脚本 %d；使用检查 %d；最近放行 %s",self.id,self.script_id,self.use_checks,tostring(self.last_allowed)))
    imgui.text(string.format("描述修正 %d；接口错误 %d",self.description_writes,self.errors))
    imgui.tree_pop()
end
end
