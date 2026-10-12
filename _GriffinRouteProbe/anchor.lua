-- A session-only navigation-center comparison. No native setters here.
local Anchor={};Anchor.__index=Anchor
local function vec(v) return {x=v.x,y=v.y,z=v.z} end
function Anchor.new() return setmetatable({enabled=false},Anchor) end
function Anchor:set_enabled(value)
    self.enabled=value==true;self.driver=nil;self.transform=nil;self.offset=nil
end
function Anchor:resolve(driver,transform,head,fx,fz)
    if not self.enabled then return vec(head),{mode="head"} end
    local root=transform:call("get_Position()")
    if self.driver~=driver or self.transform~=transform then
        local dx,dy,dz=head.x-root.x,head.y-root.y,head.z-root.z
        self.offset={side=dx*fz-dz*fx,height=dy,forward=dx*fx+dz*fz}
        self.driver=driver;self.transform=transform
    end
    local o=self.offset
    local center={x=root.x+o.forward*fx+o.side*fz,y=root.y+o.height,
        z=root.z+o.forward*fz-o.side*fx}
    return center,{mode="root_fixed_offset",offset={side=o.side,height=o.height,forward=o.forward}}
end
return Anchor
