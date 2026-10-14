-- Griffin Journey Redux 0.3.18. Requires NickCore, EnemySpawner and run_once.
-- One private context per script generation. Only the compatible state/bridge aliases are global.
local ctx=setmetatable({}, {__index=_G})
require("_GriffinJourneyRedux.session")(ctx)
require("_GriffinJourneyRedux.ownership")(ctx)
require("_GriffinJourneyRedux.player")(ctx)
require("_GriffinJourneyRedux.camera")(ctx)
require("_GriffinJourneyRedux.lifecycle")(ctx)
require("_GriffinJourneyRedux.input")(ctx)
require("_GriffinJourneyRedux.griffin")(ctx)
require("_GriffinJourneyRedux.ai_takeover")(ctx)
require("_GriffinJourneyRedux.sprint_motion")(ctx)
require("_GriffinJourneyRedux.hover_collision")(ctx)
require("_GriffinJourneyRedux.hover_motion")(ctx)
require("_GriffinJourneyRedux.flight")(ctx)
require("_GriffinJourneyRedux.seating")(ctx)
require("_GriffinJourneyRedux.protection")(ctx)
require("_GriffinJourneyRedux.passengers")(ctx)
require("_GriffinJourneyRedux.spawning")(ctx)
require("_GriffinJourneyRedux.summoning")(ctx)
require("_GriffinJourneyRedux.presets")(ctx)
local available,developer_tools=pcall(require,"_GriffinJourneyReduxDebug.tools")
if available then
    local initialized,err=pcall(developer_tools,ctx)
    if not initialized then error("Griffin Journey Redux Debug: "..tostring(err)) end
end
require("_GriffinJourneyRedux.callbacks")(ctx)
require("_GriffinJourneyRedux.ui")(ctx)
