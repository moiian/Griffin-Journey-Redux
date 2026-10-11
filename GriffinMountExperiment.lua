-- Griffin Mount Experiment: stage 3 player-as-target flight control experiment.
-- Requires the installed aaaNickCore.lua and _NickCore/EnemySpawner.lua.
-- Keeps an explicit spawn return or user-confirmed instance; never selects by Character ID.
local VERSION = "0.3.10-stage3-anchor-stick"
local state = "Idle"
local detail = "Ready for one ordinary Griffin request per script session."
local shared = nil
local owner = nil
local started = nil
local submitted = false
local identity = "Not inspected"
local friendly = false
local hooks_installed = false
local hooks_attempted = false
local friend_ptr = nil
local friend_value = nil
local relation_pending = false
local party = {}
local relation_status = "Disabled. No relationship override."
local relation_rows = {}
local hits = {Character = {0, 0}, Holder = {0, 0}}
local early_mode = false
local think_status = "Spawn ThinkStop flag: not inspected"
local release_attempted = false
local hate_clear_attempted = false
local hate_status = "Hate: not inspected; no entries cleared."
local hate_rows = {}
local flight_rows = {}
local flight_status = "Flight: not inspected. No flight commands are implemented."
local session_id = os.date("!%Y%m%dT%H%M%SZ") .. "_" .. tostring(math.floor(os.clock() * 1000))
local flight_log_path = "GriffinMountExperiment_Flight_" .. session_id .. ".json"
local flight_log = {schema = 1, version = VERSION, session_id = session_id, samples = {}, events = {}}
local log_status = "No file write yet. Events and snapshots write the dedicated JSON."
local recording = false
local action_probe = false
local record_start = 0
local next_sample = 0
local last_flush = -math.huge
local recorder_tick = nil
local candidate = nil
local candidate_status = "No candidate. Preview checks the nearest enemy within 40m; it must be an ordinary Griffin."
local target_origin = "none"
local request_listener_table = nil
local request_listener_fn = nil
local request_listener_key = "GriffinMountExperiment action observer"
local request_listener_status = "Native request observer: not attached"
local request_event_count = 0
local request_last = {}
local cross_phase = false
local last_action_request = -math.huge
local action_test_status = "尚未提交动作请求。"
local target_probe = true
local target_probe_status = "目标与坐标记录随动作探针开启；只读。"
local yaw_degrees = 45
local yaw_status = "先运行慢速或快速动作，再点击左转或右转；每次只改一次世界朝向。"
local last_yaw_request = -math.huge
local lure = nil
local lure_restore_pending = nil
local lure_start_pending = false
local lure_start_cancelled = false
local lure_status = "先固定玩家到前方，再开启摇杆控制，最后手动请求目标导向飞行。"
local lure_stick_enabled = false
local lure_input = {x=0, y=0, raw_x=0, raw_y=0}
local lure_input_error = nil
local lure_invert_y = false
local stop_lure
local test_actions = {
    {key = "Test takeoff", label = "起飞", node = "Ch253TakeoffBackJump", phase = "ground"},
    {key = "Test hover", label = "悬停", node = "HoverWait", phase = "air"},
    {key = "Test forward", label = "悬停前移（慢速候选）", node = "HoverForward", phase = "air"},
    {key = "Test circle", label = "目标导向飞行（快速候选）", node = "Ch253WrapAroundStartLoop", phase = "air"},
    {key = "Test landing attack", label = "下冲落地攻击", node = "Ch253AirLandingPressStartLoop", phase = "air"}
}
flight_log.request_observer = {repeated_requests_omitted = 0, capacity_dropped = 0}

local function game_time()
    local core = rawget(_G, "NickCore")
    return core and core.properties and core.properties.gameTime or 0
end

local function rotation_values(q)
    local v = {}
    for _, key in ipairs({"x", "y", "z", "w"}) do
        local n = q and q[key]
        assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Invalid quaternion")
        v[key] = n
    end
    local length = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w)
    assert(length > 0.0001, "Zero quaternion")
    for key, n in pairs(v) do v[key] = n / length end
    return v
end

local function flush_flight_log()
    local ok, result = pcall(json.dump_file, flight_log_path, flight_log)
    if not ok or result == false then
        log_status = "LOG WRITE ERROR: " .. tostring(result)
        recording = false
        log.error("[GriffinMountExperiment] " .. log_status)
        return false
    end
    last_flush = game_time()
    log_status = "Log write call completed; samples=" .. #flight_log.samples .. " events=" .. #flight_log.events
    return true
end

local function log_event(name, detail)
    if #flight_log.events >= 500 then return end
    flight_log.events[#flight_log.events + 1] = {
        name = name, detail = detail, game_time = game_time(), utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    flush_flight_log()
end

local function disable_friendship(message)
    friendly = false
    party = {}
    relation_rows = {}
    relation_status = message or "Disabled. Original query results pass through."
    log_event("friend_disabled", relation_status)
end

local function aggro_conflict()
    local config = package.loaded["NicksDevtools/Config"]
    return type(config) == "table" and (config.disableAggro or config.forceAggro)
end

-- Exact returned Character reference + captured party Character references only.
local function match_pair(from, to)
    if not friendly or not shared or not shared.chara then return nil end
    if from == shared.chara then
        for _, member in ipairs(party) do
            if to == member then return 1 end
        end
    elseif to == shared.chara then
        for _, member in ipairs(party) do
            if from == member then return 2 end
        end
    end
    return nil
end

local function install_relation_hooks()
    if hooks_installed then return end
    assert(not hooks_attempted, "Hook installation previously failed; reload in a clean test session")
    local enum_type = sdk.find_type_definition("app.Character.BattleRelationship")
    local field = enum_type and enum_type:get_field("Friend")
    assert(field, "BattleRelationship.Friend field unavailable")
    local value = field:get_data()
    assert(type(value) == "number", "Friend enum is not numeric")
    friend_value = value
    friend_ptr = sdk.to_ptr(value)
    local char_type = sdk.find_type_definition("app.Character")
    local holder_type = sdk.find_type_definition("app.BattleRelationshipHolder")
    local character_method = char_type and char_type:get_method("getBattleRelationshipTo(app.Character)")
    local holder_method = holder_type and holder_type:get_method("getRelationshipFromTo(app.Character, app.Character)")
    assert(character_method and holder_method, "Relationship method signatures unavailable")
    local function attach(method, label, from_index, to_index)
        sdk.hook(method, function(args)
            local storage = thread.get_hook_storage()
            storage.griffin_mount_direction = nil
            if not friendly then return end
            local from = sdk.to_managed_object(args[from_index])
            local to = sdk.to_managed_object(args[to_index])
            storage.griffin_mount_direction = match_pair(from, to)
        end, function(retval)
            local direction = thread.get_hook_storage().griffin_mount_direction
            if friendly and direction then
                hits[label][direction] = hits[label][direction] + 1
                return friend_ptr
            end
            return retval
        end)
    end
    hooks_attempted = true
    attach(character_method, "Character", 2, 3)
    attach(holder_method, "Holder", 3, 4)
    hooks_installed = true
end

local function dependency()
    local core = rawget(_G, "NickCore")
    if type(core) ~= "table" or type(core.properties) ~= "table"
        or type(core.enemySpawner) ~= "table"
        or type(core.enemySpawner.spawn_enemy) ~= "function"
        or type(rawget(_G, "run_once")) ~= "function" then
        return nil
    end
    return core
end

local function report(next_state, message)
    state, detail = next_state, message
    log.error("[GriffinMountExperiment " .. VERSION .. "] " .. state .. ": " .. detail)
    log_event("state_" .. next_state, message)
end

local function enable_party_friend(core)
    assert(not aggro_conflict(), "Turn OFF NicksDevtools Disable/Force Aggro first")
    assert(core.object and type(core.object.get_party) == "function", "NickCore.get_party unavailable")
    local members = core.object.get_party()
    assert(type(members) == "table" and members[1] == owner, "Party snapshot unavailable")
    disable_friendship()
    install_relation_hooks()
    party = members
    hits = {Character = {0, 0}, Holder = {0, 0}}
    friendly = true
    relation_status = "Enabled for bound Griffin + " .. #party .. " party members."
    log_event("friend_enabled", relation_status)
end

local function attach_request_observer(core)
    local callbacks = core.functions and core.functions.on_pre_action_request
    if type(callbacks) ~= "table" then
        request_listener_status = "Native request observer unavailable: NickCore callback missing"
        return
    end
    if request_listener_table == callbacks and callbacks[request_listener_key] == request_listener_fn then return end
    request_listener_fn = function(_, data)
        -- NickCore already decoded these fields. No native calls, disk IO or return override here.
        if not recording or not action_probe or not shared or not data
            or data.character ~= shared.chara or core.properties.player ~= owner then return end
        local now = game_time()
        local previous = request_last[data.layer]
        if previous and previous.node == data.node and previous.priority == data.priority
            and now - previous.time < 1 then
            flight_log.request_observer.repeated_requests_omitted =
                flight_log.request_observer.repeated_requests_omitted + 1
            return
        end
        -- Leave event capacity for lifecycle/error events even during busy native action traffic.
        if #flight_log.events >= 450 then
            flight_log.request_observer.capacity_dropped = flight_log.request_observer.capacity_dropped + 1
            return
        end
        request_last[data.layer] = {node = data.node, priority = data.priority, time = now}
        request_event_count = request_event_count + 1
        flight_log.events[#flight_log.events + 1] = {
            name = "native_action_request", game_time = now,
            node = data.node, layer = data.layer, priority = data.priority,
            friend_enabled = friendly, target_origin = target_origin
        }
        -- nil return keeps NickCore's original request processing unchanged.
    end
    request_listener_table = callbacks
    callbacks[request_listener_key] = request_listener_fn
    request_listener_status = "Native request observer attached through NickCore (recording + probe only)"
end

local function preview_existing_griffin()
    if relation_pending or shared or state == "Queued" then return end
    candidate = nil
    local core = dependency()
    if not core or not core.properties.player or core.properties.isPaused ~= false then
        candidate_status = "Enter active gameplay before preview."
        return
    end
    relation_pending = true
    local preview_owner = core.properties.player
    run_once(function()
        local ok, err = pcall(function()
            assert(dependency() == core and core.properties.player == preview_owner and not shared,
                "Player/instance context changed")
            assert(core.properties.isPaused == false, "Gameplay paused")
            assert(core.position and type(core.position.get_closest_enemy) == "function",
                "NickCore.get_closest_enemy unavailable")
            local chara = core.position.get_closest_enemy(nil, 40.0)
            assert(chara and chara:get_Valid(), "No valid nearest enemy within 40m")
            local prefab = chara:get_CharaIDString()
            assert(prefab == "ch253000_00", "Nearest enemy is " .. tostring(prefab) .. "; move closer to the Griffin")
            local go = chara:call("get_GameObject()")
            assert(go and go:get_Valid(), "Candidate GameObject invalid")
            candidate = {chara = chara:add_ref(), go = go:add_ref(), player = preview_owner}
            candidate_status = "Candidate ch253000_00 | Character " .. tostring(chara:get_address())
                .. " | GO " .. tostring(go:get_address()) .. ". Bind keeps THIS reference."
        end)
        if not ok then candidate_status = "Preview failed: " .. tostring(err) end
        relation_pending = false
    end)
end

local function bind_existing_griffin()
    if relation_pending or shared or not candidate or state == "Queued" then return end
    local chosen = candidate
    relation_pending = true
    run_once(function()
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == chosen.player and not shared, "Candidate context changed")
            assert(core.properties.isPaused == false, "Gameplay paused")
            assert(chosen.chara:get_Valid() and chosen.go:get_Valid(), "Candidate no longer valid")
            assert(chosen.chara:get_CharaIDString() == "ch253000_00", "Candidate is not an ordinary Griffin")
            assert(chosen.chara:call("get_GameObject()") == chosen.go, "Candidate references no longer match")
            disable_friendship("Selected instance bound; Friend override remains OFF until explicitly enabled.")
            shared = {name = "Griffin", chara = chosen.chara, go = chosen.go}
            owner, target_origin = chosen.player, "selected"
            early_mode, release_attempted, hate_clear_attempted = false, false, false
            think_status = "Existing instance: no spawn ThinkStop write is offered."
            identity = candidate_status
            candidate = nil
            report("References ready", "User-selected existing Griffin bound. No spawn, faction or flight writes.")
        end)
        if not ok then candidate = nil; candidate_status = "Bind failed: " .. tostring(err) end
        relation_pending = false
    end)
end

local function unbind_griffin()
    if lure or lure_restore_pending or lure_start_pending then return end
    if relation_pending or recording then return end
    disable_friendship("Disabled: instance unbound. World object left in place.")
    shared, owner, candidate = nil, nil, nil
    target_origin = "none"
    identity = "No instance bound"
    flight_rows, relation_rows, hate_rows = {}, {}, {}
    report("Unbound", "Preview another existing Griffin, or rebind the same one. No despawn.")
end

local function request_spawn(early)
    if submitted or shared or relation_pending then return end
    candidate = nil
    local core = dependency()
    if not core then
        report("Dependency missing", "Wait for NickCore to load; no request sent.")
        return
    end
    local p = core.properties
    if not p.player or not p.transform or p.isPaused ~= false then
        report("Not ready", "Enter active gameplay and close pause menus; no request sent.")
        return
    end
    submitted = true
    early_mode = early == true
    report("Queued", "One request queued via NickCore run_once. Close REFramework UI.")
    run_once(function()
        -- NickCore runs this in LateUpdateBehavior, matching NicksDevtools.
        local current = dependency()
        if current ~= core or not p.player or not p.transform or p.isPaused ~= false then
            report("Aborted", "Gameplay/dependency changed before dispatch. No retry this session.")
            return
        end
        owner = p.player
        started = p.gameTime
        -- pcall handles Lua errors only. NickCore's deferred native work is outside it.
        local ok, result = pcall(function()
            if early_mode then
                -- Arm exact-reference filter before asking NickCore to spawn.
                -- It cannot match during synchronous initialization until shared.chara is filled.
                enable_party_friend(core)
                relation_status = "Armed before spawn; waiting for returned Character reference."
            end
            return core.enemySpawner.spawn_enemy("Griffin", nil, early_mode)
        end)
        if not ok then
            disable_friendship("Disabled after spawn preparation error.")
            report("Lua error", tostring(result) .. "; no automatic retry.")
            return
        end
        if type(result) ~= "table" then
            disable_friendship("Disabled: unexpected spawn return.")
            report("Unexpected return", "No returned table; no automatic retry.")
            return
        end
        shared = result
        target_origin = "spawned"
        report("Waiting", "Returned table retained; waiting for go and chara.")
    end)
end

re.on_frame(function()
    if not shared then return end
    local core = dependency()
    if not core or core.properties.player ~= owner then
        disable_friendship("Disabled: player context changed.")
        shared = nil
        candidate = nil
        target_origin = "none"
        recording = false
        report("Detached", "Player context changed. References discarded; no world object removed.")
        return
    end
    if friendly and aggro_conflict() then
        disable_friendship("Disabled: NicksDevtools global aggro option is active.")
    end
    -- Only Lua table reads here: no repeated native validity/AI calls.
    if (state == "Waiting" or state == "Delayed") and shared.go and shared.chara then
        report("References ready", "Returned go and chara are present. Visually verify the Griffin.")
        if early_mode and friendly then
            relation_status = "Bound to returned Griffin + " .. #party .. " party members; ThinkStop requested at spawn."
        end
    elseif state == "Waiting" and started and core.properties.gameTime - started > 20 then
        report("Delayed", "20 gameplay seconds elapsed. Still observing the same request; do not spawn again.")
    end
    if recorder_tick then recorder_tick(core) end
end)

local function queue_relation_action(enable)
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    relation_pending = true
    local expected = shared
    run_once(function()
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected,
                "Instance/player context changed")
            assert(expected.go:get_Valid(), "Spawned GameObject is invalid")
            assert(expected.chara:get_CharaIDString() == "ch253000_00", "Unexpected prefab")
            if enable then
                enable_party_friend(core)
            end
            relation_rows = {}
            local members = friendly and party or core.object.get_party()
            for index, member in ipairs(members) do
                local outward = expected.chara:call("getBattleRelationshipTo(app.Character)", member)
                local inward = member:call("getBattleRelationshipTo(app.Character)", expected.chara)
                relation_rows[#relation_rows + 1] = "Party " .. index .. " | Griffin -> member: "
                    .. tostring(outward) .. " | member -> Griffin: " .. tostring(inward)
            end
            for _, row in ipairs(relation_rows) do log.error("[GriffinMountExperiment] " .. row) end
            log.error("[GriffinMountExperiment] " .. relation_status)
        end)
        if not ok then
            disable_friendship("Disabled after Lua error: " .. tostring(err))
            log.error("[GriffinMountExperiment] " .. relation_status)
        end
        relation_pending = false
    end)
end

local function queue_think_flag(release)
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    if release and (not early_mode or release_attempted) then return end
    relation_pending = true
    local expected = shared
    run_once(function()
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(expected.go:get_Valid(), "Spawned GameObject is invalid")
            local info = expected.chara:call("get_GenerateInfo()")
            assert(info, "GenerateInfo unavailable")
            local container = info:call("get_Container()")
            local char_info = container and container._CharaInfo
            assert(char_info, "GenerateInfo container CharacterInfo unavailable")
            local before = char_info:call("get_IsThinkStop()")
            if release then
                assert(friendly and not aggro_conflict(), "Friend override must remain enabled")
                -- Validate both directions immediately before the single flag write.
                for _, member in ipairs(party) do
                    assert(expected.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value,
                        "Griffin -> party is not Friend; read again after gameplay runs")
                    assert(member:call("getBattleRelationshipTo(app.Character)", expected.chara) == friend_value,
                        "Party -> Griffin is not Friend; read again after gameplay runs")
                end
                assert(before == true, "Spawn ThinkStop flag is not true; no write performed")
                release_attempted = true
                char_info:call("set_IsThinkStop(System.Boolean)", false)
            end
            local after = char_info:call("get_IsThinkStop()")
            think_status = "Spawn ThinkStop flag: " .. tostring(before) .. " -> " .. tostring(after)
                .. (release and " | Release requested; verify actual AI movement." or " | Read only.")
            log.error("[GriffinMountExperiment] " .. think_status)
            log_event(release and "thinkstop_release" or "thinkstop_read", think_status)
        end)
        if not ok then
            think_status = "ThinkStop inspection/release error: " .. tostring(err)
            log.error("[GriffinMountExperiment] " .. think_status)
        end
        relation_pending = false
    end)
end

local function inspect_instance()
    if not shared or not shared.go or not shared.chara then return end
    local ok, result = pcall(function()
        if not shared.go:get_Valid() then return "GameObject is no longer valid" end
        local id_string = shared.chara:get_CharaIDString()
        return "Prefab: " .. tostring(id_string)
            .. " | GO address: " .. tostring(shared.go:get_address())
            .. " | Character address: " .. tostring(shared.chara:get_address())
    end)
    identity = ok and result or ("Lua inspection error: " .. tostring(result))
    log.error("[GriffinMountExperiment] " .. identity)
end

local function queue_hate_action(clear)
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    if clear and hate_clear_attempted then return end
    relation_pending = true
    local expected = shared
    run_once(function()
        local completed = 0
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(expected.go:get_Valid(), "Spawned GameObject is invalid")
            if clear then
                assert(friendly and not aggro_conflict(), "Friend override must remain enabled")
            end
            local members = friendly and party or core.object.get_party()
            local griffin_hate = expected.chara:call("get_HateSystem()")
            assert(griffin_hate, "Griffin HateSystem unavailable")
            local entries = {}
            -- Collect and read everything before any write. Never enumerate world enemies.
            for index, member in ipairs(members) do
                local member_go = member:call("get_GameObject()")
                assert(member_go and member_go:get_Valid(), "Party GameObject invalid: " .. index)
                if clear then
                    assert(expected.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
                        and member:call("getBattleRelationshipTo(app.Character)", expected.chara) == friend_value,
                        "Both directions must be Friend before clearing: Party " .. index)
                end
                local member_hate = member:call("get_HateSystem()")
                entries[#entries + 1] = {label = "Griffin -> Party " .. index, system = griffin_hate, target = member_go}
                entries[#entries + 1] = {label = "Party " .. index .. " -> Griffin", system = member_hate, target = expected.go}
            end
            local function read(entry)
                if not entry.system then return "N/A (no HateSystem)" end
                return "total=" .. tostring(entry.system:call("getTotalHate(via.GameObject)", entry.target))
                    .. " temp=" .. tostring(entry.system:call("getRawTotalTempHate(via.GameObject)", entry.target))
                    .. " notForget=" .. tostring(entry.system:call("getRawTotalNotForgetHate(via.GameObject)", entry.target))
            end
            local rows = {}
            for index, entry in ipairs(entries) do rows[index] = entry.label .. " | " .. read(entry) end
            hate_rows = rows
            for _, row in ipairs(rows) do log.error("[GriffinMountExperiment] Hate BEFORE/READ " .. row) end
            if clear then
                hate_clear_attempted = true -- Never automatically repeat a partially completed native mutation.
                for index, entry in ipairs(entries) do
                    if entry.system then
                        entry.system:call("clear(via.GameObject)", entry.target)
                        completed = completed + 1
                    end
                    hate_rows[index] = rows[index] .. " => " .. read(entry)
                    log.error("[GriffinMountExperiment] Hate AFTER " .. hate_rows[index])
                end
            end
            hate_status = clear and ("Pair-only clear completed: " .. completed .. " calls. Observe and read again after 10s.")
                or "Hate snapshot read only. total / temp / notForget; values are not an AI target readout."
            log.error("[GriffinMountExperiment] " .. hate_status)
        end)
        if not ok then
            hate_status = "Hate error after " .. completed .. " clear calls: " .. tostring(err)
            log.error("[GriffinMountExperiment] " .. hate_status)
        end
        relation_pending = false
    end)
end

local function queue_flight_snapshot(source)
    source = source or "manual"
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    if #flight_log.samples >= 1000 then
        recording = false
        flight_status = "Session sample limit reached (1000). Recording stopped."
        flush_flight_log()
        return
    end
    relation_pending = true
    local expected = shared
    run_once(function()
        flight_rows = {}
        local sample = {
            sequence = #flight_log.samples + 1, source = source, game_time = game_time(),
            utc = os.date("!%Y-%m-%dT%H:%M:%SZ"), friend_enabled = friendly,
            values = {}, errors = {}, action_probe_enabled = action_probe, target_origin = target_origin,
            target_probe_enabled = action_probe and target_probe
        }
        if lure then
            sample.stick_lure = {active=true, input_x=lure_input.x, input_y=lure_input.y,
                raw_x=lure_input.raw_x, raw_y=lure_input.raw_y, writes=lure.writes,
                elapsed=game_time()-lure.started, target=lure.target, player_readback=lure.readback,
                controller_readback=lure.physical, forward_distance=20, lateral_range=12, vertical_range=10,
                stick_enabled=lure_stick_enabled, flight_readiness=lure.flight_readiness}
        end
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(expected.go:get_Valid(), "Spawned GameObject is invalid")
            sample.character_address = tostring(expected.chara:get_address()) -- diagnostic only; never selects a target
            local function row(label, getter)
                local success, value = pcall(getter)
                local text = label .. " = " .. (success and tostring(value) or ("READ ERROR: " .. tostring(value)))
                flight_rows[#flight_rows + 1] = text
                if source == "manual" then log.error("[GriffinMountExperiment] Flight " .. text) end
                if success then
                    local kind = type(value)
                    if kind == "number" or kind == "boolean" or kind == "string" then
                        sample.values[label] = value
                    else
                        sample.values[label] = tostring(value)
                    end
                else
                    sample.errors[label] = tostring(value)
                end
                return success and value or nil
            end
            for _, name in ipairs({"IsCanFly", "IsFlight", "IsGround", "IsHover"}) do
                row("Character." .. name, function() return expected.chara:call("get_" .. name .. "()") end)
            end
            local char_ctrl = row("Character.FlightCtrl", function() return expected.chara:call("get_FlightCtrl()") end)
            local ch253 = row("Ch253 component", function()
                return core.object.get_component(expected.go, "app.Ch253")
            end)
            local monster_ctrl = ch253 and row("Ch253.FlightControl", function()
                return ch253:call("get_FlightControl()")
            end) or nil
            row("Both controller references equal", function()
                return char_ctrl ~= nil and monster_ctrl ~= nil and char_ctrl == monster_ctrl
            end)
            local function inspect_controller(label, ctrl)
                if not ctrl then return end
                row(label .. ".CachedCharacter is returned Griffin", function()
                    return ctrl:call("get_CachedCharacter()") == expected.chara
                end)
                for _, name in ipairs({"IsFlightAction", "ESTStatusId", "FlightAngleY", "TargetAngleRad",
                    "GroundHeight", "AirTargetPosY"}) do
                    row(label .. "." .. name, function() return ctrl:call("get_" .. name .. "()") end)
                end
            end
            inspect_controller("Character.FlightCtrl", char_ctrl)
            if monster_ctrl ~= char_ctrl then inspect_controller("Ch253.FlightControl", monster_ctrl) end
            if action_probe then
                -- Opt-in observation only. No action requests, state writes or sequence updates.
                local probe_failed = false
                local function action_row(label, getter)
                    local value = row(label, getter)
                    if sample.errors[label] then probe_failed = true end
                    return value
                end
                local manager = action_row("Character.ActionManager", function()
                    return expected.chara:call("get_ActionManager()")
                end)
                action_row("ActionManager available", function() return manager ~= nil end)
                if manager then
                    action_row("ActionManager.IsEndAction", function() return manager:call("get_IsEndAction()") end)
                    for _, name in ipairs({"CurrentActionHash", "PrevActionHash"}) do
                        -- Existing engine action identifiers; no file checksums are computed.
                        action_row("ActionManager." .. name, function() return manager:call("get_" .. name .. "()") end)
                    end
                    for _, field in ipairs({"CurrentAction", "PrevAction"}) do
                        local info = action_row("ActionManager." .. field .. " present", function()
                            return manager:get_field(field)
                        end)
                        if info then
                            action_row("ActionManager." .. field .. ".Name", function() return info:get_field("Name") end)
                            action_row("ActionManager." .. field .. ".IsValid", function() return info:call("get_IsValid()") end)
                        end
                    end
                end
                if ch253 then
                    for _, name in ipairs({"MotinoLayerActionBodyName", "MotinoLayerActionWingName"}) do
                        action_row("Ch253." .. name, function() return ch253:call("get_" .. name .. "()") end)
                    end
                end
                if probe_failed then
                    action_probe = false
                    log_event("action_probe_disabled", "Read error; see sample " .. sample.sequence .. ". Original flight recording continues.")
                end
                if target_probe then
                    local target_failed = false
                    local function target_row(label, getter)
                        local value = row(label, getter)
                        if sample.errors[label] then target_failed = true end
                        return value
                    end
                    -- Keep scalar row behavior, while storing vectors in a separate typed table.
                    sample.vectors = {}
                    sample.rotations = {}
                    local function capture_vector(label, getter)
                        target_row(label, function()
                            local v = getter()
                            assert(v and type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number",
                                "Vector components unavailable")
                            sample.vectors[label] = {x = v.x, y = v.y, z = v.z}
                            return true
                        end)
                    end
                    capture_vector("Griffin.Position", function()
                        return expected.chara:call("get_Transform()"):call("get_Position()")
                    end)
                    target_row("Griffin.Rotation", function()
                        local q = rotation_values(expected.chara:call("get_Transform()"):call("get_Rotation()"))
                        sample.rotations["Griffin.Rotation"] = q
                        sample.vectors["Griffin.Forward"] = {
                            x = 2*(q.x*q.z + q.w*q.y), y = 2*(q.y*q.z - q.w*q.x),
                            z = 1 - 2*(q.x*q.x + q.y*q.y)
                        }
                        return true
                    end)
                    capture_vector("Player.Position", function() return core.properties.transform:call("get_Position()") end)
                    if char_ctrl then
                        capture_vector("FlightControl.TargetPosition", function() return char_ctrl:call("get_TargetPosition()") end)
                        capture_vector("FlightControl.ForwardTargetFront", function() return char_ctrl:call("get_ForwardTargetFront()") end)
                    end
                    local tc = ch253 and target_row("Ch253.TargetController", function()
                        return ch253:call("get_TargetController()")
                    end)
                    if tc then
                        local correct_owner = target_row("TargetController bound to Griffin", function()
                            assert(tc:call("get_Owner()") == expected.go and tc:call("get_Chara()") == expected.chara,
                                "TargetController owner mismatch")
                            return true
                        end)
                        if correct_owner then
                            target_row("TargetController.TargetType", function() return tc:call("get_TargetType()") end)
                            local target_character = target_row("TargetController.TargetCharacter", function()
                                return tc:call("get_TargetCharacter()")
                            end)
                            target_row("TargetController.TargetIsPlayer", function() return target_character == owner end)
                            target_row("TargetController.HasTargetGameObject", function()
                                return tc:call("get_TargetGameObject()") ~= nil
                            end)
                            capture_vector("TargetController.TargetPosition", function() return tc:call("get_TargetPosition()") end)
                        end
                    end
                    if target_failed then
                        target_probe = false
                        target_probe_status = "新增目标读取出现错误，已停用；原动作测试和记录保留。"
                        log_event("target_probe_disabled", "Read error; see sample " .. sample.sequence)
                    end
                end
            end
            flight_status = "Snapshot complete. Read errors, if any, are shown below. No flight state was written."
        end)
        if not ok then
            flight_status = "Flight snapshot error: " .. tostring(err)
            sample.errors.snapshot = tostring(err)
            recording = false
        end
        flight_log.samples[#flight_log.samples + 1] = sample
        if source == "manual" or not recording or not ok or game_time() - last_flush >= 1 then flush_flight_log() end
        if source == "manual" or not ok then log.error("[GriffinMountExperiment] " .. flight_status) end
        relation_pending = false
    end)
end

recorder_tick = function(core)
    if not recording or core.properties.isPaused then return end
    local now = core.properties.gameTime
    if now - record_start >= 60 then
        recording = false
        log_event("recording_finished", "60 gameplay seconds elapsed")
        return
    end
    if now >= next_sample and not relation_pending then
        next_sample = now + 0.2 -- At most 5 Hz; no catch-up burst after a slow frame.
        queue_flight_snapshot("automatic")
    end
end

local function start_recording()
    if not shared or not shared.go or not shared.chara then return end
    local core = dependency()
    if not action_probe then
        action_probe = true
        log_event("action_probe_enabled", "Automatically enabled by recording start")
    end
    if core then attach_request_observer(core) end
    log_event("request_observer_status", request_listener_status)
    record_start = game_time()
    request_last = {}
    next_sample = record_start
    recording = true
    log_event("recording_started", "60 gameplay seconds, at most 5 Hz; flight + action names + passive native requests")
end

local function queue_action_test(action)
    if lure_restore_pending then action_test_status = "请先恢复玩家位置。"; return end
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    if game_time() - last_action_request < 3 then
        action_test_status = "请等待至少3个游戏运行秒，再提交下一个动作。"
        return
    end
    local expected, allow_cross = shared, cross_phase
    relation_pending = true
    action_test_status = "已排队：" .. action.label .. "。请关闭界面让游戏运行。"
    run_once(function()
        local called = false
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(core.properties.isPaused == false, "Gameplay paused")
            assert(expected.go:get_Valid() and expected.chara:get_Valid(), "Bound instance invalid")
            assert(expected.chara:get_CharaIDString() == "ch253000_00", "Not an ordinary Griffin")
            assert(friendly and not aggro_conflict(), "Enable party Friend first")
            for _, member in ipairs(party) do
                assert(expected.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
                    and member:call("getBattleRelationshipTo(app.Character)", expected.chara) == friend_value,
                    "Party relationship is not Friend in both directions")
            end
            local ctrl = expected.chara:call("get_FlightCtrl()")
            assert(ctrl and ctrl:call("get_CachedCharacter()") == expected.chara, "Flight controller binding mismatch")
            local flying = expected.chara:call("get_IsFlight()")
            local grounded = expected.chara:call("get_IsGround()")
            if not allow_cross then
                assert(action.phase == "ground" and grounded and not flying or action.phase == "air" and flying,
                    "Phase mismatch; enable cross-phase testing to intentionally bypass this check")
            end
            local manager = expected.chara:call("get_ActionManager()")
            assert(manager and manager:call("get_GameObject()") == expected.go, "ActionManager binding mismatch")
            local method = "requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)"
            assert(sdk.find_type_definition("app.ActionManager"):get_method(method), "Request method unavailable")
            assert(#flight_log.samples < 1000, "Sample capacity full; use a fresh script session and rebind")
            if not recording then start_recording() end
            assert(#flight_log.events < 490, "Event capacity nearly full; use a fresh script session")
            log_event("manual_action_attempt", action.node)
            flight_log.events[#flight_log.events].request = {
                node = action.node, layer = 0, priority = 10, cross_phase = allow_cross,
                is_flight_before = flying, is_ground_before = grounded,
                character_address = tostring(expected.chara:get_address()), target_origin = target_origin
            }
            assert(flush_flight_log(), "Could not save pre-request log; no native request sent")
            last_action_request = game_time()
            called = true
            -- One observed request combination, no retry or forced completion.
            manager:call(method, 10, action.node, 0)
            action_test_status = "已提交一次：" .. action.label .. "。接口返回不代表动作执行成功。"
            log_event("manual_action_returned", action.node)
        end)
        if not ok then
            action_test_status = (called and "请求调用出现 Lua 错误：" or "未提交动作：") .. tostring(err)
            log_event(called and "manual_action_error" or "manual_action_blocked", action_test_status)
        end
        relation_pending = false
    end)
end

local function queue_yaw_test(direction)
    if lure or lure_restore_pending then yaw_status = "摇杆测试期间不直接旋转狮鹫；请先停止并恢复。"; return end
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    if game_time() - last_yaw_request < 1 then
        yaw_status = "请间隔至少1个游戏运行秒，再点击转向。"
        return
    end
    local expected, degrees = shared, direction * yaw_degrees
    relation_pending = true
    yaw_status = "转向已排队，请关闭界面让游戏运行。"
    run_once(function()
        local called = false
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(core.properties.isPaused == false, "Gameplay paused")
            assert(expected.go:get_Valid() and expected.chara:get_Valid(), "Bound instance invalid")
            assert(expected.chara:get_CharaIDString() == "ch253000_00"
                and expected.chara:call("get_GameObject()") == expected.go, "Character binding mismatch")
            assert(friendly and not aggro_conflict(), "Enable party Friend first")
            for _, member in ipairs(party) do
                assert(expected.chara:call("getBattleRelationshipTo(app.Character)", member) == friend_value
                    and member:call("getBattleRelationshipTo(app.Character)", expected.chara) == friend_value,
                    "Party relationship is not Friend in both directions")
            end
            assert(expected.chara:call("get_IsFlight()"), "Griffin must be airborne")
            local ctrl = expected.chara:call("get_FlightCtrl()")
            assert(ctrl and ctrl:call("get_CachedCharacter()") == expected.chara, "Flight controller binding mismatch")
            local manager = expected.chara:call("get_ActionManager()")
            assert(manager and manager:call("get_GameObject()") == expected.go, "ActionManager binding mismatch")
            local info = manager:get_field("CurrentAction")
            local node = info and info:get_field("Name")
            assert(node == "HoverForward" or node == "Ch253WrapAroundStartLoop", "Run slow or fast flight first")
            local transform = expected.chara:call("get_Transform()")
            assert(transform and Quaternion and Quaternion.new, "Transform or Quaternion constructor unavailable")
            local before = rotation_values(transform:call("get_Rotation()"))
            local half = math.rad(degrees) / 2
            local s, c = math.sin(half), math.cos(half)
            -- World-Y rotation on the left preserves existing pitch/roll.
            local after = rotation_values({x=c*before.x+s*before.z, y=c*before.y+s*before.w,
                z=c*before.z-s*before.x, w=c*before.w-s*before.y})
            -- REFramework's constructor takes (w,x,y,z), unlike the named fields.
            -- 0.3.7 live readback proved the old ordering permuted all four components.
            local value = Quaternion.new(after.w, after.x, after.y, after.z)
            local constructed = rotation_values(value)
            for _, key in ipairs({"x", "y", "z", "w"}) do
                assert(math.abs(constructed[key] - after[key]) < 0.00001,
                    "Quaternion constructor component mismatch; rotation blocked")
            end
            assert(#flight_log.samples < 1000 and #flight_log.events < 490, "Log capacity nearly full")
            if not recording then start_recording() end
            log_event("manual_yaw_attempt", node)
            flight_log.events[#flight_log.events].rotation = {degrees=degrees, before=before, requested=after, constructed=constructed,
                node=node, character_address=tostring(expected.chara:get_address()), target_origin=target_origin}
            assert(flush_flight_log(), "Could not save pre-write log; no rotation written")
            last_yaw_request = game_time()
            called = true
            transform:call("set_Rotation(via.Quaternion)", value)
            yaw_status = "已单次旋转 " .. tostring(degrees) .. "°；观察朝向和航迹是否保持。"
            log_event("manual_yaw_returned", yaw_status)
            local read_ok, readback = pcall(function() return rotation_values(transform:call("get_Rotation()")) end)
            local event = flight_log.events[#flight_log.events]
            event.rotation_readback = read_ok and readback or nil
            event.readback_error = not read_ok and tostring(readback) or nil
            flush_flight_log()
        end)
        if not ok then
            yaw_status = (called and "转向调用出现 Lua 错误：" or "未执行转向：") .. tostring(err)
            log_event(called and "manual_yaw_error" or "manual_yaw_blocked", yaw_status)
        end
        relation_pending = false
    end)
end

local function vector_values(v)
    local result = {}
    for _, key in ipairs({"x", "y", "z"}) do
        local n = v and v[key]
        assert(type(n)=="number" and n==n and math.abs(n)<math.huge, "Invalid position")
        result[key] = n
    end
    return result
end

local function player_lure_owned(d)
    local core = dependency()
    if not core or core.properties.player ~= d.player then return false end
    if not d.player:get_Valid() or not d.player_go:get_Valid() then return false end
    return d.player:call("get_GameObject()") == d.player_go
        and d.player:call("get_Transform()") == d.transform
        and d.player:get_field("<PosRotContext>k__BackingField") == d.context
        and d.player:get_field("<AdjustTerrain>k__BackingField") == d.terrain
        and d.terrain.MainCharacterController == d.controller
        and d.player:get_field("<FallInfo>k__BackingField") == d.fall
end

local function synchronize_lure_player(d)
    local universal = d.transform:call("get_UniversalPosition()")
    -- Same typed position/context/physics sequence as the inspected OJR source.
    -- No Character.warp, nil targets, collision changes or FSM changes.
    d.context:call("setPos(via.Position)", universal)
    d.fall:call("resetBaseHeight(via.Position)", universal)
    d.fall:call("resetFallHeight()")
    d.controller:call("warp()")
end

stop_lure = function(reason)
    local d = lure or lure_restore_pending
    if not d then return end
    lure = nil -- stop further driver writes before trying restoration
    lure_stick_enabled = false
    lure_input = {x=0,y=0,raw_x=0,raw_y=0}
    log_event("stick_lure_stopped", reason)
    local ok, err = pcall(function()
        if not player_lure_owned(d) then
            lure_status = "测试已停止；玩家或控制器已切换，放弃旧对象的位置恢复。"
            log_event("stick_lure_restore_skipped", "Player/context changed; no old-instance write")
            return
        end
        if d.moved then
            log_event("stick_lure_restore_attempt", "Restore original universal position")
            flush_flight_log() -- restoration is still attempted if logging fails
            d.transform:call("set_UniversalPosition(via.Position)", d.original_universal)
            synchronize_lure_player(d)
        end
        lure_status = "测试已停止并恢复玩家原位置：" .. reason
        log_event("stick_lure_restored", lure_status)
    end)
    lure_restore_pending = not ok and d or nil
    if not ok then
        lure_status = "移动已停止，恢复失败；请点击停止／恢复重试：" .. tostring(err)
        log_event("stick_lure_restore_error", lure_status)
    end
    flush_flight_log()
end

local function read_lure_stick()
    local singleton = sdk.get_native_singleton("via.hid.Gamepad")
    local definition = sdk.find_type_definition("via.hid.GamePad")
    assert(singleton and definition, "Gamepad API unavailable")
    local device = sdk.call_native_func(singleton, definition, "get_MergedDevice")
    assert(device, "Merged gamepad unavailable")
    local axis = device:call("get_AxisL()")
    local x, y = axis and axis.x, axis and axis.y
    assert(type(x)=="number" and x==x and math.abs(x)<math.huge
        and type(y)=="number" and y==y and math.abs(y)<math.huge, "Left stick unavailable")
    x,y=math.max(-1,math.min(1,x)),math.max(-1,math.min(1,y))
    local raw_x,raw_y=x,y
    local magnitude=math.sqrt(x*x+y*y)
    if magnitude<=0.2 then x,y=0,0
    else
        local scale=math.min(1,(magnitude-0.2)/0.8)/magnitude
        x,y=x*scale,y*scale
    end
    if lure_invert_y then y=-y end
    if reframework and reframework:is_drawing_ui() then x,y=0,0 end
    return {x=x,y=y,raw_x=raw_x,raw_y=raw_y}
end

local function validate_lure_griffin(d)
    local bus=rawget(_G,"DD2_OxcartControl")
    assert(not bus or not bus.owner, "OJR currently owns the player")
    assert(shared==d.expected and owner==d.player and player_lure_owned(d), "Bound context changed")
    assert(d.expected.go:get_Valid() and d.expected.chara:get_Valid(), "Griffin unavailable")
    assert(d.expected.chara:get_CharaIDString()=="ch253000_00"
        and d.expected.chara:call("get_GameObject()") == d.expected.go, "Griffin binding mismatch")
    assert(friendly and not aggro_conflict(), "Party Friend unavailable")
    for _,member in ipairs(party) do
        assert(d.expected.chara:call("getBattleRelationshipTo(app.Character)",member)==friend_value
            and member:call("getBattleRelationshipTo(app.Character)",d.expected.chara)==friend_value,
            "Party relationship changed")
    end
    local flying=d.expected.chara:call("get_IsFlight()")
    local ctrl=d.expected.chara:call("get_FlightCtrl()")
    assert(ctrl and ctrl:call("get_CachedCharacter()")==d.expected.chara, "Flight controller mismatch")
    local manager=d.expected.chara:call("get_ActionManager()")
    assert(manager and manager:call("get_GameObject()")==d.expected.go, "ActionManager mismatch")
    local info=manager:get_field("CurrentAction")
    local node=info and info:get_field("Name")
    local ch=NickCore.object.get_component(d.expected.go,"app.Ch253")
    local tc=ch and ch:call("get_TargetController()")
    assert(tc and tc:call("get_Owner()")==d.expected.go and tc:call("get_Chara()")==d.expected.chara,
        "TargetController mismatch")
    local player_target=tc:call("get_TargetCharacter()")==d.player
    d.flight_readiness={node=tostring(node),flying=flying,target_is_player=player_target}
    return manager,node,flying,player_target
end

local function start_lure_test()
    if lure or lure_restore_pending or lure_start_pending or relation_pending then return end
    if not shared or not shared.go or not shared.chara then return end
    lure_start_pending = true
    lure_start_cancelled = false
    local expected, player = shared, owner
    run_once(function()
        if lure_start_cancelled then lure_start_pending=false;return end
        local ok,err=pcall(function()
            local core=dependency()
            assert(core and core.properties.player==player and not core.properties.isPaused, "Gameplay unavailable")
            assert(type(re.on_pre_application_entry)=="function" and type(re.on_application_entry)=="function",
                "Application callbacks unavailable")
            assert(not rawget(_G,"DD2_OxcartControl") or not _G.DD2_OxcartControl.owner, "OJR currently owns the player")
            local terrain=player:get_field("<AdjustTerrain>k__BackingField")
            local d={expected=expected,player=player,player_go=player:call("get_GameObject()"),
                transform=player:call("get_Transform()"),context=player:get_field("<PosRotContext>k__BackingField"),
                terrain=terrain,controller=terrain and terrain.MainCharacterController,
                fall=player:get_field("<FallInfo>k__BackingField"),started=game_time(),writes=0}
            assert(d.transform and d.context and d.controller and d.fall, "Player physics interfaces unavailable")
            validate_lure_griffin(d)
            lure_input={x=0,y=0,raw_x=0,raw_y=0}
            d.original_universal=d.transform:call("get_UniversalPosition()")
            assert(d.original_universal, "Original universal position unavailable")
            d.original_scene=vector_values(d.transform:call("get_Position()"))
            assert(#flight_log.samples<650 and #flight_log.events<470, "Use a fresh recording session")
            start_recording() -- renew recorder window; preserve all earlier samples
            log_event("stick_lure_started", "60 gameplay seconds; ahead=20m; stick initially disabled; no action request")
            flight_log.events[#flight_log.events].player_original_scene=d.original_scene
            assert(flush_flight_log(), "Pre-movement log failed")
            lure_stick_enabled=false
            lure=d;lure_input_error=nil
            lure_status="前方固定已开启（最长60秒）；可单独开启摇杆，再手动请求飞行动作。"
        end)
        if not ok then
            lure_status="未开启摇杆测试："..tostring(err)
            log_event("stick_lure_start_blocked",lure_status)
        end
        lure_start_pending=false
    end)
end

local function tick_lure_test()
    local d=lure
    if not d then return end
    local core=dependency()
    if not core or core.properties.isPaused or game_time()<d.started then stop_lure("暂停或游戏上下文变化");return end
    if game_time()-d.started>=60 then stop_lure("60秒固定测试到期");return end
    if lure_stick_enabled and lure_input_error then stop_lure("摇杆读取失败："..lure_input_error);return end
    if not recording then stop_lure("记录已停止或保存失败");return end
    local ok,err=pcall(function()
        validate_lure_griffin(d)
        local tr=d.expected.chara:call("get_Transform()")
        local position=vector_values(tr:call("get_Position()"))
        local q=rotation_values(tr:call("get_Rotation()"))
        local fx,fz=2*(q.x*q.z+q.w*q.y),1-2*(q.x*q.x+q.y*q.y)
        local length=math.sqrt(fx*fx+fz*fz)
        assert(length>0.2,"Griffin forward is too vertical")
        fx,fz=fx/length,fz/length
        local x,y=0,0
        if lure_stick_enabled then x,y=lure_input.x,lure_input.y end
        local point={x=position.x+fx*20+fz*x*12,y=position.y+y*10,z=position.z+fz*20-fx*x*12}
        if not d.moved then
            log_event("stick_lure_first_write", "Player Transform + position context + controller sync")
            flight_log.events[#flight_log.events].target=point
            assert(flush_flight_log(),"Pre-write log failed")
        end
        d.moved=true
        d.transform:call("set_Position(via.vec3)",Vector3f.new(point.x,point.y,point.z))
        synchronize_lure_player(d)
        d.target=point;d.writes=d.writes+1
        d.readback=vector_values(d.transform:call("get_Position()"))
        d.physical=vector_values(d.controller:call("get_Position()"))
        lure_status=lure_stick_enabled and "玩家已固定；摇杆控制已开启。现在可手动请求目标导向飞行。"
            or "玩家已固定在前方20米；摇杆控制未开启。"
    end)
    if not ok then stop_lure("驾驶检查或位置写入失败："..tostring(err)) end
end

if type(re.on_application_entry)=="function" and type(re.on_pre_application_entry)=="function" then
    re.on_application_entry("UpdateHID",function()
        if not lure or not lure_stick_enabled then return end
        local ok,value=pcall(read_lure_stick)
        if ok then lure_input=value;lure_input_error=nil
        else lure_input={x=0,y=0,raw_x=0,raw_y=0};lure_input_error=tostring(value) end
    end)
    -- Supply the real player target before the game's behavior/AI stage.
    re.on_pre_application_entry("UpdateBehavior",tick_lure_test)
end

re.on_script_reset(function()
    lure_start_cancelled=true
    if lure or lure_restore_pending then stop_lure("脚本重置") end
    recording = false
    if request_listener_table and request_listener_table[request_listener_key] == request_listener_fn then
        request_listener_table[request_listener_key] = nil
    end
    if #flight_log.samples > 0 or #flight_log.events > 0 then
        log_event("script_reset", "Flushed available samples before reference loss")
    end
end)

local button_labels = {
    ["Preview nearest enemy as Griffin (40m)"] = "【本轮】1. 查找附近狮鹫（40米）",
    ["Bind PREVIEWED Griffin instance"] = "【本轮】2. 绑定这只狮鹫",
    ["Spawn ONE ordinary Griffin"] = "生成普通狮鹫（不设友方）",
    ["Spawn ThinkStop Griffin + PRE-ARM Friend"] = "没有现成狮鹫：生成并预设友方",
    ["Enable action-name probe (read only)"] = "开启动作探针（只读）",
    ["Disable action-name probe"] = "关闭动作探针",
    ["Read THIS Griffin flight snapshot (no control)"] = "读取一次飞行和动作状态",
    ["Start 60s flight recording (5 Hz)"] = "【本轮】开始完整记录（60秒）",
    ["Stop flight recording + flush log"] = "停止记录并保存",
    ["Inspect returned instance (read only)"] = "查看绑定对象信息（只读）",
    ["Read BOTH relationship directions"] = "读取双方关系",
    ["Enable Friend for THIS Griffin + current party"] = "设为队伍友方（仅这只）",
    ["Disable Friend override"] = "关闭队伍友方",
    ["Read spawn ThinkStop flag"] = "读取生成暂停标志",
    ["Release spawn ThinkStop flag (test)"] = "解除生成暂停（恢复行动）",
    ["Read party/Griffin hate (both ways)"] = "读取双方仇恨",
    ["Clear ONLY party/Griffin hate (once)"] = "清除双方仇恨（一次）",
    ["Unbind THIS Griffin (no despawn)"] = "解除绑定（不删除狮鹫）",
 }
for _, action in ipairs(test_actions) do
    button_labels[action.key] = "【本轮测试】" .. action.label .. "（一次）"
end
button_labels["Toggle cross phase"] = "切换跨阶段测试（允许地面直接请求空中动作）"
button_labels["Yaw left"] = "【本轮转向】左转（一次）"
button_labels["Yaw right"] = "【本轮转向】右转（一次）"
button_labels["Start stick lure"] = "【本轮】1. 固定玩家到狮鹫前方"
button_labels["Enable lure stick"] = "【本轮】2. 开启摇杆控制玩家方位"
button_labels["Disable lure stick"] = "关闭摇杆控制（继续固定正前方）"
button_labels["Stop stick lure"] = "【本轮驾驶】停止／恢复玩家原位置"
local function ui_button(key)
    local label = button_labels[key] or key
    local highlight = label:find("【本轮", 1, true) ~= nil
    local styled = highlight and type(imgui.push_style_color) == "function" and type(imgui.pop_style_color) == "function"
    if styled then
        imgui.push_style_color(21, 0xff98652b) -- ImGuiCol.Button, packed ABGR
        imgui.push_style_color(0, 0xffa8ecff) -- bright text; no dependency on another mod's UI helpers
    end
    local clicked = imgui.button(label .. "###" .. key)
    if styled then imgui.pop_style_color(2) end
    return clicked
end

re.on_draw_ui(function()
    if not imgui.tree_node("狮鹫坐骑实验 - 阶段3###Griffin Mount Experiment - Stage 3 Observe") then return end
    imgui.text("版本：" .. VERSION)
    imgui.text("本轮：固定玩家 → 开启摇杆 → 手动请求目标导向飞行")
    imgui.text("录制会自动包含动作名和原生请求，不必另开探针。")
    if not dependency() then imgui.text("等待 NickCore 加载完成。") end
    imgui.text("绑定来源：" .. (target_origin == "selected" and "现有狮鹫" or target_origin == "spawned" and "本脚本生成" or "尚未绑定"))
    if not shared and state ~= "Queued" then
        if ui_button("Preview nearest enemy as Griffin (40m)") then preview_existing_griffin() end
        if candidate then
            imgui.text("已找到普通狮鹫，对象地址：" .. candidate_status)
            if ui_button("Bind PREVIEWED Griffin instance") then bind_existing_griffin() end
        else
            imgui.text(candidate_status)
        end
    end
    if not submitted and not shared then
        if ui_button("Spawn ThinkStop Griffin + PRE-ARM Friend") then request_spawn(true) end
    end
    if shared and shared.go and shared.chara then
        imgui.text("队伍友方：" .. (friendly and "已开启" or "未开启"))
        if not friendly and ui_button("Enable Friend for THIS Griffin + current party") then queue_relation_action(true) end
        if early_mode and friendly and not release_attempted
            and ui_button("Release spawn ThinkStop flag (test)") then queue_think_flag(true) end
        if not recording and ui_button("Start 60s flight recording (5 Hz)") then start_recording() end
        if recording and ui_button("Stop flight recording + flush log") then
            recording = false
            log_event("recording_stopped", "Manual stop")
        end
        if imgui.tree_node("动作按钮（固定玩家后点目标导向飞行）") then
            imgui.text("每次只点一个动作，关闭界面观察；至少间隔3秒。")
            imgui.text("跨阶段测试：" .. (cross_phase and "已开启" or "关闭（按地面/空中检查）"))
            if ui_button("Toggle cross phase") then
                cross_phase = not cross_phase
                log_event("cross_phase_mode", tostring(cross_phase))
            end
            for _, action in ipairs(test_actions) do
                if ui_button(action.key) then queue_action_test(action) end
            end
            imgui.text("落地按钮是已捕获的下冲攻击，不是平稳降落。")
            imgui.text(action_test_status)
            imgui.tree_pop()
        end
    end
    if shared and shared.go and shared.chara and imgui.tree_node("【本轮】左摇杆驾驶（玩家作为前方目标）") then
        imgui.text("1.固定玩家 → 2.开启摇杆 → 再点目标导向飞行。")
        imgui.text("固定最长60秒；自动记录。左右横移／上下升降，松杆回正前方。")
        if type(imgui.checkbox)=="function" then
            local changed,value=imgui.checkbox("上下反转（推上反而下降时开启）",lure_invert_y)
            if changed then lure_invert_y=value end
        end
        if not lure and not lure_restore_pending and not lure_start_pending and ui_button("Start stick lure") then start_lure_test() end
        if lure and not lure_stick_enabled and ui_button("Enable lure stick") then
            local ok,value=pcall(read_lure_stick)
            if ok then
                lure_stick_enabled=true;lure_input=value;lure_input_error=nil
                log_event("stick_lure_input_enabled","Manual enable; anchor remains active")
            else
                lure_status="已固定玩家，但摇杆无法读取："..tostring(value)
                log_event("stick_lure_input_error",lure_status)
            end
        end
        if lure and lure_stick_enabled and ui_button("Disable lure stick") then
            lure_stick_enabled=false;lure_input={x=0,y=0,raw_x=0,raw_y=0};lure_input_error=nil
            log_event("stick_lure_input_disabled","Keep anchor; return to straight ahead")
        end
        if (lure or lure_restore_pending or lure_start_pending) and ui_button("Stop stick lure") then
            lure_start_cancelled=true
            run_once(function() stop_lure("手动停止") end)
        end
        imgui.text(lure_status)
        if lure then imgui.text(string.format("摇杆 X %.2f / Y %.2f | 位置更新 %d 次",lure_input.x,lure_input.y,lure.writes)) end
        imgui.tree_pop()
    end
    if shared and shared.go and shared.chara and imgui.tree_node("旧版单次旋转测试（本轮不用点）") then
        imgui.text("先进入悬停前移或目标导向飞行，再转向。")
        if type(imgui.slider_int) == "function" then
            local changed, value = imgui.slider_int("【本轮】单次转向角度（度）", yaw_degrees, 5, 180)
            if changed and type(value) == "number" and value == value then
                yaw_degrees = math.max(5, math.min(180, math.floor(value)))
            end
        else
            imgui.text("角度滑条不可用，使用默认45°。")
        end
        if ui_button("Yaw left") then queue_yaw_test(-1) end
        if ui_button("Yaw right") then queue_yaw_test(1) end
        imgui.text(yaw_status)
        imgui.tree_pop()
    end
    imgui.text("录制：" .. (recording and "进行中（60秒后自动保存）" or "未在录制") .. " | 样本：" .. #flight_log.samples .. " | 原生请求：" .. request_event_count)
    imgui.text("日志：reframework/data/" .. flight_log_path)
    if relation_pending then imgui.text("操作已排队，请关闭界面让游戏运行。") end
    if log_status:find("LOG WRITE ERROR", 1, true) then imgui.text("日志保存失败：" .. log_status) end
    local latest = flight_log.samples[#flight_log.samples]
    if latest and next(latest.errors) then imgui.text("最近读取有错误，请展开高级诊断；日志已保留错误。") end
    if imgui.tree_node("高级诊断（平时不用点）") then
        if not submitted and not shared and ui_button("Spawn ONE ordinary Griffin") then request_spawn(false) end
        if shared and shared.go and shared.chara then
        if not action_probe and ui_button("Enable action-name probe (read only)") then
            action_probe = true
            local core = dependency()
            if core then attach_request_observer(core) end
            log_event("action_probe_enabled", "Current/previous action names and body/wing names added to flight samples")
        end
        if action_probe and ui_button("Disable action-name probe") then
            action_probe = false
            log_event("action_probe_disabled", "Manual disable")
        end
        if ui_button("Read THIS Griffin flight snapshot (no control)") then queue_flight_snapshot() end
        if ui_button("Inspect returned instance (read only)") then inspect_instance() end
        if ui_button("Read BOTH relationship directions") then queue_relation_action(false) end
        if friendly and ui_button("Disable Friend override") then disable_friendship() end
        if ui_button("Read spawn ThinkStop flag") then queue_think_flag(false) end
        if ui_button("Read party/Griffin hate (both ways)") then queue_hate_action(false) end
        if friendly and not hate_clear_attempted
            and ui_button("Clear ONLY party/Griffin hate (once)") then queue_hate_action(true) end
        if not recording and ui_button("Unbind THIS Griffin (no despawn)") then unbind_griffin() end
        end
        imgui.text("状态：" .. state .. " | " .. detail)
        imgui.text(identity)
        imgui.text(flight_status)
        imgui.text(log_status)
        imgui.text(request_listener_status)
        imgui.text(target_probe_status)
        imgui.text(relation_status)
        imgui.text(think_status)
        imgui.text(hate_status)
        for _, row in ipairs(flight_rows) do imgui.text(row) end
        for _, row in ipairs(relation_rows) do imgui.text(row) end
        for _, row in ipairs(hate_rows) do imgui.text(row) end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
