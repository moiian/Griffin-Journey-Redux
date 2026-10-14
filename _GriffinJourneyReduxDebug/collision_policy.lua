return function(ctx)
local _ENV=ctx
local guard=hover_collision
function guard:set_return_to_safe(value)
    self.return_to_safe=value==true
    self.block_policy=value and function(m)
        local safe=m.collision_safe
        if safe then m.position={x=safe.position.x,y=safe.position.y,z=safe.position.z};m.yaw=safe.yaw end
        m.rebase_after_block=nil
    end or nil
    self:set_enabled(self.enabled)
end
end
