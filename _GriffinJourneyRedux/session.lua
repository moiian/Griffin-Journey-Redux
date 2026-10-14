-- Griffin Journey Redux: session
return function(ctx)
local _ENV=ctx
-- Griffin Flight Beta 0.3.14. Requires installed NickCore + EnemySpawner + run_once.
-- Separate from GriffinMountExperiment; no OJR/LMD/NickCore files are changed.
VERSION = "0.3.14"
state = rawget(_G, "GriffinFlightBetaState") or {spawns = {}}
_G.GriffinFlightBetaState = state
_G.GriffinJourneyReduxState = state
state.spawns = state.spawns or {}
generation = {}
state.generation = generation
alive, queued = true, false
operation = nil
active, camera_state = nil, nil
camera_mode, follow_state = "original", nil
camera_follow_status = "镜头跟随：游戏默认"
status = "先生成狮鹫，再开始驾驶。"
hooks_ready, hooks_tried, friend_value = false, false, nil
yaw_state, yaw_hook_ready = nil, false
hover_yaw_state=nil
yaw_status = "自动转向镜头：未开启"
controls,menu,passengers = {},{},{}
menu.block_cross_phase=true -- Session-only; ordinary action phase guard is on without Debug.
passengers.frame=0
-- Session-only independent experiments; never persisted in player settings.
passengers.fall_experiment={reset=false,ground=false}
passengers.griffin_fall={reset=false,status="狮鹫跌落实验：关闭"}
passengers.protection={damage=true,relocation=true,lost_check=false,destroy=false,counts={}}
masks = nil
input = {x = 0, y = 0, buttons = 0}
settings = {distance = 30, fov = 90, freeze_player = true, rider_anim="", rider_lookX=0, rider_lookZ=1, rider_tilt_follow=1, rider_pitch_offset=0, rider_anchor="head", rider_neck_joint="", rider_height=1.0, rider_forward=0, rider_side=0, navigation_radius=4.019, steering_yaw=50.276, steering_pitch=22.018, navigation_height=0.991, bumper_pitch=59, controls_revision=1, camera_auto_yaw=false, camera_yaw_speed=120, camera_manual_threshold=0.55, sprint_stop_tau=0.8, hover_accel_tau=0.2, hover_decel_tau=0.6, hover_reverse_tau=0.6, hover_forward_speed=3, hover_backward_speed=1.5, hover_climb_speed=1.5, hover_descend_speed=1.5, hover_up_accel_tau=0.6, hover_up_decel_tau=0.2, hover_down_accel_tau=0.2, hover_down_decel_tau=0.6, hover_turn_speed=75, hover_camera_yaw_speed=120}
loaded_settings=nil
settings_path = "GriffinFlightBeta_Settings.json"
skip_think_enabled, skip_think_expected = false, nil
skip_think_status = "跳过思考：默认开启，等待狮鹫就绪"

function core()
    local c = rawget(_G, "NickCore")
    if c and c.properties and c.object and c.enemySpawner and type(run_once) == "function" then return c end
end
-- Same native Photo Mode flag used by OJR. Failure keeps ordinary pause behavior.
menu.photo_active=function()
    local ok,value=pcall(function()
        local gui=sdk.get_managed_singleton("app.GuiManager")
        return gui and gui["<IsDispPhotoModeAll>k__BackingField"]==true
    end)
    return ok and value==true
end
menu.gameplay_paused=function()
    local c=core()
    return not c or c.properties.isPaused or menu.photo_active()
end
menu.visual_allowed=function()
    local c=core()
    -- Display locking spans normal menus and the frame before pause is reported.
    -- Each visual write still validates the retained player/Griffin/actor instances.
    return alive and c and active and c.properties.player==active.player
end
function now()
    local c = core()
    return c and c.properties.gameTime or 0
end
function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
function vector(v)
    assert(v and finite(v.x) and finite(v.y) and finite(v.z), "Invalid position")
    return {x = v.x, y = v.y, z = v.z}
end
function flush()
    return debug_tools and debug_tools:flush() or false
end
function event(name,detail,defer_flush)
    if debug_tools then debug_tools:event(name,detail,defer_flush) end
end
function failed(label, err)
    status = label .. "：" .. tostring(err)
    event("error", status)
    -- Runtime errors remain visible in the menu; diagnostic output requires opt-in.
end
if type(json.load_file) == "function" then
    local ok, saved = pcall(json.load_file, settings_path)
    if ok and type(saved) == "table" then
        loaded_settings=saved
        -- Migrate the former shared speed once; explicit per-direction zero values are valid.
        if finite(saved.hover_speed) then
            settings.hover_forward_speed=math.max(0,math.min(12,saved.hover_speed))
            settings.hover_backward_speed=settings.hover_forward_speed*0.5
        end
        for _,key in ipairs({"hover_forward_speed","hover_backward_speed","hover_climb_speed","hover_descend_speed"}) do
            if finite(saved[key]) then settings[key]=math.max(0,math.min(12,saved[key])) end
        end
        -- Keep tuned legacy values for the slower stage; new explicit fields win.
        if finite(saved.hover_up_tau) then settings.hover_up_accel_tau=math.max(0,math.min(3,saved.hover_up_tau)) end
        if finite(saved.hover_down_tau) then settings.hover_down_decel_tau=math.max(0,math.min(3,saved.hover_down_tau)) end
        for _,key in ipairs({"sprint_stop_tau","hover_accel_tau","hover_decel_tau","hover_reverse_tau","hover_up_accel_tau","hover_up_decel_tau","hover_down_accel_tau","hover_down_decel_tau"}) do
            if finite(saved[key]) then settings[key]=math.max(0,math.min(3,saved[key])) end
        end
        if finite(saved.hover_turn_speed) then settings.hover_turn_speed=math.max(0,math.min(180,saved.hover_turn_speed)) end
        if finite(saved.hover_camera_yaw_speed) then settings.hover_camera_yaw_speed=math.max(0,math.min(360,saved.hover_camera_yaw_speed)) end
        settings.rider_anim=type(saved.rider_anim)=="string" and saved.rider_anim or ""
        if type(saved.camera_auto_yaw)=="boolean" then settings.camera_auto_yaw=saved.camera_auto_yaw end
        if finite(saved.camera_manual_threshold) then settings.camera_manual_threshold=math.max(0.25,math.min(0.95,saved.camera_manual_threshold)) end
        if finite(saved.camera_yaw_speed) then settings.camera_yaw_speed=math.max(15,math.min(360,saved.camera_yaw_speed)) end
        if type(saved.freeze_player) == "boolean" then settings.freeze_player = saved.freeze_player end
        if finite(saved.navigation_radius) then settings.navigation_radius=math.max(2,math.min(130,saved.navigation_radius)) end
        if finite(saved.navigation_height) then settings.navigation_height=math.max(-27,math.min(27,saved.navigation_height)) end
        if finite(saved.steering_yaw) then settings.steering_yaw=math.max(1,math.min(85,saved.steering_yaw)) end
        -- First controls migration adopts the user's screenshot, not an older cached pitch.
        if saved.controls_revision == 1 and finite(saved.steering_pitch) then settings.steering_pitch=math.max(1,math.min(80,saved.steering_pitch)) end
        if finite(saved.bumper_pitch) then settings.bumper_pitch=math.max(1,math.min(59,saved.bumper_pitch)) end
        if finite(saved.distance) then settings.distance = math.max(0, math.min(80, saved.distance)) end
        if finite(saved.fov) then settings.fov = math.max(40, math.min(120, saved.fov)) end
        for _,spec in ipairs({{"rider_lookX",-1,1},{"rider_lookZ",-1,1},{"rider_tilt_follow",0,1},{"rider_pitch_offset",-45,45}}) do
            if finite(saved[spec[1]]) then settings[spec[1]]=math.max(spec[2],math.min(spec[3],saved[spec[1]])) end
        end
        settings.rider_anchor=saved.rider_anchor=="neck" and "neck" or "head"
        settings.rider_neck_joint=type(saved.rider_neck_joint)=="string" and saved.rider_neck_joint or ""
        if finite(saved.rider_height) then settings.rider_height=math.max(-5,math.min(15,saved.rider_height)) end
        if finite(saved.rider_forward) then settings.rider_forward=math.max(-15,math.min(15,saved.rider_forward)) end
        if finite(saved.rider_side) then settings.rider_side=math.max(-10,math.min(10,saved.rider_side)) end
    end
end

function aggro_clear()
    local cfg = package.loaded["NicksDevtools/Config"]
    return not (type(cfg) == "table" and (cfg.disableAggro or cfg.forceAggro))
end
function pair_is_owned(a, b)
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
function install_hooks()
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
function capture_party(c, player)
    assert(aggro_clear(), "请关闭 NicksDevtools 的 Disable Aggro / Force Aggro")
    local party = c.object.get_party()
    assert(type(party) == "table" and party[1] == player, "Party unavailable")
    return party
end
function validate_spawn(r,visual_only)
    local c = assert(core(), "NickCore unavailable")
    assert(c.properties.player == r.owner and (not menu.gameplay_paused() or visual_only and menu.visual_allowed()), "Player changed or game paused")
    local result = r.result
    assert(result and result.go and result.chara, "等待狮鹫生成完成")
    assert(result.go:get_Valid() and result.chara:get_Valid(), "Griffin no longer valid")
    assert(result.chara:get_CharaIDString() == "ch253000_00"
        and result.chara:call("get_GameObject()") == result.go, "Griffin reference mismatch")
    assert(r.friend and aggro_clear(), "Friend override unavailable")
    assert(r.owner:get_Valid(), "Player no longer valid")
    local unavailable = 0
    for _, member in ipairs(r.party) do
        -- A distant pawn may leave the loaded scene. Never pass an invalid reference
        -- to native relationship calls, and do not end the player's flight for it.
        if member:get_Valid() then
            assert(result.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
                and member:call("getBattleRelationshipTo(app.Character)", result.chara) == friend_value,
                "Party relationship changed")
        else
            unavailable = unavailable + 1
        end
    end
    if unavailable ~= (r.unavailable_party or 0) then
        r.unavailable_party = unavailable
        event("party_reference_availability", {unavailable=unavailable, ignored_for_driver=true})
    end
    return result.chara
end
function owned_player(d, require_current)
    if require_current and (not core() or core().properties.player ~= d.player) then return false end
    if not d.player:get_Valid() or not d.player_go:get_Valid() then return false end
    return d.player:call("get_GameObject()") == d.player_go
        and d.player:call("get_Transform()") == d.transform
        and d.player:get_field("<PosRotContext>k__BackingField") == d.context
        and d.player:get_field("<AdjustTerrain>k__BackingField") == d.terrain
        and d.terrain.MainCharacterController == d.controller
        and d.player:get_field("<FallInfo>k__BackingField") == d.fall
end
function player_fsm(player)
    local manager = player:call("get_ActionManager()")
    return manager and manager.Fsm
end

-- Optional developer module can be omitted from player distributions.
passengers.apply_fall_experiment=function() end
passengers.griffin_fall_tick=function() end
passengers.record_protection=function() end
passengers.record_release_context=function() end
passengers.snapshot=function(value)
    if type(value)~="table" then return value end
    local result={};for key,item in pairs(value) do result[key]=passengers.snapshot(item) end;return result
end
settings.anti_jitter=not loaded_settings or loaded_settings.anti_jitter~=false
settings.griffin_anti_jitter=loaded_settings and loaded_settings.griffin_anti_jitter==true or false
end
