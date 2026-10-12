-- Called only by the opt-in route probe at three existing stage boundaries.
-- Values retain native names/units; no native updates, writes, or hooks.
local M={}
local function number(v)
    assert(type(v)=="number" and v==v and math.abs(v)<math.huge,"Invalid native number")
    return v
end
local function boolean(v) assert(type(v)=="boolean","Invalid native Boolean");return v end
local function vec(v)
    assert(v,"Missing native vector")
    return {x=number(v.x),y=number(v.y),z=number(v.z)}
end
function M.capture(d,row,group)
    group("fall_gravity_flag",function()
        row.gravity_disabled_until_motion_end=boolean(d.player:get_field("IsDisableGravityUntilMotionEnd"))
    end)
    group("free_fall",function()
        local obj=d.player:get_field("<FreeFallCtrl>k__BackingField")
        if not obj then row.free_fall={available=false};return end
        local v={available=true,instance=tostring(obj)}
        v.active=boolean(obj:get_field("<IsActive>k__BackingField"))
        v.rise=boolean(obj:get_field("<IsRise>k__BackingField"))
        v.process_id=number(obj:get_field("<ProcessID>k__BackingField"))
        v.initial_frame_speed=vec(obj:get_field("<InitialFrameSpeed>k__BackingField"))
        for key,field in pairs({frame="Frame",frame_gravity="FrameGravity",default_frame_gravity="DefaultFrameGravity",
            add_frame_for_gravity="AddFrameForGravity",max_fall_frame_speed="MaxFallFrameSpeed"}) do
            v[key]=number(obj:get_field(field))
        end
        row.free_fall=v
    end)
    group("controller_ground",function()
        -- The caller's existing exact-player ownership gate validates MainCharacterController.
        -- This native physics query is separate from app.Character.get_IsGround.
        row.controller_ground=boolean(d.controller:call("get_Ground()"))
        row.controller_ground_contacts=number(d.controller:call("get_NumGroundContactPoints()"))
        row.controller_gravity_direction=vec(d.controller:call("get_GravityDirection()"))
    end)
end
return M
