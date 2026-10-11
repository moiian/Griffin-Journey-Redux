-- Griffin Mount Experiment: stage 2 relationship query experiment.
-- Requires the installed aaaNickCore.lua and _NickCore/EnemySpawner.lua.
-- Keeps spawn_enemy's returned table; never searches by Character ID.
local VERSION = "0.2.0-stage2"
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

local function request_spawn()
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
        local ok, result = pcall(core.enemySpawner.spawn_enemy, "Griffin", nil, false)
        if not ok then
            report("Lua error", tostring(result) .. "; no automatic retry.")
            return
        end
        if type(result) ~= "table" then
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

re.on_draw_ui(function()
    if not imgui.tree_node("Griffin Mount Experiment - Stage 2") then return end
    imgui.text("Version: " .. VERSION)
    imgui.text("Dependency: installed NickCore enemySpawner + run_once")
    imgui.text("Ordinary Griffin / ch253000_00 / thinkStop=false")
    imgui.text("Status: " .. state)
    imgui.text(detail)
    if not dependency() then imgui.text("NickCore is not ready. No standalone fallback.") end
    if not submitted and imgui.button("Spawn ONE ordinary Griffin") then request_spawn() end
    if shared and shared.go and shared.chara then
        if imgui.button("Inspect returned instance (read only)") then inspect_instance() end
        if imgui.button("Read BOTH relationship directions") then queue_relation_action(false) end
        if not friendly and imgui.button("Enable Friend for THIS Griffin + current party") then
            queue_relation_action(true)
        end
        if friendly and imgui.button("Disable Friend override") then disable_friendship() end
    end
    imgui.text(identity)
    imgui.text(relation_status)
    imgui.text("Friend enum (runtime metadata): " .. tostring(friend_value or "not read yet"))
    if relation_pending then imgui.text("Relationship action queued. Close UI and let gameplay run.") end
    imgui.text("Hits Griffin->party / party->Griffin | Character: " .. hits.Character[1] .. "/" .. hits.Character[2]
        .. " | Holder: " .. hits.Holder[1] .. "/" .. hits.Holder[2])
    for _, row in ipairs(relation_rows) do imgui.text(row) end
    imgui.text("Party snapshot: disable/re-enable after changing party. Other creatures pass through.")
    imgui.text("Read button also counts as hook hits. Observe AI behaviour separately.")
    imgui.text("No global faction writes, hate clearing, flight or riding edits.")
    imgui.text("One request per session. Script reset loses ownership; it does not despawn.")
    imgui.tree_pop()
end)
