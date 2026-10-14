-- Scoped HUD rendering, independent of third-party HUD controllers.
return function(ctx)
local _ENV=ctx
local defaults={enabled=true,on_summon=true,on_driving=true,on_exit=true,on_hover=true,
    skills=true,pawn_orders=true,player_hp=true,player_stamina=true,player_status=true,
    boss_hp=true,pawn_status=true,minimap=true}
menu.default_seed.hud_config=menu.clone(defaults)
settings.hud_config=menu.clone(defaults)
local saved=loaded_settings and loaded_settings.hud_config
if type(saved)=="table" then
    for key in pairs(defaults) do if type(saved[key])=="boolean" then settings.hud_config[key]=saved[key] end end
end
hud={time=0,pending={},status="隐藏界面：待机"}
local self=hud
local nodes={ui010201="skills",ui020401="pawn_orders",ui020501="boss_hp",ui022601="pawn_status",ui020301="minimap"}
local panels={{key="player_hp",field="PnlHpLine",parent=true},
    {key="player_stamina",field="PnlStLine",parent=true},{key="player_status",field="PnlStatusIconAll"}}
local function current() return alive and state.generation==generation and not self.stopped end
local function valid(object) return object and object:get_Valid()==true end
function self:clear()
    self.owner=nil;self.summon_until=nil;self.summon_token=nil;self.exit_until=nil
    self.exit_ticket=nil;self.hover=false;self.hiding=false;self.next_poll=nil
end
function self:advance()
    local t=now()
    if finite(t) then
        if self.last and t<self.last then self:clear() end
        if self.last and t>=self.last and not menu.gameplay_paused() then self.time=self.time+t-self.last end
        self.last=t
    end
end
function self:notify_summon(owner,token)
    if not current() or not core() or core().properties.player~=owner then return end
    self:advance()
    if self.owner~=owner then self:clear() end
    self.owner=owner;self.summon_until=self.time+20;self.summon_token=token
end
function self:cancel_summon(token)
    if self.summon_token==token then self.summon_until=nil;self.summon_token=nil end
end
function self:notify_exit(d)
    if not current() or not d or not core() or core().properties.player~=d.player then return end
    self:advance()
    if self.owner~=d.player then self:clear() end
    self.owner=d.player;self.exit_until=self.time+10;self.next_poll=nil;self.hover=false
    local r=d.spawn;local result=r and r.result
    self.exit_ticket=result and {spawn=r,result=result,ch=result.chara,go=result.go,owner=d.player} or nil
end
local function any_content(cfg)
    for _,key in ipairs({"skills","pawn_orders","player_hp","player_stamina","player_status","boss_hp","pawn_status","minimap"}) do
        if cfg[key] then return true end
    end
    return false
end
function self:poll_hover()
    local ticket=self.exit_ticket
    if not ticket or self.next_poll and self.time+0.000001<self.next_poll then return end
    self.next_poll=self.time+0.1;self.hover=false
    local ok,hovering,retired=pcall(function()
        local r=ticket.spawn
        local retained=false;for _,entry in ipairs(state.spawns) do if entry==r then retained=true;break end end
        if not retained or r.deleted or r.delete_requested or r.sinking or r.owner~=ticket.owner
            or r.result~=ticket.result or r.result.chara~=ticket.ch or r.result.go~=ticket.go
            or not valid(ticket.ch) or not valid(ticket.go) then return false,true end
        local ch=ticket.ch
        if ch:call("get_GameObject()")~=ticket.go then return false,true end
        if ch:call("get_IsDead()") or ch:call("get_IsFallDead()") or ch:call("get_IsDown()")
            or ch:call("get_IsGround()") or not ch:call("get_IsFlight()") then return false,true end
        local manager=ch:call("get_ActionManager()")
        if not manager or manager:call("get_GameObject()")~=ticket.go then return false,true end
        local info=manager:get_field("CurrentAction")
        return info and info:get_field("Name")=="Ch253HoverWaitHoHomingHeight",false
    end)
    if ok then
        self.hover=hovering==true
        if retired then self.exit_ticket=nil end
    else self.status="隐藏界面：悬停状态暂不可读" end
end
function self:tick()
    self:restore_all()
    self:advance();self.hiding=false
    if not current() then self:clear();return end
    local c=core();local owner=c and c.properties.player
    local driving=active and active.player==owner and active.spawn and active.spawn.owner==owner
    if driving and self.owner~=owner then self:clear();self.owner=owner end
    if not owner or self.owner~=owner then self:clear();return end
    local cfg=settings.hud_config
    if not cfg or not cfg.enabled or not any_content(cfg) then self.status="隐藏界面：关闭";return end
    local ok,in_game=pcall(function()
        if not valid(owner) then return false end
        local main=sdk.get_managed_singleton("app.MainFlowManager")
        return main and main:call("get_IsInGamePhase()")
    end)
    if not ok or not in_game then self:clear();return end
    if menu.gameplay_paused() then return end
    if driving then self.exit_ticket=nil;self.hover=false
    elseif cfg.on_hover then self:poll_hover() else self.hover=false end
    local summon_window=cfg.on_summon and self.summon_until and self.time+0.000001<self.summon_until
    local exit_window=cfg.on_exit and self.exit_until and self.time+0.000001<self.exit_until
    self.hiding=self.available and (cfg.on_driving and driving or summon_window or exit_window or cfg.on_hover and self.hover) and true or false
    self.status=self.hiding and "隐藏界面：生效" or "隐藏界面：待机"
    if not active and not self.exit_ticket and (not self.summon_until or self.time>=self.summon_until)
        and (not self.exit_until or self.time>=self.exit_until) then self:clear() end
end
local function panel_for(component,spec)
    local panel=component:get_field(spec.field)
    if panel and spec.parent then panel=panel:call("get_Parent()") end
    return panel
end
function self:restore_for(element)
    local items=self.pending[element]
    if not items then return end
    self.pending[element]=nil
    for _,item in ipairs(items) do
        local ok,err=pcall(function()
            if valid(element) and valid(item.go) and valid(item.component) and valid(item.panel)
                and element:call("get_GameObject()") == item.go
                and item.go:call("getComponent(System.Type)",item.kind)==item.component
                and panel_for(item.component,item.spec)==item.panel and item.panel:call("get_Visible()")==false then
                item.panel:call("set_Visible(System.Boolean)",true)
            end
        end)
        if not ok then self.pending[element]=items;self.status="隐藏界面：面板恢复待重试／"..tostring(err) end
    end
end
function self:restore_all()
    for element in pairs(self.pending) do self:restore_for(element) end
end
local status_type
function self:before_gui(element)
    if not current() or not self.hiding or not self.owner or not core() or core().properties.player~=self.owner then return true end
    local cfg=settings.hud_config
    if not cfg.enabled then return true end
    local go=element:call("get_GameObject()")
    if not go then return true end
    local name=go:call("get_Name()")
    local key=nodes[name]
    if key then return not cfg[key] end
    if name~="ui020901" then return true end
    if cfg.player_hp and cfg.player_stamina and cfg.player_status then return false end
    if not cfg.player_hp and not cfg.player_stamina and not cfg.player_status then return true end
    self:restore_for(element)
    if self.pending[element] then return true end
    status_type=status_type or sdk.typeof("app.ui020901")
    local component=go:call("getComponent(System.Type)",status_type)
    if not component then return true end
    local items={};self.pending[element]=items
    for _,spec in ipairs(panels) do
        if cfg[spec.key] then
            local panel=panel_for(component,spec)
            if panel and panel:call("get_Visible()") == true then
                items[#items+1]={go=go,component=component,kind=status_type,panel=panel,spec=spec}
                panel:call("set_Visible(System.Boolean)",false)
            end
        end
    end
    return true
end
function self:draw()
    if not imgui.tree_node("隐藏界面") then return end
    local cfg=menu.draft.hud_config
    local function toggle(key,label)
        local changed,value=menu.toggle(label,cfg[key])
        if changed then cfg[key]=value;menu.changed() end
    end
    toggle("enabled","启用隐藏界面")
    if imgui.tree_node("隐藏时机") then
        for _,row in ipairs({{"on_summon","召唤后20秒内"},{"on_driving","驾驶狮鹫时"},
            {"on_exit","退出驾驶后10秒内"},{"on_hover","退出后狮鹫仍在悬停时"}}) do toggle(row[1],row[2]) end
        imgui.tree_pop()
    end
    if imgui.tree_node("隐藏内容") then
        for _,row in ipairs({{"skills","玩家职业技能栏"},{"pawn_orders","随从命令栏"},
            {"player_hp","玩家血条"},{"player_stamina","玩家耐力条"},{"player_status","玩家状态图标"},
            {"boss_hp","BOSS血条"},{"pawn_status","随从名字和HP条"},{"minimap","小地图"}}) do toggle(row[1],row[2]) end
        imgui.tree_pop()
    end
    if not self.available then imgui.text("当前REFramework缺少界面绘制回调，隐藏未启用。") end
    imgui.tree_pop()
end
self.available=type(re.on_pre_gui_draw_element)=="function" and type(re.on_gui_draw_element)=="function"
if self.available then
    re.on_pre_gui_draw_element(function(element)
        local ok,draw=pcall(self.before_gui,self,element)
        if ok then return draw end
        self:restore_for(element);self.status="隐藏界面：跳过不可用面板／"..tostring(draw)
        return true
    end)
    re.on_gui_draw_element(function(element) self:restore_for(element) end)
    re.on_application_entry("PrerenderGUI",function() self:tick() end)
    re.on_application_entry("RenderGUI",function() self:restore_all() end)
end
re.on_script_reset(function() self.stopped=true;self:restore_all();self:clear() end)
end
