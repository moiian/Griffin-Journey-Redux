-- Griffin Mount Experiment: stage 3 read-only flight observation.
-- Requires the installed aaaNickCore.lua and _NickCore/EnemySpawner.lua.
-- Keeps spawn_enemy's returned table; never searches by Character ID.
local VERSION = "0.3.0-stage3-observe"
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

local function disable_friendship(message)
    friendly = false
    party = {}
    relation_rows = {}
    relation_status = message or "Disabled. Original query results pass through."
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
    relation_status = "Enabled for returned Griffin + " .. #party .. " party members."
end

local function request_spawn(early)
    if submitted then return end
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
        report("Waiting", "Returned table retained; waiting for go and chara.")
    end)
end

re.on_frame(function()
    if not shared then return end
    local core = dependency()
    if not core or core.properties.player ~= owner then
        disable_friendship("Disabled: player context changed.")
        shared = nil
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

local function queue_flight_snapshot()
    if relation_pending or not shared or not shared.go or not shared.chara then return end
    relation_pending = true
    local expected = shared
    run_once(function()
        flight_rows = {}
        local ok, err = pcall(function()
            local core = dependency()
            assert(core and core.properties.player == owner and shared == expected, "Instance context changed")
            assert(expected.go:get_Valid(), "Spawned GameObject is invalid")
            local function row(label, getter)
                local success, value = pcall(getter)
                local text = label .. " = " .. (success and tostring(value) or ("READ ERROR: " .. tostring(value)))
                flight_rows[#flight_rows + 1] = text
                log.error("[GriffinMountExperiment] Flight " .. text)
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
            flight_status = "Snapshot complete. Read errors, if any, are shown below. No flight state was written."
        end)
        if not ok then flight_status = "Flight snapshot error: " .. tostring(err) end
        log.error("[GriffinMountExperiment] " .. flight_status)
        relation_pending = false
    end)
end

re.on_draw_ui(function()
    if not imgui.tree_node("Griffin Mount Experiment - Stage 3 Observe") then return end
    imgui.text("Version: " .. VERSION)
    imgui.text("Dependency: installed NickCore enemySpawner + run_once")
    imgui.text("Ordinary Griffin / ch253000_00 / requested thinkStop=" .. tostring(early_mode))
    imgui.text("Status: " .. state)
    imgui.text(detail)
    if not dependency() then imgui.text("NickCore is not ready. No standalone fallback.") end
    if not submitted then
        if imgui.button("Spawn ONE ordinary Griffin") then request_spawn(false) end
        if not submitted and imgui.button("Spawn ThinkStop Griffin + PRE-ARM Friend") then request_spawn(true) end
    end
    if shared and shared.go and shared.chara then
        if imgui.button("Read THIS Griffin flight snapshot (no control)") then queue_flight_snapshot() end
        if imgui.button("Inspect returned instance (read only)") then inspect_instance() end
        if imgui.button("Read BOTH relationship directions") then queue_relation_action(false) end
        if not friendly and imgui.button("Enable Friend for THIS Griffin + current party") then
            queue_relation_action(true)
        end
        if friendly and imgui.button("Disable Friend override") then disable_friendship() end
        if imgui.button("Read spawn ThinkStop flag") then queue_think_flag(false) end
        if early_mode and friendly and not release_attempted
            and imgui.button("Release spawn ThinkStop flag (test)") then queue_think_flag(true) end
        if imgui.button("Read party/Griffin hate (both ways)") then queue_hate_action(false) end
        if friendly and not hate_clear_attempted
            and imgui.button("Clear ONLY party/Griffin hate (once)") then queue_hate_action(true) end
    end
    imgui.text(identity)
    imgui.text(flight_status)
    for _, row in ipairs(flight_rows) do imgui.text(row) end
    imgui.text(relation_status)
    imgui.text(think_status)
    if early_mode then
        imgui.text("Pre-armed filter binds only when NickCore fills returned chara; initialization gap is unproven.")
        imgui.text("ThinkStop release resumed AI in prior tests; check movement in this session.")
    end
    imgui.text("Friend enum (runtime metadata): " .. tostring(friend_value or "not read yet"))
    if relation_pending then imgui.text("Relationship action queued. Close UI and let gameplay run.") end
    imgui.text("Hits Griffin->party / party->Griffin | Character: " .. hits.Character[1] .. "/" .. hits.Character[2]
        .. " | Holder: " .. hits.Holder[1] .. "/" .. hits.Holder[2])
    for _, row in ipairs(relation_rows) do imgui.text(row) end
    imgui.text(hate_status)
    for _, row in ipairs(hate_rows) do imgui.text(row) end
    imgui.text("Party snapshot: disable/re-enable after changing party. Other creatures pass through.")
    imgui.text("Read button also counts as hook hits. Observe AI behaviour separately.")
    imgui.text("Hate clear is manual, pair-only, once per session. No AI reset or damage blocking.")
    imgui.text("No global faction writes, flight or riding edits.")
    imgui.text("One request per session. Script reset loses ownership; it does not despawn.")
    imgui.tree_pop()
end)
