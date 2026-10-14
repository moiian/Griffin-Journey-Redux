-- Optional developer add-on. Extends the loaded release; never loads another driver.
return function(ctx)
local _ENV=ctx
local FallStop=require("_GriffinJourneyRedux.fall_stop")
require("_GriffinJourneyReduxDebug.fall_snapshot")(FallStop)
passengers.snapshot=function(value)
    if type(value)~="table" then return value end
    local out={};for key,item in pairs(value) do out[key]=passengers.snapshot(item) end;return out
end
passengers.fall_experiment={reset=false,ground=false}
passengers.griffin_fall={reset=false,status="狮鹫跌落实验：关闭"}
passengers.protection.lost_check=false;passengers.protection.destroy=false;passengers.protection.counts={}
anti_jitter.griffin_stop=require("_GriffinJourneyReduxDebug.griffin_fall")(FallStop,anti_jitter.env)
anchor_modes={{key="full",label="完整同步"},{key="rider",label="仅Hip头顶"}}
anti_jitter.env.diagnostics=function() return debug_tools and debug_tools:diagnostics() or {} end
anti_jitter.griffin_stop:set_enabled(false)
require("_GriffinJourneyReduxDebug.ai_takeover")(ctx)
require("_GriffinJourneyReduxDebug.anchor_mode")(ctx)
require("_GriffinJourneyReduxDebug.freeze")(ctx)
require("_GriffinJourneyReduxDebug.camera_probe")(ctx)
require("_GriffinJourneyReduxDebug.item_menu")(ctx)
require("_GriffinJourneyReduxDebug.collision_policy")(ctx)
require("_GriffinJourneyReduxDebug.tools")(ctx)
driver_extension={}
function driver_extension:tick(d)
    local ok,err=ai_takeover:tick(d)
    if not ok then stop_driver("附加组件恢复失败："..tostring(err)) end
    return ok,err
end
function driver_extension:release()
    anti_jitter.griffin_stop:release_driver()
    passengers.griffin_fall.actor=nil
    return ai_takeover:release()
end
event=function(name,detail,defer) debug_tools:event(name,detail,defer) end
flush=function() return debug_tools:flush() end
passengers.on_anchor=function(a) passengers.apply_fall_experiment(a) end
passengers.on_release=function(a,reason,valid) passengers.record_release_context(a,reason,valid) end
fall_hits,fall_blocked=0,0
passengers.on_protection=function(actor,kind,blocked,...)
    if kind=="fall" then fall_hits=fall_hits+1;if blocked then fall_blocked=fall_blocked+1 end end
    passengers.record_protection(actor,kind,blocked,...)
end
passengers.extra_protection=function(hook) require("_GriffinJourneyReduxDebug.extra_protection")(ctx,hook) end
local capture=passengers.capture_identity
passengers.capture_identity=function(a)
    capture(a)
    if debug_tools.enabled then a.brine=a.player:get_field("<BrineProcessor>k__BackingField") end
end
consumables.log_path="GriffinJourneyRedux_PizzaGrant.json"
item_integration.on_effect_check=function(...) if item_probe.enabled then item_probe:effect_check(...) end end
item_integration.on_common_check=function(...) if item_probe.enabled then item_probe:common_check(...) end end
consumables.on_grant_record=function(record)
    if not debug_tools.enabled or not record then return end
    local ok,result=pcall(json.dump_file,"GriffinJourneyRedux_PizzaGrant.json",record)
    if not ok or result==false then consumables.log_error=tostring(result) end
end
hover_collision.casts=0;hover_collision.contacts=0;hover_collision.blocks=0;hover_collision.cost=0
local diagnostic_sequence=0
hover_collision.on_path=function(m,current,delta,angle,result)
    if not collision_debug.enabled then return end
    local g=hover_collision
    g.actual=vector(current);g.target=vector(m.position);g.request={x=delta.x,y=delta.y,z=delta.z,yaw=angle};g.last_phase=m.write_phase
    g.probes=g.probes or {};g.probes[m.write_phase or "direct"]={time=now(),actual=g.actual,target=g.target,request=g.request,result=result}
end
hover_collision.on_query=function(point,reverse)
    if not collision_debug.enabled then return end
    hover_collision.last_center=point.center==true;hover_collision.last_ball=point.forward
    hover_collision.last_lateral=point.right;hover_collision.last_direction=reverse and "reverse" or "forward"
end
hover_collision.on_ball=function(point,distance,length,radius,direction,hit)
    if not collision_debug.enabled then return end
    local g=hover_collision
    if hit then g.blocks=g.blocks+1 end
    if point.center then g.center_probe={center=true,distance=distance,requested_step=length,radius=radius,direction=vector(direction),result=hit and "blocked" or "clear"} end
end
hover_collision.on_cast=function(start,finish,radius,count)
    if not collision_debug.enabled then return end
    diagnostic_sequence=diagnostic_sequence+1
    hover_collision.casts=diagnostic_sequence;hover_collision.contacts=hover_collision.contacts+count
    hover_collision.last_query={start=vector(start),finish=vector(finish),radius=radius,contacts=count,sequence=diagnostic_sequence}
end
hover_collision.on_event=function(...) if collision_debug.enabled then collision_debug:record(...) end end
hover_collision.on_observe=function(d,ch,tr,flying,ground,action)
    if not collision_debug.enabled then return end
    hover_collision.driver_state={position=vector(tr:call("get_UniversalPosition()")),gear=d.gear,mode=d.mode,action=action,
        flying=flying,ground=ground,controls=d.controls_active,external=d.external_control,hold=d.manual_hold,
        stick={x=input.hover_x or input.x,y=input.y},up=held(input.buttons,masks.hover_up),down=held(input.buttons,masks.hover_down)}
end
local collision_observers={}
for _,key in ipairs({"on_path","on_query","on_ball","on_cast","on_event","on_observe"}) do
    collision_observers[key]=hover_collision[key];hover_collision[key]=nil
end
local collision_recording=collision_debug.set_enabled
function collision_debug:set_enabled(value)
    if value then for key,fn in pairs(collision_observers) do hover_collision[key]=fn end end
    collision_recording(self,value)
    if not value then for key in pairs(collision_observers) do hover_collision[key]=nil end end
end
local tick=tick_driver
tick_driver=function()
    if debug_tools:recording() then debug_tools:capture("behavior_before_anchor") end
    tick()
    local d=active
    if d and debug_tools:recording() then
        d.trace={griffin=vector(d.rider_griffin_transform:call("get_Position()")),player=vector(d.transform:call("get_Position()")),
            action=d.native_action,gear=d.gear,mode=d.mode,anchor_mode=d.anchor_mode,anchor_plan=d.anchor_plan,
            stick={x=input.x,y=input.y},passenger_protection=passengers.protection.counts}
    end
    passengers.griffin_fall_tick()
    if d then anti_jitter.griffin_stop:after_anchor(d) end
    if debug_tools:recording() then debug_tools:capture("behavior_before_native") end
end
local speed_menu=require("_GriffinJourneyReduxDebug.speed_menu")(ctx)
local input_menu=require("_GriffinJourneyReduxDebug.input_menu")(ctx)
re.on_frame(function()
    if not alive then return end
    collision_debug:tick();item_probe:tick();debug_tools:tick()
    if debug_tools.enabled then passengers.probe_tick();debug_tools:sample() end
    if menu.gameplay_paused() then flush() end
    anti_jitter.griffin_stop:tick()
end)
re.on_application_entry("UpdateBehavior",function()
    if alive and debug_tools:recording() then debug_tools:capture("behavior_native_after") end
end)
re.on_pre_application_entry("UpdateJointExpression",function()
    if alive and debug_tools:recording() then debug_tools:capture("joint_before_restore") end
end)
re.on_application_entry("UpdateJointExpression",function()
    if alive and debug_tools:recording() then debug_tools:capture("joint_seated_after") end
end)
re.on_application_entry("PrepareRendering",function()
    if alive and debug_tools:recording() then read_camera_follow();debug_tools:capture("render_native_after") end
end)
re.on_script_reset(function()
    item_probe:set_enabled(false);collision_debug:flush(true);debug_tools:shutdown()
    anti_jitter.griffin_stop:set_enabled(false);ai_takeover.enabled=false
end)
re.on_draw_ui(function()
    if not alive or not imgui.tree_node("Griffin Journey Redux · Debug 附加组件") then return end
    imgui.text("连接正式版 v"..VERSION.."；所有实验默认关闭，设置不自动启用。")
    local changed,value=menu.toggle("方向6：禁用狮鹫决策组件（实验）",ai_takeover.enabled)
    if changed then ai_takeover:set_enabled(value) end
    changed,value=menu.toggle("狮鹫防抖（实验）",anti_jitter.griffin_stop.enabled)
    if changed then anti_jitter.griffin_stop:set_enabled(value) end
    changed,value=menu.toggle("受阻后拉回最后安全位置（对照）",hover_collision.return_to_safe==true)
    if changed then hover_collision:set_return_to_safe(value) end
    speed_menu();input_menu();item_integration:draw();collision_debug:draw();debug_tools:draw()
    imgui.tree_pop()
end)
end
