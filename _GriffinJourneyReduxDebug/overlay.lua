-- Opt-in sprint +6m/s displacement experiment, never an absolute position lock.
return function(ctx)
local _ENV=ctx
local test={status="冲刺位移叠加：未运行",extra=6,pending=state.sprint_overlay_repair}
local duration={A=2,B=6,R=2}
local settling={A=0.4,B=0.6,R=0.6}
local function mean(s) return s and s.time>0 and s.sum/s.time or nil end
local function length(v) return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z) end
local function distance(a,b) return length({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}) end
local function binding(r)
 local ch=r.character
 assert(ch:get_Valid() and r.go:get_Valid() and r.driver.spawn.result.chara==ch
  and ch:call("get_GameObject()")==r.go and ch:call("get_Transform()")==r.transform,"Overlay Griffin changed")
 assert(ch:get_field("<PosRotContext>k__BackingField")==r.context
  and ch:get_field("<AdjustTerrain>k__BackingField")==r.terrain
  and r.terrain.MainCharacterController==r.controller,"Overlay physics changed")
end
local function repair(r)
 if not r.dirty then return end
 if not r.character:get_Valid() or not r.go:get_Valid() then r.dirty=false;return end
 binding(r)
 -- Repair current coordinates after a partial setter failure; never undo movement.
 local p=r.transform:call("get_UniversalPosition()")
 r.context:call("setPosRot(via.Position, via.Quaternion)",p,r.transform:call("get_Rotation()"))
 r.controller:call("warp()")
 r.dirty=false
end
function test:repair()
 if not self.pending then return true end
 local ok,err=pcall(repair,self.pending)
 if ok then self.pending=nil;state.sprint_overlay_repair=nil;return true end
 self.status="叠加位置同步恢复待重试："..tostring(err);return false
end
function test:stop(reason)
 local r=self.run
 self.run=nil
 if r and r.dirty then self.pending=r;state.sprint_overlay_repair=r end
 if r then
  self.result=r;r.baseline=mean(r.stats.A);r.boosted=mean(r.stats.B);r.recovered=mean(r.stats.R)
  self.status="冲刺位移叠加："..(reason or "已停止").."；保留当前位置" end
 self:repair()
end
local function valid(r)
 return alive and state.generation==generation and active==r.driver and r.driver.gear==2
  and r.driver.controls_active and not r.driver.external_control and not menu.gameplay_paused()
  and owned_player(r.driver,true) and r.driver.spawn.result.chara==r.character
end
local function native_sprint(r)
 assert(r.character:call("get_IsFlight()") and not r.character:call("get_IsGround()"),"Not airborne")
 local manager=assert(r.character:call("get_ActionManager()"))
 assert(manager:call("get_GameObject()")==r.go,"ActionManager changed")
 local info=manager:get_field("CurrentAction");local name=info and info:get_field("Name")
 assert(type(name)=="string" and name:sub(1,15)=="Ch253WrapAround","Native sprint changed")
end
function test:start()
 if self.run or not self:repair() then return end
 local ok,err=pcall(function()
  local d=active;assert(d and d.gear==2 and d.sprint_speed and d.sprint_speed.ready,"请先稳定2档冲刺约2秒")
  assert(not debug_tools.speed_test.run and not debug_tools.speed_test.pending and not debug_tools.timing.run,"请先结束其他检查")
  local ch=validate_spawn(d.spawn);local tr=assert(ch:call("get_Transform()"))
  local terrain=assert(ch:get_field("<AdjustTerrain>k__BackingField"))
  local r={driver=d,character=ch,go=d.spawn.result.go,transform=tr,terrain=terrain,
   context=assert(ch:get_field("<PosRotContext>k__BackingField")),controller=assert(terrain.MainCharacterController),
   phase="A",started=now(),last_time=now(),position=vector(tr:call("get_UniversalPosition()")),
   stats={},writes=0,readback=0,controller_error=0,added=0,reverse=0,checked=0}
  assert(valid(r),"Driver unavailable");binding(r);native_sprint(r)
  self.result=nil;self.run=r;self.status="叠加对照 A：原速2秒 → +6米／秒6秒 → 恢复2秒；保持平飞。"
 end)
 if not ok then self.status="叠加对照未启动："..tostring(err) end
end
function test:finish(r)
 self.run=nil
 local a,b,c=mean(r.stats.A),mean(r.stats.B),mean(r.stats.R)
 self.result=r;r.baseline=a;r.boosted=b;r.recovered=c
 if not a or not b or not c then self.status="叠加对照：样本不足；额外位移已结束";return end
 r.gain=b-a
 -- Coordinate reads alone cannot establish visual flight quality.
 r.observed=r.writes>0 and r.gain>=self.extra*0.65 and r.gain<=self.extra*1.35 and math.abs(c-a)<=2 and r.readback<0.05 and r.controller_error<0.05
 self.status=r.observed and "已观察到额外速度及恢复；是否回拉／抖动仍需画面确认" or "未证实稳定叠加；请结合速度与回拉画面判断"
end
function test:tick()
 if not self:repair() then return end
 local r=self.run;if not r then return end
 local ok,current=pcall(valid,r)
 if not ok or not current then self:stop("驾驶／档位／暂停变化，已取消") end
end
function test:after_behavior()
 local r=self.run;if not r then return end
 local ok,err=pcall(function()
  if not valid(r) then self:stop("驾驶／档位／暂停变化，已取消");return end
  binding(r);native_sprint(r)
  local t=now();local dt=t-r.last_time
  if dt<=0 then return end -- No duplicate application when the game clock did not advance.
  if dt>0.1 then self:stop("帧间隔过大，已取消");return end
  local p=r.transform:call("get_UniversalPosition()");local before=vector(p)
  local delta={x=before.x-r.position.x,y=before.y-r.position.y,z=before.z-r.position.z}
  local speed=length(delta)/dt
  assert(finite(speed) and speed<200,"Position jump")
  local elapsed=t-r.started
  if elapsed>=settling[r.phase] then
   local s=r.stats[r.phase] or {sum=0,time=0};r.stats[r.phase]=s
   s.sum=s.sum+speed*dt;s.time=s.time+dt
  end
  if r.last_after then
   local step={x=before.x-r.last_after.x,y=before.y-r.last_after.y,z=before.z-r.last_after.z}
   r.checked=r.checked+1
   if step.x*r.direction.x+step.y*r.direction.y+step.z*r.direction.z < -0.01 then r.reverse=r.reverse+1 end
   r.last_step=length(step)/dt -- Motion between the previous write and this frame, not a rollback proof.
  end
  r.position=before;r.last_time=t
  if elapsed>=duration[r.phase] then
   if r.phase=="A" then r.phase="B";r.started=t;self.status="叠加对照 B：当前原生位置上逐帧添加 +6米／秒，不锁定位置。"
   elseif r.phase=="B" then r.phase="R";r.started=t;r.last_after=nil;self.status="叠加对照：停止额外位移，采样原速恢复。"
   else self:finish(r);return end
  end
  if r.phase~="B" then return end
  local sample=r.driver.sprint_sample;local velocity=sample and sample.velocity
  assert(velocity and t-sample.time<=0.15,"World direction sample stale")
  local n=length(velocity);assert(n>1 and finite(n),"Flight direction unavailable")
  -- Normalize only: measured total speed must never feed back into the fixed +6 magnitude.
  local direction={x=velocity.x/n,y=velocity.y/n,z=velocity.z/n}
  local step=self.extra*dt
  local target={x=before.x+direction.x*step,y=before.y+direction.y*step,z=before.z+direction.z*step}
  p.x=target.x;p.y=target.y;p.z=target.z
  local q=r.transform:call("get_Rotation()")
  r.dirty=true
  r.transform:call("set_UniversalPosition(via.Position)",p)
  r.context:call("setPosRot(via.Position, via.Quaternion)",p,q)
  r.controller:call("warp()")
  r.dirty=false;r.writes=r.writes+1;r.added=r.added+step
  local after=vector(r.transform:call("get_UniversalPosition()"))
  r.readback=math.max(r.readback,distance(after,target))
  r.controller_error=math.max(r.controller_error,distance(vector(r.transform:call("get_Position()")),vector(r.controller:call("get_Position()"))))
  r.last_after=after;r.direction=direction
 end)
 if not ok then self:stop("叠加异常："..tostring(err)) end
end
function test:draw()
 if self.run then
  if beta_button("停止冲刺叠加对照###BetaOverlayStop") then self:stop("手动停止") end
 elseif beta_button("冲刺位移叠加对照（+6米／秒，自动结束）###BetaOverlayStart") then self:start() end
 imgui.text(self.status)
 local r=self.result
 if r then
  for _,v in ipairs({{"原速 A",r.baseline},{"叠加 +6",r.boosted},{"恢复原速",r.recovered}}) do
   imgui.text(v[1].."："..(v[2] and string.format("%.2f 米／秒",v[2]) or "样本不足"))
  end
  imgui.text(string.format("叠加次数 %d；累计代码位移 %.2fm",r.writes,r.added))
  imgui.text(string.format("即时Transform误差 %.4fm；碰撞体差 %.4fm",r.readback,r.controller_error))
  imgui.text(string.format("相邻帧反向位移 %d／%d（仅线索）",r.reverse,r.checked))
 end
end
return test
end
