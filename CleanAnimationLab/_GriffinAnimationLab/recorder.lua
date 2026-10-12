-- Opt-in, bounded read-only recording in NickCore's behavior queue.
local Probe=require("_GriffinAnimationLab.state_probe")
local M={}
function M.new()
    local self={enabled=false,status="关闭",next_sample=0,last_flush=0,
        path="GriffinAnimationLab_"..os.date("!%Y%m%dT%H%M%SZ").."_"..math.floor(os.clock()*1000)..".json",
        data={version="0.1.4",events={},samples={},sample_limit=3000,sample_hz=20}}
    function self:flush()
        if #self.data.events==0 and #self.data.samples==0 then return end
        local ok,result=pcall(json.dump_file,self.path,self.data)
        self.status=ok and result~=false and self.path or "写入失败"
    end
    function self:snapshot(lab,phase)
        local ok,row=pcall(Probe.read,lab.instance,lab.isolation,phase)
        if ok then
            if lab.refresh then
                local w=lab.refresh.wait
                row.refresh={pending=w~=nil,requests=lab.refresh.requests,returned=lab.refresh.returned,
                    completed=lab.refresh.completed,failed=lab.refresh.failed,behavior=lab.refresh.behavior,
                    elapsed=w and w.elapsed or nil}
            end
            return row
        end
        return {time=os.clock(),phase=phase,errors={snapshot=tostring(row)}}
    end
    function self:event(message,lab,phase)
        if not self.enabled then return end
        if #self.data.events<1000 then
            local row={time=os.clock(),message=message}
            if lab then row.state=self:snapshot(lab,phase) end
            self.data.events[#self.data.events+1]=row
        end
        self:flush()
    end
    function self:tick(lab)
        if not self.enabled then return end
        local now=os.clock()
        if now-self.last_flush>=2 then self.last_flush=now;self:flush() end
        if self.pending or now<self.next_sample or not lab.instance or not lab.bound or #self.data.samples>=3000 then return end
        self.next_sample=now+0.05
        self.pending=true
        local instance,rev=lab.instance,lab.revision
        run_once(function()
            self.pending=false
            local core=rawget(_G,"NickCore")
            if not self.enabled or not lab.alive or not lab.bound or lab.instance~=instance or rev~=lab.revision
                or not core or core.properties.isPaused then return end
            local bridge=rawget(_G,"GriffinFlightBetaBridge")
            local ok,current=pcall(function() return bridge and bridge.get_instance()==instance end)
            if not ok or not current then return end
            local row=self:snapshot(lab,"sample")
            self.data.samples[#self.data.samples+1]=row
            self.latest=row
        end)
    end
    return self
end
return M
