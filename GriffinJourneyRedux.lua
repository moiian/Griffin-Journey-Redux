-- Griffin Journey Redux 0.3.48. Requires NickCore, EnemySpawner and run_once.
-- One private context per script generation. Only the compatible state/bridge aliases are global.
-- REFramework's autorun search paths do not survive into deferred callbacks.
-- Resolve this mod's modules from the entry file, without changing global paths.
local native_require=require
local base=debug.getinfo(1,"S").source:match("^@(.*[/\\])") or "reframework/autorun/"
local module_env=setmetatable({}, {__index=_G})
local function require(name)
    if not name:match("^_GriffinJourneyRedux[./]") and not name:match("^_GriffinJourneyReduxDebug[./]") then
        return native_require(name)
    end
    if package.loaded[name]~=nil then return package.loaded[name] end
    local chunk,err=loadfile(base..name:gsub("%.","/")..".lua","t",module_env)
    assert(chunk,err)
    local value=chunk()
    if value==nil then value=true end
    package.loaded[name]=value
    return value
end
module_env.require=require
return require("_GriffinJourneyRedux.world")(function(ctx)
ctx.require=require
require("_GriffinJourneyRedux.session")(ctx)
require("_GriffinJourneyRedux.ownership")(ctx)
require("_GriffinJourneyRedux.player")(ctx)
require("_GriffinJourneyRedux.camera")(ctx)
require("_GriffinJourneyRedux.lifecycle")(ctx)
require("_GriffinJourneyRedux.input")(ctx)
require("_GriffinJourneyRedux.griffin")(ctx)
require("_GriffinJourneyRedux.sprint_motion")(ctx)
require("_GriffinJourneyRedux.hover_collision")(ctx)
require("_GriffinJourneyRedux.hover_motion")(ctx)
require("_GriffinJourneyRedux.flight")(ctx)
require("_GriffinJourneyRedux.seating")(ctx)
require("_GriffinJourneyRedux.protection")(ctx)
require("_GriffinJourneyRedux.passengers")(ctx)
require("_GriffinJourneyRedux.spawning")(ctx)
require("_GriffinJourneyRedux.spawn_watch")(ctx)
require("_GriffinJourneyRedux.summoning")(ctx)
require("_GriffinJourneyRedux.consumables")(ctx)
require("_GriffinJourneyRedux.item_integration")(ctx)
require("_GriffinJourneyRedux.shop_item")(ctx)
require("_GriffinJourneyRedux.presets")(ctx)
require("_GriffinJourneyRedux.hud")(ctx)
require("_GriffinJourneyRedux.settings_editor")(ctx)
require("_GriffinJourneyRedux.callbacks")(ctx)
local available,developer_tools=pcall(require,"_GriffinJourneyReduxDebug.addon")
if available then
    local initialized,err=pcall(developer_tools,ctx)
    if not initialized then error("Griffin Journey Redux Debug: "..tostring(err)) end
end
require("_GriffinJourneyRedux.ui")(ctx)

end)
