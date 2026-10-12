-- Requires installed NickCore run_once and GriffinFlightBetaBridge for explicit binding.
local Lab = require("_GriffinAnimationLab.lab")
local lab = Lab.new()
re.on_frame(function() lab:tick() end)
re.on_draw_ui(function() lab:draw() end)
re.on_script_reset(function() lab:shutdown() end)
