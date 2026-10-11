-- Griffin Mount Experiment: stage 1 only.
-- Requires the installed aaaNickCore.lua and _NickCore/EnemySpawner.lua.
-- Keeps spawn_enemy's returned table; never searches by Character ID.
local VERSION = "0.1.0-stage1"
local state = "Idle"
local detail = "Ready for one ordinary Griffin request per script session."
local shared = nil
local owner = nil
local started = nil
local submitted = false
local identity = "Not inspected"

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
        shared = nil
        report("Detached", "Player context changed. References discarded; no world object removed.")
        return
    end
    -- Only Lua table reads here: no repeated native validity/AI calls.
    if (state == "Waiting" or state == "Delayed") and shared.go and shared.chara then
        report("References ready", "Returned go and chara are present. Visually verify the Griffin.")
    elseif state == "Waiting" and started and core.properties.gameTime - started > 20 then
        report("Delayed", "20 gameplay seconds elapsed. Still observing the same request; do not spawn again.")
    end
end)

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
    if not imgui.tree_node("Griffin Mount Experiment - Stage 1") then return end
    imgui.text("Version: " .. VERSION)
    imgui.text("Dependency: installed NickCore enemySpawner + run_once")
    imgui.text("Ordinary Griffin / ch253000_00 / thinkStop=false")
    imgui.text("Status: " .. state)
    imgui.text(detail)
    if not dependency() then imgui.text("NickCore is not ready. No standalone fallback.") end
    if not submitted and imgui.button("Spawn ONE ordinary Griffin") then request_spawn() end
    if shared and shared.go and shared.chara then
        if imgui.button("Inspect returned instance (read only)") then inspect_instance() end
    end
    imgui.text(identity)
    imgui.text("Stage 1: normal hostile AI. No friendship, flight or riding edits.")
    imgui.text("One request per session. Script reset loses ownership; it does not despawn.")
    imgui.tree_pop()
end)
