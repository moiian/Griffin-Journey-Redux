-- Griffin Journey Redux: input
return function(ctx)
local _ENV=ctx
-- Independent HID mapping, following OJR's capture/release-gate layout (no OJR/Hotkeys dependency).
controls.rows={
    {"spawn","召唤狮鹫","None","None"},{"start","开始驾驶（长按1秒，10米内）","F","RRight"},
    {"stop","结束驾驶（长按1秒）","X","None"},{"delete","删除狮鹫","None","None"},
    {"a","起飞","Space","RDown"},
    {"rt","冲刺／2档","LShift","RTrigBottom"},{"lt","悬停／1档","LControl","LTrigBottom"},
    {"hover_up","1档上移","E","RDown"},{"hover_down","1档下移","Q","RUp"},
    {"landing","原生降落（1／2档）","G","RStickPush"},
    {"rb","冲刺爬升／2档","R","LTrigTop"},{"lb","冲刺俯冲／2档","C","RTrigTop"},
    {"left","向左","A","None"},{"right","向右","D","None"},
    {"up","向前","W","None"},{"down","向后","S","None"},
    {"preset_next","切换座位预设","None","None"},
}
controls.enums={keyboard={},gamepad={}}
controls.choices={keyboard={"None"},gamepad={"None"}}
controls.previous={}
controls.save=function()
    local ok,result=pcall(json.dump_file,settings_path,settings)
    if not ok or result==false then
        menu.save_error="设置保存失败，当前修改尚未写入文件："..tostring(result)
        status=menu.save_error
        return false
    end
    menu.save_error=nil
    return true
end
controls.enum=function(type_name,target,prefix)
    local def=sdk.find_type_definition(type_name)
    if not def then return end
    if def.get_fields then
        for _,field in ipairs(def:get_fields()) do
            if field:is_static() then
                local value,name=field:get_data(nil),field:get_name()
                if finite(value) and value>0 and value==math.floor(value) and name~="All" then target[(prefix or "")..name]=value end
            end
        end
    else -- Minimal/mock runtimes: resolve only concrete defaults.
        for _,row in ipairs(controls.rows) do
            local name=type_name=="via.hid.KeyboardKey" and row[3] or row[4]
            local field=def:get_field(name);local value=field and field:get_data(nil)
            if finite(value) and value>0 then target[(prefix or "")..name]=value end
        end
    end
end
controls.enum("via.hid.KeyboardKey",controls.enums.keyboard)
controls.enum("via.hid.MouseButton",controls.enums.keyboard,"Mouse:")
controls.enum("via.hid.GamePadButton",controls.enums.gamepad)
for device,values in pairs(controls.enums) do
    for name in pairs(values) do controls.choices[device][#controls.choices[device]+1]=name end
    table.sort(controls.choices[device],function(a,b) if a==b then return false end;if a=="None" then return true end;if b=="None" then return false end;return a<b end)
end
settings.bindings={}
local migrate_bindings=not loaded_settings or loaded_settings.flight_bindings_revision~=1
local old_defaults={rb={keyboard="E",gamepad="RTrigTop"},lb={keyboard="Q",gamepad="LTrigTop"}}
settings.flight_bindings_revision=1
settings.boarding_bindings_revision=1
for _,row in ipairs(controls.rows) do
    settings.bindings[row[1]]={}
    for i,device in ipairs({"keyboard","gamepad"}) do
        local stored=loaded_settings and loaded_settings.bindings and loaded_settings.bindings[row[1]]
        stored=type(stored)=="table" and stored[device]
        -- First upgrade enables the requested B binding only when no custom pad key exists.
        if row[1]=="start" and device=="gamepad" and (not loaded_settings or loaded_settings.boarding_bindings_revision~=1) and stored=="None" then stored=nil end
        -- Retain other custom bindings and explicit None.
        if migrate_bindings and old_defaults[row[1]] and stored==old_defaults[row[1]][device] then stored=nil end
        settings.bindings[row[1]][device]=(stored=="None" or controls.enums[device][stored]) and stored or row[i+2]
    end
end
masks={a=1,rt=2,lt=4,rb=8,lb=16,hover_up=32,hover_down=64,landing=128} -- Logical actions; physical enum values remain runtime-resolved above.
controls.device=function(singleton_name,type_name,method)
    local singleton=sdk.get_native_singleton(singleton_name)
    local def=sdk.find_type_definition(type_name)
    return singleton and def and sdk.call_native_func(singleton,def,method)
end
function read_pad()
    local pad=controls.device("via.hid.Gamepad","via.hid.GamePad","get_MergedDevice")
    local kb=controls.device("via.hid.Keyboard","via.hid.Keyboard","get_Device")
    local mouse=controls.device("via.hid.Mouse","via.hid.Mouse","get_Device")
    assert(pad or kb,"未检测到手柄或键盘")
    local bits=pad and pad:call("get_Button") or 0
    local mbits=mouse and mouse:call("get_Button") or 0
    assert(finite(bits) and finite(mbits),"输入按键不可用")
    local function down(device,name)
        local code=controls.enums[device][name]
        if not code or code==0 or name=="None" then return false end
        if device=="gamepad" then return (bits & code)==code end
        if name:sub(1,6)=="Mouse:" then return (mbits & code)==code end
        return kb and kb:call("isDown",code)==true or false
    end
    local current={}
    for name,binding in pairs(settings.bindings) do current[name]=down("keyboard",binding.keyboard) or down("gamepad",binding.gamepad) end
    local suppressed=false
    if controls.capture then
        local capture,pressed=controls.capture,{}
        for _,name in ipairs(controls.choices[capture.device]) do pressed[name]=down(capture.device,name) end
        if capture.previous then
            for _,name in ipairs(controls.choices[capture.device]) do
                if pressed[name] and not capture.previous[name] then
                    settings.bindings[capture.action][capture.device]=name
                    controls.capture=nil;controls.release_gate=true;controls.save();break
                end
            end
        end
        capture.previous=pressed;suppressed=true
    end
    if controls.release_gate then
        local any=false
        for device,names in pairs(controls.choices) do
            for _,name in ipairs(names) do if down(device,name) then any=true;break end end
        end
        if not any then controls.release_gate=false end
        suppressed=true
    end
    local logical,edges=0,{}
    for name,value in pairs(current) do
        edges[name]=not suppressed and value and controls.previous[name]~=nil and not controls.previous[name]
        if not suppressed and value and masks[name] then logical=logical|masks[name] end
    end
    controls.previous=current
    local axis=pad and pad:call("get_AxisL()") or {x=0,y=0}
    assert(axis and finite(axis.x) and finite(axis.y),"摇杆不可用")
    local x,y=math.max(-1,math.min(1,axis.x)),math.max(-1,math.min(1,axis.y))
    local length=math.sqrt(x*x+y*y)
    if length<=0.2 then x,y=0,0 else local scale=math.min(1,(length-0.2)/0.8)/length;x,y=-x*scale,y*scale end
    -- Slow-flight pad polarity follows the user's in-game direction check.
    -- Keyboard movement retains ordinary A-left / D-right independently of sprint's mapping.
    local hover_x=math.max(-1,math.min(1,x+(current.right and 1 or 0)-(current.left and 1 or 0)))
    x=math.max(-1,math.min(1,x+(current.left and 1 or 0)-(current.right and 1 or 0)))
    y=math.max(-1,math.min(1,y+(current.up and 1 or 0)-(current.down and 1 or 0)))
    if suppressed then x,y,hover_x=0,0,0 end
    local rx,ry,right_error=0,0,nil
    local hover_camera_input=active and active.controls_active and not active.external_control
        and active.gear==1 and active.hover_motion and settings.hover_camera_yaw_speed>0
    if (settings.camera_auto_yaw or hover_camera_input) and pad then
        local ok,right=pcall(function() return pad:call("get_AxisR()") end)
        if ok and right and finite(right.x) and finite(right.y) then rx,ry=right.x,right.y else right_error="右摇杆读取失败" end
    end
    if suppressed then rx,ry,right_error=0,0,nil end
    return {x=x,y=y,hover_x=hover_x,buttons=logical,rx=rx,ry=ry,right_error=right_error,edges=edges,down=current}
end

-- Fresh press, continuous unpaused hold, one attempt until release (including rejection).
controls.holds={}
function controls.hold_actions(result,blocked)
    local fired
    local t=now()
    for _,name in ipairs({"stop","start"}) do
        local h=controls.holds[name] or {};controls.holds[name]=h
        if blocked or not finite(t) then
            h.started=nil;h.consumed=true
        elseif not result.down[name] then
            h.started=nil;h.consumed=false
        elseif result.edges[name] then
            h.started=t;h.consumed=false
        elseif h.started and not h.consumed then
            if t<h.started then h.started=nil;h.consumed=true
            elseif t-h.started>=1 then h.consumed=true;fired=fired or name end
        end
    end
    if fired then
        -- Shared bindings must not start and stop with the same physical hold.
        for _,name in ipairs({"stop","start"}) do
            if result.down[name] then controls.holds[name].consumed=true end
        end
    end
    return fired
end

function held(bits, mask) return (bits & mask) == mask end
function action_phase_allowed(phase,flying,ground)
    return not menu.block_cross_phase or phase==nil
        or phase=="air" and flying and not ground
        or phase=="ground" and ground and not flying
end
function set_intent(d, node, mode)
    local phase=mode=="taking_off" and "ground"
        or (mode=="hover" or mode=="dash" or mode=="landing") and "air" or nil
    d.intent = {node = node, mode = mode,phase=phase}
end
function dispatch(d)
    local c=core()
    if not c or menu.gameplay_paused() or not d.intent or d.pending or now() - d.last_request < 0.35 then return end
    local intent = d.intent
    d.pending = true
    run_once(function()
        if not alive or active ~= d or d.intent ~= intent then d.pending = false; return end
        local c=core()
        if c and menu.gameplay_paused() then d.pending=false;return end -- keep intent until resume
        local ok, err = pcall(function()
            local ch = validate_spawn(d.spawn)
            -- Recheck at native submission: the phase may change while queued.
            if intent.phase and menu.block_cross_phase and not action_phase_allowed(intent.phase,
                ch:call("get_IsFlight()"),ch:call("get_IsGround()")) then
                d.intent=nil
                if d.control_node==intent.node then d.control_node=nil end
                if intent.mode=="taking_off" and d.mode=="taking_off" then
                    d.mode="control";d.auto_hover=false
                end
                return
            end
            assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
            local manager = ch:call("get_ActionManager()")
            assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
            event("action_request", {node = intent.node, mode = intent.mode})
            d.last_request = now()
            d.action_transition={node=intent.node,from=d.native_action,at=d.last_request}
            assert(ai_takeover:tick(d),"方向6组件恢复失败")
            manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)", 10, intent.node, 0)
            request_camera_follow_check()
            d.mode = intent.mode
            d.intent = nil
            if d.mode == "taking_off" then d.takeoff_at = now(); d.saw_takeoff = false; d.auto_hover = intent.auto_hover;d.takeoff_play_started=false;d.takeoff_elapsed=0;d.takeoff_timer_last=now();d.takeoff_choice=nil;d.takeoff_stop_requested=nil end
            event("action_returned", intent.node)
        end)
        d.pending = false
        if not ok then stop_driver("Action request failed"); failed("动作请求失败", err) end
    end)
end
function apply_player_freeze(d, freeze)
    assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player FSM binding changed")
    local desired = d.original_fsm
    if freeze then desired = false end
    local current = d.fsm:call("get_Enabled()")
    assert(type(current) == "boolean", "Cannot read player FSM")
    if current ~= desired then
        d.fsm_touched = true -- retain recovery even if the setter raises after writing
        d.fsm:call("set_Enabled(System.Boolean)", desired)
    end
    assert(d.fsm:call("get_Enabled()") == desired, "Player FSM mode readback mismatch")
    d.freeze_requested = freeze
    event("player_fsm_mode", {freeze_requested=freeze, enabled=desired, original_enabled=d.original_fsm})
end
freeze_revision = 0
function change_player_freeze(freeze)
    freeze_revision = freeze_revision + 1
    local revision, d = freeze_revision, active
    if not d then
        settings.freeze_player = freeze
        pcall(json.dump_file, settings_path, settings)
        return
    end
    run_once(function()
        if not alive or active ~= d or revision ~= freeze_revision then return end
        local ok, err = pcall(function()
            validate_spawn(d.spawn)
            apply_player_freeze(d, freeze)
            settings.freeze_player = freeze
            pcall(json.dump_file, settings_path, settings)
        end)
        if not ok then stop_driver("FSM 对照切换失败"); failed("FSM 对照切换失败", err) end
    end)
end

-- Bound to the retained spawn reference; free-player observations do not move the player.
end
