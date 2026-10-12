-- Opt-in recording only; no hooks, position changes, or per-frame disk writes.
local M={}
function M.new()
    local self={enabled=false,status="关闭",next_sample=0,last_flush=0,
        path="GriffinAnimationLab_"..os.date("!%Y%m%dT%H%M%SZ").."_"..math.floor(os.clock()*1000)..".json",
        data={version="0.1.0",events={},samples={}}}
    function self:flush()
        if #self.data.events==0 and #self.data.samples==0 then return end
        local ok,result=pcall(json.dump_file,self.path,self.data)
        self.status=ok and result~=false and self.path or "写入失败"
    end
    function self:event(message)
        if not self.enabled then return end
        if #self.data.events<1000 then self.data.events[#self.data.events+1]={time=os.clock(),message=message} end
        self:flush()
    end
    function self:tick(isolation)
        if not self.enabled then return end
        local now=os.clock()
        if now<self.next_sample then return end
        self.next_sample=now+0.2
        local d=isolation.active
        if d and not d.recovering and #self.data.samples<3000 then
            local ok,row=pcall(function()
                assert(isolation:valid(d),"对象失效")
                local t=d.instance.chara:call("get_Transform()")
                local p=t:call("get_UniversalPosition()")
                return {time=now,clip=d.clip,blocked=isolation.blocked,
                    character=tostring(d.instance.chara:get_address()),position={x=p.x,y=p.y,z=p.z},
                    root_motion=d.motion:call("get_RootMotion()"),fsm_enabled=d.fsm:call("get_Enabled()")}
            end)
            if ok then self.data.samples[#self.data.samples+1]=row else self.status="采样失败："..tostring(row) end
        end
        if now-self.last_flush>=2 then self.last_flush=now;self:flush() end
    end
    return self
end
return M
