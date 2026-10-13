-- Gameplay anti-jitter; independent of optional developer diagnostics.
local FallStop=require("_GriffinJourneyRedux.fall_stop")
local M={};M.__index=M
function M.new(env)
    return setmetatable({env=env,fall_stop=FallStop.new(env),griffin_stop=FallStop.new(env,"griffin")},M)
end
function M:after_anchor(d) self.fall_stop:after_anchor(d) end
function M:after_passenger(d,a) self.fall_stop:after_passenger(d,a) end
function M:forget_passenger(a) self.fall_stop:forget_passenger(a) end
function M:after_behavior() local d=self.env.driver();if d then self.griffin_stop:after_anchor(d) end end
function M:tick() self.fall_stop:tick();self.griffin_stop:tick() end
function M:stop() self.fall_stop:release_driver();self.griffin_stop:release_driver() end
function M:shutdown() self.fall_stop:set_enabled(false,"脚本结束");self.griffin_stop:set_enabled(false,"脚本结束");self:stop() end
return M
