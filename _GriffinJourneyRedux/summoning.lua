-- Forgery performance followed by an exact-instance spawn, sharing spawning.lua.
return function(ctx)
local _ENV=ctx
summon={status="召唤演出：未运行"}
for key,default in pairs({summon_height=25.2,summon_forward=10.094,summon_delay=4.1}) do
    local value=loaded_settings and loaded_settings[key]
    settings[key]=finite(value) and math.max(0,math.min(key=="summon_delay" and 30 or 50,value)) or default
end
local function flow_instance()
    local td=sdk.find_type_definition("app.AppSingleton`1<app.FerrystoneFlowController>")
    local field=td and td:get_field("_Instance")
    local flow=assert(field and field:get_data(),"飞石演出控制器尚未就绪")
    assert(flow:get_type_definition():get_full_name()=="app.FerrystoneFlowController","飞石控制器类型不符")
    return flow
end
local function can_start(allow_paused)
    local c=assert(core(),"等待 NickCore 加载")
    assert(alive and state.generation==generation,"脚本已重载")
    assert(not active and not state.recovery and not queued and #state.spawns==0,"请先结束驾驶并删除已有狮鹫")
    assert(not menu.photo_active(),"请关闭照片模式")
    assert(allow_paused or not menu.gameplay_paused(),"请关闭暂停或照片模式")
    local main=sdk.get_managed_singleton("app.MainFlowManager")
    assert(main and main:call("get_IsInGamePhase()"),"请进入游戏")
    local experiment=rawget(_G,"GriffinMountExperimentControl")
    assert(not experiment or not experiment.is_driving or not experiment.is_driving(),"请先结束实验工具驾驶")
    local bus=rawget(_G,"DD2_OxcartControl")
    assert(not bus or not bus.owner,"请先结束牛车驾驶")
    local owner=assert(c.properties.player,"玩家尚未就绪")
    assert(owner:get_Valid(),"玩家已失效")
    local tr=owner:call("get_Transform()")
    assert(tr and tr==c.properties.transform,"玩家位置接口已变化")
    local flow=flow_instance()
    assert(flow:call("get_IsActive()")==false and flow:get_field("Routine")==0,"已有飞石演出正在运行")
    for _,field in ipairs({"<Director>k__BackingField","Param","Updater"}) do
        assert(flow:get_field(field),"飞石演出接口尚未就绪："..field)
    end
    return owner,tr,flow
end
function summon:cancel(reason)
    if not self.current then return end
    self.current=nil
    self.status="召唤演出已取消："..tostring(reason)
end
local function begin_request(request)
    run_once(function()
        if not alive or state.generation~=generation or summon.current~=request then return end
        local started,err=pcall(function()
            local player,transform,controller=can_start()
            assert(player==request.owner and transform==request.transform and controller==request.flow,"玩家或演出控制器已变化")
            request.flow:call("startForgery()")
            request.last=now();request.stage="playing"
            assert(request.flow:call("get_IsActive()")==true and request.flow:get_field("Routine")==7,"赝品演出未进入运行状态")
            summon.status=string.format("召唤演出：开始后 %.2f 秒生成狮鹫",request.delay)
        end)
        if not started then summon:cancel(err) end
    end)
end
function summon:request(wait_for_resume)
    wait_for_resume=wait_for_resume==true
    if self.current then return false,"召唤演出正在运行" end
    local ok,owner,tr,flow=pcall(can_start,wait_for_resume==true)
    if not ok then self.status="召唤演出未启动："..tostring(owner);return false,self.status end
    local request={owner=owner,transform=tr,flow=flow,stage=wait_for_resume and "waiting_resume" or "queued",elapsed=0,
        height=settings.summon_height,forward=settings.summon_forward,delay=settings.summon_delay}
    self.current=request
    if wait_for_resume then
        request.wait_deadline=os.time()+30
        self.status="召唤道具：请求已接收，请关闭物品菜单后播放演出"
    else
        self.status="召唤演出：等待开始"
        begin_request(request)
    end
    return true,"召唤演出请求已接受"
end
function summon:tick()
    local request=self.current
    if not request or (request.stage~="playing" and request.stage~="waiting_resume") then return end
    if not alive or state.generation~=generation then self:cancel("脚本已重载");return end
    local c=core()
    if not c or c.properties.player~=request.owner or not request.owner:get_Valid()
        or c.properties.transform~=request.transform or active or state.recovery then self:cancel("玩家或控制状态已变化");return end
    if request.stage=="waiting_resume" then
        if os.time()>request.wait_deadline then self:cancel("等待关闭物品菜单超时");return end
        if menu.gameplay_paused() then return end
        request.stage="queued"
        begin_request(request)
        return
    end
    local t=now()
    if menu.gameplay_paused() then request.last=t;return end
    local ok,err=pcall(function()
        local main=sdk.get_managed_singleton("app.MainFlowManager")
        assert(main and main:call("get_IsInGamePhase()"),"已离开游戏阶段")
        assert(flow_instance()==request.flow,"演出控制器已变化")
        local busy=request.flow:call("get_IsActive()")
        local routine=request.flow:get_field("Routine")
        if not busy and routine==0 then
            if request.fired then self.current=nil;self.status="召唤演出已结束，可手动开始驾驶";return end
            local director=request.flow:get_field("<Director>k__BackingField")
            local count=director and director:get_field("ShotCameraRequestCount")
            local index=director and director:get_field("ShotCameraIndex")
            if not request.native_ended then
                assert(director and director:get_field("Routine")==0 and finite(count) and count>0
                    and finite(index) and index>=count,"演出未正常完成，召唤已取消")
                request.native_ended=true
                self.status=string.format("演出已结束，等待开始后 %.2f 秒生成狮鹫",request.delay)
            end
        else
            assert(not request.native_ended and routine==7,"已切换至其他飞石流程")
        end
        local dt=t-request.last;request.last=t
        assert(finite(dt) and dt>=0 and dt<=2,"演出计时中断")
        request.elapsed=request.elapsed+dt
        if not request.fired and request.elapsed>=request.delay then
            assert(#state.spawns==0 and not queued,"已有其他生成请求")
            -- via.Position is a value copy returned by the getter; only this copy is edited.
            local p=request.transform:call("get_UniversalPosition()")
            vector(p)
            local q=request.transform:call("get_Rotation()")
            assert(q and finite(q.x) and finite(q.y) and finite(q.z) and finite(q.w),"玩家朝向不可用")
            local fx,fz=2*(q.x*q.z+q.w*q.y),1-2*(q.x*q.x+q.y*q.y)
            local len=math.sqrt(fx*fx+fz*fz)
            assert(len>0.000001,"玩家水平朝向不可用")
            fx,fz=fx/len,fz/len
            p.x=p.x+fx*request.forward;p.y=p.y+request.height;p.z=p.z+fz*request.forward
            assert(spawn({session=request,owner=request.owner,position=p,facing={x=-fx,z=-fz}}),"生成请求被拒绝")
            request.fired=true
            self.status=string.format("%.2f 秒已提交生成请求，等待 NickCore 实例就绪",request.delay)
        end
    end)
    if not ok then self:cancel(err) end
end
function apply_spawn_facing(r,ch)
    if not r.summon_facing then return end
    assert(r.result and r.result.chara==ch and ch:call("get_GameObject()")==r.result.go,"召唤朝向实例不符")
    local tr=assert(ch:call("get_Transform()"),"狮鹫Transform未就绪")
    local context=assert(ch:get_field("<PosRotContext>k__BackingField"),"狮鹫位置上下文未就绪")
    local terrain=ch:get_field("<AdjustTerrain>k__BackingField")
    local controller=assert(terrain and terrain.MainCharacterController,"狮鹫碰撞体未就绪")
    local p=tr:call("get_UniversalPosition()")
    local target=r.owner:call("get_Transform()"):call("get_UniversalPosition()")
    vector(p);vector(target)
    local dx,dz=target.x-p.x,target.z-p.z
    if dx*dx+dz*dz<0.000001 then dx,dz=r.summon_facing.x,r.summon_facing.z end
    local yaw=math.atan(dx,dz)
    local rotation=Quaternion.new(math.cos(yaw/2),0,math.sin(yaw/2),0)
    tr:call("set_Rotation(via.Quaternion)",rotation)
    context:call("setPosRot(via.Position, via.Quaternion)",p,rotation)
    controller:call("warp()")
    r.summon_facing=nil
end
end
