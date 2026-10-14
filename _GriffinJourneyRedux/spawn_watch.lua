-- Exact-instance lifecycle checks. Never search/delete every Griffin in the scene.
return function(ctx)
local _ENV=ctx
spawn_watch={status="狮鹫生命周期：等待实例",last_reason=nil,removed=0,reads={},errors=0}
local watch=spawn_watch
state.pending_cleanup=state.pending_cleanup or {}
local function current() return alive and state.generation==generation end
local function valid(object) return object and object:get_Valid()==true end
local function flag(ch,name)
    local ok,value=pcall(ch.call,ch,name.."()")
    if ok and type(value)=="boolean" then watch.reads[name]=true;return value end
    watch.reads[name]=false
    return nil
end
function watch:mountable(r)
    if not r or r.deleted or r.delete_requested or r.sinking then return false,"狮鹫正在退出或清理" end
    if not r.ready then return false,"请等待狮鹫初始化完成" end
    local ch=r.result and r.result.chara
    if not valid(ch) then return false,"狮鹫实例已失效" end
    if flag(ch,"get_IsDead") or flag(ch,"get_IsFallDead") then return false,"狮鹫已死亡" end
    if flag(ch,"get_IsDown") then return false,"狮鹫已被击倒" end
    return true
end
local function remove_record(index,reason)
    local r=state.spawns[index]
    r.friend=false;r.deleted=true
    table.remove(state.spawns,index)
    if skip_think_expected==r then skip_think_enabled=false;skip_think_expected=nil end
    watch.removed=watch.removed+1;watch.last_reason=reason
    watch.status="狮鹫生命周期：已回收记录／"..reason
    event("spawn_record_reaped",{reason=reason})
end
-- Read-only native validity checks; safe to call from item eligibility hooks.
-- No destruction, driver release or other native mutation runs inside those hooks.
function watch:reap_invalid()
    if not current() then return end
    for i=#state.spawns,1,-1 do
        local r=state.spawns[i]
        if not (active and active.spawn==r) and not (state.recovery and state.recovery.spawn==r) then
            local result=r.result
            local ok,gone=pcall(function()
                return r.deleted or (result and result.go and not valid(result.go))
                    or (r.ready and (not result or not result.go))
            end)
            if ok and gone then remove_record(i,"游戏已清除实例") end
        end
    end
end
local function exit(r,reason)
    watch.last_reason=reason;watch.status="狮鹫生命周期："..reason
    if active and active.spawn==r then
        stop_driver(reason)
        event("driver_boundary_exit",{reason=reason})
    end
end
local function retire(r,reason)
    r.cleanup_reason=reason;r.delete_requested=true
    exit(r,reason)
    if state.recovery and state.recovery.spawn==r then return end
    if skip_think_expected==r then skip_think_enabled=false;skip_think_expected=nil end
    local result=r.result
    if not result or not result.go or not valid(result.go) then
        if r.ready or r.deleted then r.deleted=true;r.friend=false end
    else delete_one(r) end
end
local function sample(r,t)
    if r.deleted then exit(r,"狮鹫记录已清理");return end
    local result=r.result
    if not result or not result.go or not result.chara then
        if r.ready then retire(r,"狮鹫引用已消失");return end
        r.spawn_wait_started=r.spawn_wait_started or t
        if t<r.spawn_wait_started then r.spawn_wait_started=t end
        if t-r.spawn_wait_started>=45 then
            -- Keep the returned mutable table so an unusually late NickCore result can
            -- still be destroyed. Do not forget it and leave a late orphan behind.
            r.friend=false;r.delete_requested=true;r.cleanup_reason="生成等待超时"
            for i=#state.spawns,1,-1 do
                if state.spawns[i]==r then table.remove(state.spawns,i);break end
            end
            state.pending_cleanup[#state.pending_cleanup+1]=r
            watch.last_reason=r.cleanup_reason;watch.status="狮鹫生命周期：生成超时，保留迟到实例清理记录"
            event("spawn_wait_timeout",{pending=#state.pending_cleanup})
        end
        return
    end
    if not valid(result.go) then retire(r,"狮鹫被游戏清除");return end
    if not valid(result.chara) then retire(r,"狮鹫角色已失效");return end
    local ch=result.chara
    if ch:call("get_GameObject()")~=result.go or ch:get_CharaIDString()~="ch253000_00" then
        exit(r,"狮鹫归属发生变化")
        if not state.recovery then r.deleted=true;r.friend=false end
        event("spawn_identity_lost","Unknown object not destroyed")
        return
    end
    if r.sinking then retire(r,"狮鹫进入沉水死亡流程");return end
    if flag(ch,"get_IsDead") or flag(ch,"get_IsFallDead") then retire(r,"狮鹫已死亡");return end
    if flag(ch,"get_IsDown") then exit(r,"狮鹫被击倒（普通受击除外）") end
    local c=core();local owner=c and c.properties.player
    if owner and r.owner~=owner then retire(r,"玩家实例已变化");return end
    if owner and valid(owner) and flag(owner,"get_IsDead") then retire(r,"玩家已死亡");return end
    if not r.ready then return end
    if not r.ready_at or t<r.ready_at then r.ready_at=t end
    if active or state.recovery or t-r.ready_at<10 then return end
    if r.next_distance and t<r.next_distance then return end
    r.next_distance=t+.2
    if owner and valid(owner) then
        local a=vector(owner:call("get_Transform()"):call("get_UniversalPosition()"))
        local b=vector(ch:call("get_Transform()"):call("get_UniversalPosition()"))
        local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z
        r.player_distance=math.sqrt(dx*dx+dy*dy+dz*dz)
        if r.player_distance>30 then retire(r,"玩家离狮鹫超过30米") end
    end
end
function watch:tick()
    if not current() then return end
    local ok,err=pcall(function()
        self:reap_invalid()
        local c=core()
        if not c or menu.gameplay_paused() then return end
        local main_ok,main=pcall(sdk.get_managed_singleton,"app.MainFlowManager")
        if not main_ok or not main then return end -- singleton may not exist during loading
        if not main:call("get_IsInGamePhase()") then
            if active then stop_driver("已离开游戏阶段") end
            return
        end
        local t=now()
        if self.last_time and t<self.last_time then
            self.next_idle=nil;self.next_recovery=nil
            for _,r in ipairs(state.spawns) do r.next_distance=nil end
        end
        self.last_time=t
        if state.recovery and (not self.next_recovery or t>=self.next_recovery) then
            self.next_recovery=t+.5;stop_driver("自动重试玩家与乘客释放")
        end
        if active or not self.next_idle or t>=self.next_idle then
            self.next_idle=t+.2
            for i=#state.spawns,1,-1 do sample(state.spawns[i],t) end
        end
        for i=#state.pending_cleanup,1,-1 do
            local r=state.pending_cleanup[i]
            if r.deleted then table.remove(state.pending_cleanup,i)
            elseif r.result and r.result.go then
                if not valid(r.result.go) then table.remove(state.pending_cleanup,i)
                else delete_one(r) end
            end
        end
        self:reap_invalid()
    end)
    if not ok then
        self.errors=self.errors+1;self.status="狮鹫生命周期：检查失败 "..tostring(err)
        if active then pcall(stop_driver,"狮鹫生命周期检查失败") end
    end
end
-- Observe native sink activation, rather than treating wetness/water below as drowning.
local td=sdk.find_type_definition("app.SinkDieReactionController")
local signature="activate(System.Boolean,System.Boolean,System.Boolean,System.Boolean,System.Boolean)"
local method=td and (td:get_method(signature) or td:get_method((signature:gsub(",",", "))))
watch.sink_hook=method~=nil
if method then
    sdk.hook(method,function(args)
        if not current() then return end
        local ok,err=pcall(function()
            local controller=sdk.to_managed_object(args[2])
            for _,r in ipairs(state.spawns) do
                local ch=r.result and r.result.chara
                if not r.deleted and valid(ch) and ch:call("get_SinkDieReaction()")==controller then r.sinking=true end
            end
        end)
        if not ok then watch.errors=watch.errors+1;watch.status="狮鹫生命周期：沉水观察失败 "..tostring(err) end
    end,function(ret) return ret end)
end
end
