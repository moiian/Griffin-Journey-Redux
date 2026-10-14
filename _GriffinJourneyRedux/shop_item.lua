-- Native registration for this mod's single product; no editor_shops loader required.
return function(ctx)
local _ENV=ctx
shop_item={shop_id=5,item_id=58990,stock=19,days=1,amount=9,status="巧克力商店：等待道具加载"}
local product=shop_item
local function current() return alive and state.generation==generation end
local function ready()
    local uc=rawget(_G,"usercontent");local db=uc and uc.database
    if not db or type(db.get_entity)~="function" then return false end
    local item=db.get_entity("item_data",product.item_id)
    local script=db.get_entity("custom_script",67608110)
    local data=item and item.runtime_instance
    return data and data._Id==product.item_id and data._UseEffect==67608110
        and script and type(script.script_func)=="function"
end
local function read(array)
    local entries={}
    if array then
        for index=0,array:get_size()-1 do entries[#entries+1]=array[index] end
    end
    return entries
end
local function write(shop,entries)
    local array=assert(sdk.create_managed_array("app.ItemShopBuyParam",#entries),"无法创建商品数组"):add_ref()
    for index,item in ipairs(entries) do array[index-1]=item end
    shop._BuyParams=array
    return array
end
local function configure(item)
    item._ItemId=product.item_id
    item._Stock=product.stock
    item._AddStockDays=product.days
    item._AddStockNum=product.amount
    item._ReleaseQuestId=-1;item._QuestResultNo=-1
    item._ReleaseSentimentRankBit=1;item._ReleaseTotalPay=0;item._ReleaseFlag=0
    item._IsCheckJob=false
end
function product:apply(manager)
    local shop=manager:call("getItemShopData(System.Int32)",self.shop_id)
    if not shop then self.status="巧克力商店：等待 Shop 5";return end
    local array=shop._BuyParams
    -- Revisit only when the native shop or array changes; no repeated full-list scans.
    if self.shop==shop and self.array==array then return end
    local entries=read(array)
    local found,index
    for i,item in ipairs(entries) do
        if item._ItemId==self.item_id then
            if found then self.status="巧克力商店：发现重复物品 ID，未修改列表";return end
            found,index=item,i
        end
    end
    local item=found
    if not item then
        item=assert(sdk.create_instance("app.ItemShopBuyParam"),"无法创建巧克力商品"):add_ref()
        self.created=item
    end
    configure(item)
    if index then table.remove(entries,index) end
    table.insert(entries,math.min(2,#entries+1),item)
    self.array=write(shop,entries);self.shop=shop;self.item=item
    self.status="巧克力商店：Shop 5 第2项；库存19／每天补9（原生管理）"
end
function product:tick()
    if not current() then return end
    local t=os.clock()
    if self.next_check and t<self.next_check then return end
    self.next_check=t+1
    local ok,err=pcall(function()
        if not ready() then self.status="巧克力商店：等待 Content Editor 道具与脚本";return end
        local flow=sdk.get_managed_singleton("app.MainFlowManager")
        if not flow or not flow:call("get_IsInGamePhase()") then return end
        local manager=sdk.get_managed_singleton("app.ItemManager")
        if manager then self:apply(manager) end
    end)
    if not ok then self.status="巧克力商店：添加失败 "..tostring(err) end
end
function product:shutdown()
    -- Remove only the exact object created by this generation, retaining later additions.
    if not self.created or not self.shop then return end
    local ok,err=pcall(function()
        local entries=read(self.shop._BuyParams)
        for index,item in ipairs(entries) do
            if item==self.created then table.remove(entries,index);write(self.shop,entries);break end
        end
    end)
    if not ok then self.status="巧克力商店：清理失败 "..tostring(err) end
end
end
