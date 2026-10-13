-- Bounded read-only native movement timing probe. No persistent settings or file output.
return function(ctx)
local _ENV=ctx
local probe={status="原生位移时序：未运行",installed={}}
local key="griffin_timing039"
local methods={
 {"update()","update",0},{"lateUpdate()","late",0},
 {"updatePosition()","position",0},{"updateFlightAttitudeBeforePosition()","attitudeBefore",0},
 {"updateFlightAttitude()","attitude",0},{"updateFlightHeight()","height",0},
 {"eventFlightUpdate(via.GameObject)","flightEvent",1},
 {"eventBeforeColliderAdjust(via.GameObject)","beforeCollider",1},
 {"eventAfterColliderAdjust(via.GameObject, via.motion.ExpressionUpdate)","afterCollider",2},
 {"getFlightForwordDistance()","forwardDistance",0,"System.Single"}}
local function storage()
 local ok,s=pcall(thread.get_hook_storage);return ok and type(s)=="table" and s or nil
end
local function magnitude(v) return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z) end
local function distance(a,b) return magnitude({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}) end
local function valid(r)
 return alive and active==r.driver and state.generation==generation and r.driver.gear==2
  and r.driver.controls_active and not r.driver.external_control and not menu.gameplay_paused()
  and owned_player(r.driver,true) and r.driver.spawn.result.chara==r.character
end
local function snapshot(r)
 return {p=vector(r.transform:call("get_UniversalPosition()")),v=vector(r.controller:get_field("FlightMoveVector"))}
end
local function boundary(r,s,label)
 local ok,id=pcall(thread.get_id);if not ok or id==nil then r.missing=r.missing+1;return end
 local previous=r.last[id]
 if previous then
  local d=distance(previous.p,s.p)
  if d>0.00001 then
   local lane=previous.label.." -> "..label
   local stat=r.boundaries[lane]
   if stat then stat.sum=stat.sum+d;stat.n=stat.n+1
   elseif r.boundary_count<48 then r.boundary_count=r.boundary_count+1;r.boundaries[lane]={sum=d,n=1} end
  end
 end
 r.last[id]={p=s.p,label=label}
 if #r.order<32 then r.order[#r.order+1]=label end
end
function probe:stop(reason)
 if not self.run then return end
 self.run=nil;self.status="原生位移时序："..(reason or "已停止").."（只读）"
end
function probe:install()
 for _,spec in ipairs(methods) do
  local name,label,n,ret=spec[1],spec[2],spec[3],spec[4] or "System.Void"
  if not self.installed[name] then
   local ok,err=pcall(function()
    local td=assert(sdk.find_type_definition("app.FlightControl"))
    local m=assert(td:get_method(name),"Method unavailable: "..name)
    assert(not m:is_static() and m:get_num_params()==n and m:get_return_type():get_full_name()==ret,"Signature changed: "..name)
    sdk.hook(m,function(args)
     local r=self.run;if not r or not alive then return end
     r.all[label]=(r.all[label] or 0)+1
     local s=storage();if not s then r.missing=r.missing+1;return end
     local node={run=r};s[key]=node
     local success,error_text=pcall(function()
      local fc=sdk.to_managed_object(args[2]);if fc~=r.controller or not valid(r) then return end
      assert(fc:call("get_CachedCharacter()")==r.character,"Controller changed")
      local before=snapshot(r);node.before=before
      boundary(r,before,label.."<")
      local stat=r.stats[label] or {n=0,delta=0,vin=0,vout=0,old=0,old_n=0,returned=0,return_n=0};r.stats[label]=stat
      local old=fc:get_field("OldFlySpeedXZ")
      if finite(old) then stat.old=stat.old+old;stat.old_n=stat.old_n+1 end
     end)
     if not success then node.before=nil;r.error=tostring(error_text) end
    end,function(value)
     local r=self.run;if not r or not alive then return value end
     local s=storage();local node=s and s[key]
     if not node or node.run~=r then r.missing=r.missing+1;return value end
     if not node.before then return value end
     local ok,err=pcall(function()
      if not valid(r) then return end
      local after=snapshot(r);boundary(r,after,label..">")
      local stat=r.stats[label];stat.n=stat.n+1
      stat.delta=stat.delta+distance(node.before.p,after.p)
      stat.vin=stat.vin+magnitude(node.before.v);stat.vout=stat.vout+magnitude(after.v)
      if ret=="System.Single" then
       local f=sdk.to_float(value);if finite(f) then stat.returned=stat.returned+f;stat.return_n=stat.return_n+1 end
      end
     end)
     if not ok then r.error=tostring(err) end
     return value
    end)
   end)
   if ok then self.installed[name]=true else self.install_errors[name]=tostring(err) end
  end
 end
end
function probe:start()
 if self.run then return end
 local d=active
 local ok,err=pcall(function()
  assert(d and d.gear==2 and d.sprint_speed and d.sprint_speed.ready,"请先稳定2档平飞约2秒")
  assert(not debug_tools or not debug_tools.speed_test.pending,"请先完成旧测试向量恢复")
  local ch=validate_spawn(d.spawn);local fc=assert(ch:call("get_FlightCtrl()"))
  assert(fc:call("get_CachedCharacter()")==ch,"FlightControl owner changed")
  local tr=assert(ch:call("get_Transform()"))
  self.install_errors={};self:install();self.result=nil
  self.run={driver=d,character=ch,controller=fc,transform=tr,started=now(),all={},stats={},last={},boundaries={},boundary_count=0,order={},missing=0}
  self.status="原生位移时序：只读采样3秒；保持平飞，勿转向／升降。"
 end)
 if not ok then self.status="时序检查未启动："..tostring(err) end
end
function probe:tick()
 local r=self.run;if not r then return end
 local ok,err=pcall(function()
  if not valid(r) then self:stop("驾驶／档位／暂停变化，已取消");return end
  assert(validate_spawn(r.driver.spawn)==r.character and r.character:call("get_FlightCtrl()")==r.controller,"Native binding changed")
  local speed=r.driver.sprint_speed
  if not speed or not speed.ready or now()-speed.time>0.15 or math.abs(input.x)>0.15
   or held(input.buttons,masks.rb) or held(input.buttons,masks.lb)
   or math.abs(speed.vertical)>math.max(1,speed.horizontal*0.2) then self:stop("样本或操控变化，已取消");return end
  if now()-r.started>=3 then self.result=r;self.run=nil;self.status="原生位移时序：完成（只读，未修改速度）" end
 end)
 if not ok then self:stop("检查异常："..tostring(err)) end
end
function probe:draw()
 if self.run then
  if beta_button("停止时序检查###BetaTimingStop") then self:stop("手动停止") end
 elseif beta_button("原生位移时序检查（3秒，只读）###BetaTimingStart") then self:start() end
 imgui.text(self.status)
 local r=self.result
 if r then
  for _,spec in ipairs(methods) do
   local label=spec[2];local s=r.stats[label]
   if s and s.n>0 then
    imgui.text(string.format("%s：%d次，调用内位移 %.4fm",label,s.n,s.delta/s.n))
    imgui.text(string.format("  向量长度 %.4f -> %.4f；OldSpeed %.3f",s.vin/s.n,s.vout/s.n,s.old_n>0 and s.old/s.old_n or 0))
    if s.return_n>0 then imgui.text(string.format("  返回距离：%.4f",s.returned/s.return_n)) end
   else imgui.text(label.."：本狮鹫0次／所有实例"..(r.all[label] or 0)) end
  end
  imgui.text("位移发生的相邻阶段：")
  local lanes={};for label,s in pairs(r.boundaries) do lanes[#lanes+1]={label=label,s=s} end
  table.sort(lanes,function(a,b) return a.s.sum>b.s.sum end)
  for i=1,math.min(6,#lanes) do local v=lanes[i];imgui.text(string.format("%s：%.4fm／次",v.label,v.s.sum/v.s.n)) end
  for i=1,#r.order,4 do imgui.text(table.concat(r.order," ",i,math.min(i+3,#r.order))) end
  if r.missing>0 then imgui.text("回调上下文缺失："..r.missing) end
  if r.error then imgui.text("接口异常："..r.error) end
 end
 for name,err in pairs(self.install_errors or {}) do imgui.text("可选入口未安装："..name.." / "..err) end
end
return probe
end
