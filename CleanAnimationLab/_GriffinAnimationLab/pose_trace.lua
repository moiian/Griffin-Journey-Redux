-- Read-only callbacks after motion replacement. No argument conversion or native skip.
local Trace=require("_GriffinAnimationLab.call_trace")
local M={}
function M.new(recorder)
    local function flight(ch) return ch:call("get_FlightCtrl()") end
    local function owns(obj,ch) return obj:call("get_CachedCharacter()")==ch end
    return Trace.new(recorder,{flag="trace_pose",data_key="pose_trace",label="位置入口跟踪",methods={
        {type="app.FlightControl",method="updatePosition()",key="flight_position",get=flight,owns=owns,params=0},
        {type="app.FlightControl",method="eventBeforeColliderAdjust(via.GameObject)",key="before_collider",get=flight,owns=owns,params=1},
        {type="app.FlightControl",method="eventAfterColliderAdjust(via.GameObject, via.motion.ExpressionUpdate)",key="after_collider",get=flight,owns=owns,params=2},
        {type="app.Character",method="onRootApply(via.vec3, via.Quaternion)",key="root_apply",get=function(ch) return ch end,params=2},
    }})
end
return M
