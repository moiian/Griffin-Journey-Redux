-- Griffin Flight Beta 0.1.0. Requires installed NickCore + EnemySpawner + run_once.
-- Separate from GriffinMountExperiment; no OJR/LMD/NickCore files are changed.
local VERSION = "0.1.0-beta"
local state = rawget(_G, "GriffinFlightBetaState") or {spawns = {}}
_G.GriffinFlightBetaState = state
state.spawns = state.spawns or {}
local generation = {}
state.generation = generation
local alive, queued = true, false
local operation = nil
local active, camera_state = nil, nil
local status = "先生成狮鹫，再开始驾驶。"
local hooks_ready, hooks_tried, friend_value = false, false, nil
local masks = nil
local input = {x = 0, y = 0, buttons = 0}
local settings = {distance = 30, fov = 90}
local settings_path = "GriffinFlightBeta_Settings.json"
local log_id = os.date("!%Y%m%dT%H%M%SZ") .. "_" .. math.floor(os.clock() * 1000)
local part, last_flush, next_sample = 1, -math.huge, 0
local journal = {version = VERSION, events = {}, samples = {}}
local stop_driver, delete_one

local function core()
    local c = rawget(_G, "NickCore")
    if c and c.properties and c.object and c.enemySpawner and type(run_once) == "function" then return c end
end
local function now()
    local c = core()
    return c and c.properties.gameTime or 0
end
local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function vector(v)
    assert(v and finite(v.x) and finite(v.y) and finite(v.z), "Invalid position")
    return {x = v.x, y = v.y, z = v.z}
end
local function flush()
    local ok, result = pcall(json.dump_file, "GriffinFlightBeta_" .. log_id .. "_" .. part .. ".json", journal)
    last_flush = now()
    if not ok or result == false then log.error("[GriffinFlightBeta] Log save failed") end
    return ok and result ~= false
end
local function rotate()
    if #journal.events < 400 and #journal.samples < 600 then return end
    if flush() then
        part = part + 1
        journal = {version = VERSION, events = {}, samples = {}}
    end
end
local function event(name, detail)
    rotate()
    if #journal.events < 450 then
        journal.events[#journal.events + 1] = {name = name, detail = detail, time = now()}
    end
    flush()
end
local function failed(label, err)
    status = label .. "：" .. tostring(err)
    event("error", status)
    log.error("[GriffinFlightBeta] " .. status)
end
if type(json.load_file) == "function" then
    local ok, saved = pcall(json.load_file, settings_path)
    if ok and type(saved) == "table" then
        if finite(saved.distance) then settings.distance = math.max(0, math.min(80, saved.distance)) end
        if finite(saved.fov) then settings.fov = math.max(40, math.min(120, saved.fov)) end
    end
end

local function aggro_clear()
    local cfg = package.loaded["NicksDevtools/Config"]
    return not (type(cfg) == "table" and (cfg.disableAggro or cfg.forceAggro))
end
local function pair_is_owned(a, b)
    if not alive or state.generation ~= generation then return false end
    for _, r in ipairs(state.spawns) do
        local ch = r.result and r.result.chara
        if r.friend and ch then
            for _, p in ipairs(r.party or {}) do
                if (a == ch and b == p) or (b == ch and a == p) then return true end
            end
        end
    end
    return false
end
local function install_hooks()
    if hooks_ready then return end
    assert(not hooks_tried, "Friend hook initialization failed; reset scripts")
    local enum = sdk.find_type_definition("app.Character.BattleRelationship")
    friend_value = assert(enum and enum:get_field("Friend"), "Friend enum unavailable"):get_data()
    assert(finite(friend_value), "Invalid Friend enum")
    local ptr = sdk.to_ptr(friend_value)
    local c = sdk.find_type_definition("app.Character")
    local h = sdk.find_type_definition("app.BattleRelationshipHolder")
    local cm = c and c:get_method("getBattleRelationshipTo(app.Character)")
    local hm = h and h:get_method("getRelationshipFromTo(app.Character, app.Character)")
    assert(cm and hm, "Friend methods unavailable")
    hooks_tried = true
    local function attach(method, i, j)
        sdk.hook(method, function(args)
            thread.get_hook_storage().griffin_flight_beta_friend = pair_is_owned(
                sdk.to_managed_object(args[i]), sdk.to_managed_object(args[j]))
        end, function(ret)
            if alive and thread.get_hook_storage().griffin_flight_beta_friend then return ptr end
            return ret
        end)
    end
    attach(cm, 2, 3)
    attach(hm, 3, 4)
    hooks_ready = true
end
local function capture_party(c, player)
    assert(aggro_clear(), "请关闭 NicksDevtools 的 Disable Aggro / Force Aggro")
    local party = c.object.get_party()
    assert(type(party) == "table" and party[1] == player, "Party unavailable")
    return party
end
local function validate_spawn(r)
    local c = assert(core(), "NickCore unavailable")
    assert(c.properties.player == r.owner and not c.properties.isPaused, "Player changed or game paused")
    local result = r.result
    assert(result and result.go and result.chara, "等待狮鹫生成完成")
    assert(result.go:get_Valid() and result.chara:get_Valid(), "Griffin no longer valid")
    assert(result.chara:get_CharaIDString() == "ch253000_00"
        and result.chara:call("get_GameObject()") == result.go, "Griffin reference mismatch")
    assert(r.friend and aggro_clear(), "Friend override unavailable")
    for _, member in ipairs(r.party) do
        assert(member:get_Valid(), "Party member no longer valid")
        assert(result.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
            and member:call("getBattleRelationshipTo(app.Character)", result.chara) == friend_value,
            "Party relationship changed")
    end
    return result.chara
end
local function owned_player(d, require_current)
    if require_current and (not core() or core().properties.player ~= d.player) then return false end
    if not d.player:get_Valid() or not d.player_go:get_Valid() then return false end
    return d.player:call("get_GameObject()") == d.player_go
        and d.player:call("get_Transform()") == d.transform
        and d.player:get_field("<PosRotContext>k__BackingField") == d.context
        and d.player:get_field("<AdjustTerrain>k__BackingField") == d.terrain
        and d.terrain.MainCharacterController == d.controller
        and d.player:get_field("<FallInfo>k__BackingField") == d.fall
end
local function player_fsm(player)
    local manager = player:call("get_ActionManager()")
    return manager and manager.Fsm
end
local function sync_player(d)
    local pos = d.transform:call("get_UniversalPosition()")
    d.context:call("setPos(via.Position)", pos)
    d.fall:call("resetBaseHeight(via.Position)", pos)
    d.fall:call("resetFallHeight()")
    d.controller:call("warp()")
end
local function restore_camera()
    local s = camera_state
    if not s then return end
    camera_state = nil
    local ok, err = pcall(function()
        if sdk.get_managed_singleton("app.CameraManager") == s.manager
            and math.abs(s.manager._DistanceOffset - s.last_distance) < 0.001 then
            s.manager._DistanceOffset = s.distance
        end
        if sdk.get_primary_camera() == s.camera
            and math.abs(s.camera:call("get_FOV") - s.last_fov) < 0.001 then
            s.camera:call("set_FOV", s.fov)
        end
    end)
    if not ok then event("camera_restore_error", tostring(err)) end
end
stop_driver = function(reason)
    operation = nil
    queued = false
    local d = active or state.recovery
    active = nil
    input = {x = 0, y = 0, buttons = 0}
    restore_camera()
    if not d then return true end
    d.intent = nil -- queued native action callbacks must see that driving has ended
    local errors = {}
    if d.moved then
        local ok, err = pcall(function()
            if owned_player(d, true) then
                d.transform:call("set_UniversalPosition(via.Position)", d.original_position)
                sync_player(d)
            end
            d.moved = false
        end)
        if not ok then errors[#errors + 1] = "位置恢复 " .. tostring(err) end
    end
    if d.fsm_touched then
        local ok, err = pcall(function()
            if d.player:get_Valid() and player_fsm(d.player) == d.fsm then
                d.fsm:call("set_Enabled(System.Boolean)", d.original_fsm)
                d.fsm_touched = false
            elseif not d.player:get_Valid() then
                d.fsm_touched = false
            else
                error("Player FSM instance changed; saved FSM was not written")
            end
        end)
        if not ok then errors[#errors + 1] = "FSM恢复 " .. tostring(err) end
    end
    state.recovery = (#errors > 0) and d or nil
    status = #errors > 0 and ("驾驶已停止，请再点结束驾驶恢复：" .. table.concat(errors, "; "))
        or "驾驶已结束，玩家已恢复。"
    event("driver_stopped", {reason = reason, errors = errors})
    return #errors == 0
end

local function read_pad()
    local singleton = sdk.get_native_singleton("via.hid.Gamepad")
    local def = sdk.find_type_definition("via.hid.GamePad")
    local device = singleton and def and sdk.call_native_func(singleton, def, "get_MergedDevice")
    assert(device, "手柄未连接")
    if not masks then
        local enum = sdk.find_type_definition("via.hid.GamePadButton")
        masks = {}
        for name, field in pairs({a = "RDown", rt = "RTrigBottom", lt = "LTrigBottom"}) do
            local f = enum and enum:get_field(field)
            local n = f and f:get_data(nil)
            assert(finite(n) and n > 0 and n == math.floor(n), "Gamepad button unavailable: " .. field)
            masks[name] = n
        end
    end
    local axis, bits = device:call("get_AxisL()"), device:call("get_Button")
    assert(axis and finite(axis.x) and finite(axis.y) and finite(bits) and bits == math.floor(bits), "Invalid gamepad input")
    local x, y = math.max(-1, math.min(1, axis.x)), math.max(-1, math.min(1, axis.y))
    local length = math.sqrt(x*x + y*y)
    if length <= 0.2 then x, y = 0, 0
    else local scale = math.min(1, (length - 0.2)/0.8)/length; x, y = -x*scale, y*scale end
    return {x = x, y = y, buttons = bits}
end
local function held(bits, mask) return (bits & mask) == mask end
local function set_intent(d, node, mode)
    d.intent = {node = node, mode = mode}
end
local function dispatch(d)
    if not d.intent or d.pending or now() - d.last_request < 0.35 then return end
    local intent = d.intent
    d.pending = true
    run_once(function()
        if not alive or active ~= d or d.intent ~= intent then d.pending = false; return end
        local ok, err = pcall(function()
            local ch = validate_spawn(d.spawn)
            assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
            local manager = ch:call("get_ActionManager()")
            assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
            event("action_request", {node = intent.node, mode = intent.mode})
            d.last_request = now()
            manager:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)", 10, intent.node, 0)
            d.mode = intent.mode
            d.intent = nil
            if d.mode == "taking_off" then d.takeoff_at = now(); d.saw_takeoff = false end
            event("action_returned", intent.node)
        end)
        d.pending = false
        if not ok then stop_driver("Action request failed"); failed("动作请求失败", err) end
    end)
end
local function start_driver()
    if active or state.recovery or queued then return end
    if not core() then status = "等待 NickCore 加载。"; return end
    local r = state.spawns[#state.spawns]
    if not r then status = "请先生成狮鹫。"; return end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        local ok, err = pcall(function()
            local c = assert(core(), "等待 NickCore 加载")
            r.party = capture_party(c, r.owner)
            validate_spawn(r)
            local bus = rawget(_G, "DD2_OxcartControl")
            assert(not bus or not bus.owner, "请先结束牛车驾驶")
            local player = r.owner
            local terrain = player:get_field("<AdjustTerrain>k__BackingField")
            local d = {spawn = r, player = player, player_go = player:call("get_GameObject()"),
                transform = player:call("get_Transform()"), context = player:get_field("<PosRotContext>k__BackingField"),
                terrain = terrain, controller = terrain and terrain.MainCharacterController,
                fall = player:get_field("<FallInfo>k__BackingField"), fsm = player_fsm(player),
                mode = "ground", last_request = -math.huge, started = now(), pending = false}
            assert(d.transform and d.context and d.controller and d.fall and d.fsm, "Player interfaces unavailable")
            local ft = d.fsm:get_type_definition()
            assert(ft:get_method("get_Enabled()") and ft:get_method("set_Enabled(System.Boolean)"), "FSM Enabled interface unavailable")
            d.original_position = d.transform:call("get_UniversalPosition()")
            d.original_fsm = d.fsm:call("get_Enabled()")
            assert(d.original_position and type(d.original_fsm) == "boolean", "Cannot capture player state")
            input = read_pad()
            d.previous_buttons = input.buttons -- holding A/RT on enable is not a fresh press
            active = d
            d.fsm_touched = true
            event("fsm_freeze", {original_enabled = d.original_fsm})
            d.fsm:call("set_Enabled(System.Boolean)", false)
            if r.result.chara:call("get_IsFlight()") then
                set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            end
            status = "驾驶中：A 起飞，RT 冲刺，LT 悬停。"
            event("driver_started", {ahead = 20, lateral = 12, vertical = 10})
        end)
        if not ok then
            if active then stop_driver("Start failed") end
            failed("未能开始驾驶", err)
        end
    end)
end

local function tick_driver()
    local d = active
    if not d or not alive then return end
    local c = core()
    if not c or c.properties.isPaused or now() < d.started then stop_driver("游戏暂停或上下文变化"); return end
    local ok, err = pcall(function()
        local ch = validate_spawn(d.spawn)
        local bus = rawget(_G, "DD2_OxcartControl")
        assert(not bus or not bus.owner, "OJR owns the player")
        assert(owned_player(d, true) and player_fsm(d.player) == d.fsm, "Player binding changed")
        local tr = ch:call("get_Transform()")
        local pos, q = vector(tr:call("get_Position()")), tr:call("get_Rotation()")
        assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w), "Invalid Griffin rotation")
        local norm = math.sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w)
        assert(norm > 0.0001, "Invalid Griffin rotation length")
        local qx,qy,qz,qw = q.x/norm,q.y/norm,q.z/norm,q.w/norm
        local fx,fz = 2*(qx*qz + qw*qy), 1-2*(qx*qx+qy*qy)
        local length = math.sqrt(fx*fx+fz*fz)
        assert(length > 0.2, "Griffin is too vertical")
        fx,fz = fx/length,fz/length
        local target = {x=pos.x+fx*20+fz*input.x*12, y=pos.y+input.y*10,
            z=pos.z+fz*20-fx*input.x*12}
        d.moved = true
        d.transform:call("set_Position(via.vec3)", Vector3f.new(target.x,target.y,target.z))
        sync_player(d)
        local flying, ground = ch:call("get_IsFlight()"), ch:call("get_IsGround()")
        local manager = ch:call("get_ActionManager()")
        assert(manager and manager:call("get_GameObject()") == d.spawn.result.go, "ActionManager mismatch")
        local info = manager:get_field("CurrentAction")
        local action_name = info and info:get_field("Name")
        local pressed = input.buttons & (~d.previous_buttons)
        d.previous_buttons = input.buttons
        if d.mode == "taking_off" then
            if action_name == "Ch253TakeoffBackJump" then d.saw_takeoff = true end
            if flying and action_name ~= "Ch253TakeoffBackJump" and not d.intent then
                set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            elseif ground and not flying and d.saw_takeoff and action_name ~= "Ch253TakeoffBackJump" then
                d.mode = "ground"
            end
        end
        if held(pressed, masks.a) and ground and not flying and not d.pending then
            set_intent(d, "Ch253TakeoffBackJump", "taking_off")
        elseif flying and d.mode ~= "taking_off" then
            if held(pressed, masks.lt) then set_intent(d, "Ch253HoverWaitHoHomingHeight", "hover")
            elseif held(pressed, masks.rt) then set_intent(d, "Ch253WrapAroundStartLoop", "dash") end
        end
        dispatch(d)
        d.trace = {griffin = pos, player = vector(d.transform:call("get_Position()")), target = target,
            physical = vector(d.controller:call("get_Position()")), flight = flying, ground = ground,
            action = tostring(action_name), mode = d.mode, stick = {x=input.x,y=input.y}}
    end)
    if not ok then stop_driver("驾驶检查或位置同步失败"); failed("驾驶已停止", err) end
end

local function spawn()
    if queued or #state.spawns > 0 or state.recovery then return end
    if not core() then status = "等待 NickCore 加载。"; return end
    local token = {}
    operation = token
    queued = true
    run_once(function()
        if operation ~= token then return end
        operation = nil
        queued = false
        if not alive then return end
        local ok, err = pcall(function()
            local c = assert(core(), "等待 NickCore 加载")
            assert(c.properties.player and not c.properties.isPaused, "请进入游戏")
            install_hooks()
            local r = {owner = c.properties.player, party = capture_party(c,c.properties.player), friend = true}
            -- NickCore returns a mutable instance-reference table; never search by Character ID.
            r.result = c.enemySpawner.spawn_enemy("Griffin", nil, true)
            assert(type(r.result) == "table", "Spawn interface returned no reference table")
            state.spawns[#state.spawns+1] = r
            status = "正在生成狮鹫并设置友方……"
            event("spawn_requested", "NickCore Griffin; ThinkStop requested; exact returned reference")
        end)
        if not ok then failed("生成失败", err) end
    end)
end
delete_one = function(r)
    if r.destroy_queued then return end
    local result = r.result
    if not result or not result.go then return end -- retain pending table; delete when NickCore fills it
    r.destroy_queued = true
    local go = result.go
    run_once(function()
        if not alive then r.destroy_queued = false; return end
        local ok, err = pcall(function()
            assert(not active and not state.recovery, "End driving before deletion")
            assert(r.result == result and result.go == go, "Spawn reference changed")
            if go:get_Valid() then
                if result.chara and result.chara:get_Valid() then
                    assert(result.chara:call("get_GameObject()") == go
                        and result.chara:get_CharaIDString() == "ch253000_00", "Spawn identity mismatch")
                end
                event("delete_requested", "Only this Beta's returned GameObject")
                go:destroy(go) -- same native destruction form as installed NickCore; never destroy_spawns()
            end
            r.deleted = true; r.friend = false
            status = "本 Beta 生成的狮鹫已删除。"
            event("deleted", "Owned instance only")
        end)
        r.destroy_queued = false
        if not ok then r.delete_requested = false; failed("删除失败", err) end
    end)
end

re.on_frame(function()
    if not alive then return end
    local c = core()
    if not c then return end
    for i=#state.spawns,1,-1 do
        local r = state.spawns[i]
        if r.owner ~= c.properties.player then r.friend = false end
        if r.deleted then table.remove(state.spawns,i)
        elseif r.delete_requested then delete_one(r)
        elseif r.result and r.result.go and r.result.chara and not r.ready then
            r.ready = true
            run_once(function()
                if not alive or r.deleted or r.delete_requested then return end
                local ok, err = pcall(function()
                    install_hooks()
                    local ch = validate_spawn(r)
                    local info = ch:call("get_GenerateInfo()")
                    local container = info and info:call("get_Container()")
                    local data = container and container._CharaInfo
                    assert(data, "Spawn ThinkStop interface unavailable")
                    if data:call("get_IsThinkStop()") then data:call("set_IsThinkStop(System.Boolean)",false) end
                    status = "狮鹫已生成并设为队伍友方，可以开始驾驶。"
                    event("spawn_ready", "Friend bound; spawn ThinkStop released when true")
                end)
                if not ok then failed("狮鹫初始化失败",err) end
            end)
        end
    end
    if active and active.trace and now() >= next_sample then
        next_sample = now()+0.5
        rotate()
        if #journal.samples < 650 then journal.samples[#journal.samples+1] = {time=now(), data=active.trace} end
    end
    if active and now()-last_flush >= 2 then flush() end
end)
re.on_application_entry("UpdateHID",function()
    if not active or not alive then return end
    local ok, result = pcall(read_pad)
    if ok then input = result
    else stop_driver("手柄读取失败"); failed("手柄读取失败", result) end
end)
re.on_pre_application_entry("UpdateBehavior",tick_driver)
re.on_application_entry("PrepareRendering",function()
    local d = active
    if not d or d.camera_failed then return end
    local ok, err = pcall(function()
        local manager, camera = sdk.get_managed_singleton("app.CameraManager"), sdk.get_primary_camera()
        assert(manager and camera, "Camera unavailable")
        if camera_state and (camera_state.manager ~= manager or camera_state.camera ~= camera) then
            restore_camera(); d.camera_failed = true; return
        end
        if not camera_state then
            local distance,fov = manager._DistanceOffset,camera:call("get_FOV")
            assert(finite(distance) and finite(fov), "Camera values unavailable")
            camera_state = {manager=manager,camera=camera,distance=distance,fov=fov,
                last_distance=distance,last_fov=fov}
        end
        camera_state.last_distance=settings.distance; camera_state.last_fov=settings.fov
        manager._DistanceOffset=settings.distance
        camera:call("set_FOV",settings.fov)
    end)
    if not ok then restore_camera(); d.camera_failed=true; event("camera_error",tostring(err)) end
end)
re.on_script_reset(function()
    stop_driver("脚本重置")
    alive = false
    for _, r in ipairs(state.spawns) do r.friend = false; r.ready = false; r.destroy_queued = false end
    flush()
end)

-- Rebind only when this global table survives a same-Lua-state reload. A full Lua reset
-- may discard all references; never reconstruct native objects from addresses/IDs.
for _, r in ipairs(state.spawns) do r.friend = true; r.ready = false; r.destroy_queued = false end
local function beta_button(label)
    local styled = type(imgui.push_style_color)=="function" and type(imgui.pop_style_color)=="function"
    if styled then imgui.push_style_color(21,0xff98652b);imgui.push_style_color(0,0xffa8ecff) end
    local clicked = imgui.button(label)
    if styled then imgui.pop_style_color(2) end
    return clicked
end
re.on_draw_ui(function()
    if not imgui.tree_node("狮鹫飞行 Beta###GriffinFlightBeta") then return end
    imgui.text("版本 "..VERSION.." | A 起飞 · RT 冲刺 · LT 悬停")
    if beta_button("一键生成狮鹫并设为友方###BetaSpawn") then spawn() end
    if beta_button("开始驾驶（固定玩家＋冻结 FSM）###BetaStart") then start_driver() end
    if beta_button("结束驾驶／恢复玩家###BetaStop") then
        operation = nil; queued = false
        if type(run_once)~="function" then stop_driver("手动结束");imgui.tree_pop();return end
        run_once(function() if alive then stop_driver("手动结束") end end)
    end
    if beta_button("删除本 Beta 生成的狮鹫###BetaDelete") then
        operation = nil; queued = false
        if type(run_once)~="function" then status="等待 NickCore 加载后再删除。";imgui.tree_pop();return end
        run_once(function()
            if not alive or not stop_driver("删除狮鹫") then return end
            for _, r in ipairs(state.spawns) do r.delete_requested=true; delete_one(r) end
        end)
    end
    imgui.text(status)
    if active then
        local labels={ground="等待起飞",taking_off="起飞中",hover="悬停",dash="冲刺"}
        imgui.text("当前："..(labels[active.mode] or active.mode).."；左摇杆左右转向／上下调整目标高度。")
    end
    if imgui.tree_node("镜头设置") then
        if type(imgui.slider_float)=="function" then
            local changed,v = imgui.slider_float("距离偏移",settings.distance,0,80)
            if changed and finite(v) then settings.distance=math.max(0,math.min(80,v));pcall(json.dump_file,settings_path,settings) end
            changed,v = imgui.slider_float("FOV",settings.fov,40,120)
            if changed and finite(v) then settings.fov=math.max(40,math.min(120,v));pcall(json.dump_file,settings_path,settings) end
        end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
