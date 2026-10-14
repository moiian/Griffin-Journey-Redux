-- One emergency consumable; all inventory/HP mutations happen outside item-use hooks.
return function(ctx)
local _ENV=ctx
consumables={id=58995,script_id=67608115,heal=50,status="榴莲味披萨：待使用"}
local pizza=consumables
local function current() return alive and state.generation==generation end
local function entity()
    local uc=rawget(_G,"usercontent");local db=uc and uc.database
    local item=db and db.get_entity("item_data",pizza.id)
    local script=db and db.get_entity("custom_script",pizza.script_id)
    return item and item.runtime_instance and item.runtime_instance._UseEffect==pizza.script_id
        and script and type(script.script_func)=="function"
end
function pizza:grant(owner)
    local c=core()
    assert(current() and c and owner==c.properties.player and owner:get_Valid(),"披萨发放玩家已变化")
    assert(entity(),"披萨道具或脚本未加载")
    local manager=assert(sdk.get_managed_singleton("app.ItemManager"),"物品管理器未就绪")
    manager:call("getItem(System.Int32,System.Int32,app.Character)",self.id,1,owner)
    self.status="榴莲味披萨：已请求向当前玩家发放1个"
    event("pizza_granted",{item=self.id,count=1})
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
            if not heal_ok then request.heal_error=tostring(heal_err);event("pizza_heal_failed",request.heal_error) end
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
