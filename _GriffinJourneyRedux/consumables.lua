-- One emergency consumable; all inventory/HP mutations happen outside item-use hooks.
return function(ctx)
local _ENV=ctx
consumables={id=58995,script_id=67608115,heal=50,status="榴莲味披萨：待使用"}
local pizza=consumables
local grant_signature="getItem(System.Int32, System.Int32, app.CharacterID)"
local function method(td,signature)
    return td and (td:get_method(signature) or td:get_method((signature:gsub(", ",","))))
end
local function save_record()
    if pizza.on_grant_record then pizza.on_grant_record(pizza.last_grant) end
end
local function count(manager,reader,id,player_id)
    if not reader then return nil,"getStorageData重载不可用" end
    local ok,value=pcall(function()
        local storage=reader:call(manager,id,player_id)
        if not storage or storage._ItemId~=id then return 0 end
        assert(type(storage._Num)=="number","库存数量不可读")
        return storage._Num
    end)
    if ok then return value end
    return nil,tostring(value)
end
local function current() return alive and state.generation==generation end
local function entity()
    local uc=rawget(_G,"usercontent");local db=uc and uc.database
    local item=db and db.get_entity("item_data",pizza.id)
    local script=db and db.get_entity("custom_script",pizza.script_id)
    return item and item.runtime_instance and item.runtime_instance._UseEffect==pizza.script_id
        and script and type(script.script_func)=="function"
end
function pizza:grant(owner)
    assert(not self.verification,"上一笔披萨发放尚待确认")
    self.last_grant={version=VERSION,item=self.id,script=self.script_id,amount=1,method=grant_signature,stage="checking"}
    local record=self.last_grant
    local ok,err=pcall(function()
        local c=core()
        assert(current() and c and owner==c.properties.player and owner:get_Valid(),"披萨发放玩家已变化")
        assert(entity(),"披萨道具或脚本未加载")
        local manager=assert(sdk.get_managed_singleton("app.ItemManager"),"物品管理器未就绪")
        local native=manager._ItemDataDict and manager._ItemDataDict[self.id]
        record.native_id=native and native._Id;record.native_effect=native and native._UseEffect
        assert(native and native._Id==self.id and native._UseEffect==self.script_id,"披萨未正确注入原生物品字典")
        local td=sdk.find_type_definition("app.ItemManager")
        local give=assert(method(td,grant_signature),"指定的CharacterID发放重载不可用")
        local enum=sdk.find_type_definition("app.CharacterID")
        local field=enum and enum:get_field("ch000000_00")
        local player_id=assert(field and field:get_data(),"当前玩家CharacterID枚举不可用")
        assert(finite(player_id),"玩家CharacterID不是数值")
        record.player_id=player_id
        local reader=method(td,"getStorageData(System.Int32, app.CharacterID)")
        record.before,record.before_error=count(manager,reader,self.id,player_id)
        record.stage="calling"
        -- Pin the exact REMethodDefinition and receiver; no dynamic overload dispatch.
        give:call(manager,self.id,1,player_id)
        record.stage="requested"
        self.verification={owner=owner,manager=manager,reader=reader,player_id=player_id,due=os.clock()+1,record=record}
        self.status="榴莲味披萨：已调用玩家ID发放重载，等待背包数量确认"
        if event then event("pizza_grant_requested",{item=self.id,count=1,player_id=player_id}) end
    end)
    if not ok then record.stage="failed";record.error=tostring(err);self.status="披萨发放失败："..tostring(err) end
    save_record()
    if not ok then error(err) end
end
function pizza:verify_grant()
    local verify=self.verification
    if not verify or os.clock()<verify.due then return end
    self.verification=nil
    local record=verify.record
    local c=core()
    local manager_ok,manager=pcall(sdk.get_managed_singleton,"app.ItemManager")
    if not current() or not c or c.properties.player~=verify.owner or not manager_ok or manager~=verify.manager then
        record.stage="unconfirmed";record.error="发放确认前玩家已变化"
    else
        record.after,record.after_error=count(verify.manager,verify.reader,self.id,verify.player_id)
        record.stage=type(record.before)=="number" and type(record.after)=="number" and record.after==record.before+1 and "confirmed" or "unconfirmed"
    end
    self.status=record.stage=="confirmed" and "榴莲味披萨：玩家道具栈数量已确认增加1"
        or "榴莲味披萨：未确认玩家数量增加，请查看发放LOG（不会自动重发）"
    save_record()
end
function pizza:request(owner)
    local c=core()
    if not current() or not c or owner~=c.properties.player or not owner or not owner:get_Valid() then return false,"披萨使用者不是当前玩家" end
    if self.current then return false,"披萨清理请求正在执行" end
    if menu.photo_active() then return false,"请退出照片模式" end
    self.current={owner=owner,deadline=os.time()+30,stage="waiting"}
    self.status="榴莲味披萨：请关闭物品菜单后执行"
    return true,"披萨使用请求已接受"
end
function pizza:tick()
    self:verify_grant()
    local request=self.current
    if not request then return end
    local c=core()
    if not current() or not c or c.properties.player~=request.owner then self.current=nil;return end
    if request.stage=="waiting" and os.time()>request.deadline then self.current=nil;self.status="披萨请求等待菜单超时";return end
    if menu.gameplay_paused() then return end
    local ok,err=pcall(function()
        assert(request.owner:get_Valid(),"披萨使用者已失效")
        local main=sdk.get_managed_singleton("app.MainFlowManager")
        assert(main and main:call("get_IsInGamePhase()"),"已离开游戏阶段")
        if request.stage=="waiting" then
            -- Mark before native mutation: a failure must not cause repeated healing.
            request.stage="clearing"
            local heal_ok,heal_err=pcall(function()
                if request.owner:call("get_IsDead()") then return end
                local hit=assert(request.owner:call("get_Hit()"),"回血接口未就绪")
                hit:call("recoverHp(System.Single,System.Boolean,System.Int32,System.Boolean)",self.heal,false,0,false)
            end)
            if not heal_ok then request.heal_error=tostring(heal_err);if event then event("pizza_heal_failed",request.heal_error) end end
            if summon then summon:cancel("使用榴莲味披萨") end
            operation=nil;queued=false
            stop_driver("使用榴莲味披萨",true)
            for _,r in ipairs(state.spawns) do r.delete_requested=true;r.cleanup_reason="使用榴莲味披萨" end
        end
        if state.recovery then self.status="榴莲味披萨：等待玩家与乘客恢复后清理";return end
        for _,r in ipairs(state.spawns) do if not r.deleted then delete_one(r) end end
        if #state.spawns==0 then
            self.current=nil
            self.status=request.heal_error and ("狮鹫清理完成；回血失败："..request.heal_error) or "榴莲味披萨：清理完成，已请求恢复50 HP"
        end
    end)
    if not ok then
        self.status="榴莲味披萨：执行失败 "..tostring(err)
        -- Keep a clearing request for recovery, but never repeat its healing step.
        if request.stage=="waiting" then self.current=nil end
    end
end
end
