return function(ctx)
local _ENV=ctx
function read_camera_follow()
    if not debug_tools or not debug_tools:recording() then return end
    local d,s=active,follow_state
    if not d or not s then return end
    local ok,probe=pcall(function()
        return {mode=camera_mode,target=vector(s.main:call("get_TargetPosition()")),
            base_offset=vector(s.main:call("get_BaseOffset()")),
            selected=s.joint and vector(s.joint:call("get_Position()")) or nil,
            readback_matches=not s.joint or s.main:call("get_TargetJoint()")==s.joint,
            player=vector(d.transform:call("get_Position()")),
            hip=d.hip_joint and vector(d.hip_joint:call("get_Position()")) or nil,
            griffin=vector(d.spawn.result.chara:call("get_Transform()"):call("get_Position()"))}
    end)
    if d.trace then d.trace.camera_follow=ok and probe or {mode=camera_mode,error=tostring(probe)} end
end
end
