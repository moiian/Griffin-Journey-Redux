-- Griffin Journey Redux: ui
return function(ctx)
local _ENV=ctx
re.on_draw_ui(function()
    if not imgui.tree_node("Griffin Journey Redux###GriffinJourneyRedux") then return end
    imgui.text("v"..VERSION)
    if menu.save_error then imgui.text(menu.save_error) end
    if imgui.tree_node("一般设置") then
        if beta_button("一键生成狮鹫###BetaSpawn") then spawn() end
        if beta_button("召唤演出测试###BetaSummonPerformance") then summon:request() end
        if imgui.tree_node("召唤演出设置") then
            menu.slider("summon_delay","生成时间（演出开始后秒数）",0,30)
            menu.slider("summon_height","生成上方距离（米）",0,50)
            menu.slider("summon_forward","生成前方距离（米）",0,50)
            imgui.text("以生成时玩家位置和水平朝向计算；生成后水平面朝玩家。")
            imgui.tree_pop()
        end
        imgui.text(summon.status)
        if beta_button("开始驾驶###BetaStart") then start_driver() end
        if beta_button("结束驾驶###BetaStop") then menu.stop() end
        if beta_button("删除狮鹫###BetaDelete") then menu.delete() end
        if beta_button("让狮鹫听话###BetaSelectPlayerTarget") then menu.listen() end
        imgui.text(status)
        if active then imgui.text("当前档位："..active.gear.."档") end
        imgui.tree_pop()
    end
    if imgui.tree_node("飞行设置") then
        hover_collision:draw()
        local ai_changed,ai_value=menu.toggle("方向6：禁用狮鹫决策组件（实验）",ai_takeover.enabled)
        if ai_changed then ai_takeover:set_enabled(ai_value) end
        if ai_takeover.enabled or ai_takeover.held or ai_takeover.errors>0 then imgui.text(ai_takeover.status) end
        local changed,value=menu.toggle("玩家与乘客防抖",settings.anti_jitter)
        if changed then settings.anti_jitter=value;anti_jitter.fall_stop:set_enabled(value);controls.save() end
        if settings.anti_jitter and not anti_jitter.fall_stop.enabled then imgui.text(anti_jitter.fall_stop.status) end
        changed,value=menu.toggle("狮鹫防抖",settings.griffin_anti_jitter)
        if changed then settings.griffin_anti_jitter=value;anti_jitter.griffin_stop:set_enabled(value);controls.save() end
        if settings.griffin_anti_jitter and not anti_jitter.griffin_stop.enabled then imgui.text(anti_jitter.griffin_stop.status) end
        imgui.text("1档：A 上移／Y 下移；RS 两档原生降落；左杆前后移动、左右转向；LT 惯性悬停")
        imgui.text("RT 冲刺；RB 俯冲／LB 爬升（1档按下即进入2档）；A 仅在地面触发起飞")
        imgui.text("起飞至少播放1.89秒后才切悬停／冲刺；1档玩家实体跟随预设[1]，2档启用球面导航。")
        menu.slider("sprint_stop_tau","2档切悬停惯性时间常数（秒）",0,3)
        if active and active.sprint_speed then
            local speed=active.sprint_speed
            imgui.text(string.format("2档实测总速度：%.2f 米／秒%s",speed.total,speed.ready and "" or "（采样中）"))
            imgui.text(string.format("水平：%.2f 米／秒",speed.horizontal))
            imgui.text(string.format("竖直：%+.2f 米／秒",speed.vertical))
        end
        if active and active.sprint_status then imgui.text(active.sprint_status) end
        if active and active.sprint_handoff_speed then imgui.text(string.format("最近LT继承速度：%.2f 米／秒",active.sprint_handoff_speed)) end
        menu.slider("hover_forward_speed","1档前进速度（米／秒）",0,12)
        menu.slider("hover_backward_speed","1档后退速度（米／秒）",0,12)
        menu.slider("hover_climb_speed","1档垂直爬升速度（米／秒）",0,12)
        menu.slider("hover_descend_speed","1档垂直下移速度（米／秒）",0,12)
        menu.slider("hover_up_accel_tau","1档上移启动时间常数（秒）",0,3)
        menu.slider("hover_up_decel_tau","1档上移停止时间常数（秒）",0,3)
        menu.slider("hover_down_accel_tau","1档下移启动时间常数（秒）",0,3)
        menu.slider("hover_down_decel_tau","1档下移停止时间常数（秒）",0,3)
        menu.slider("hover_accel_tau","1档水平加速时间常数（秒）",0,3)
        menu.slider("hover_decel_tau","1档水平松杆减速时间常数（秒）",0,3)
        menu.slider("hover_reverse_tau","1档水平反向刹车时间常数（秒）",0,3)
        imgui.text("时间常数越大，惯性越明显；0为立即响应。上移、下移的启动与停止分别调节。")
        imgui.text("反向输入先刹到零速再加速；LT保留惯性减速，松杆不重复发送悬停。")
        menu.slider("hover_turn_speed","1档左摇杆转向速度（度／秒）",0,180)
        menu.slider("steering_yaw","左右转向灵敏度（最大角度）",1,85)
        menu.slider("steering_pitch","摇杆上下微调（最大角度）",1,80)
        menu.slider("bumper_pitch","RB／LB 升降角度（最高59°）",1,59)
        menu.slider("navigation_radius","头部导航半径（米）",2,130)
        menu.slider("navigation_height","球面回中高度（米）",-settings.navigation_radius*0.9,settings.navigation_radius*0.9)
        imgui.tree_pop()
    end
    if imgui.tree_node("镜头设置") then
        local changed,value=menu.toggle("镜头跟随狮鹫头部",settings.head_camera)
        if changed then settings.head_camera=value;change_camera_mode(value and "griffin" or "original");controls.save() end
        changed,value=menu.toggle("2档转向时跟随镜头###BetaCameraYaw",settings.camera_auto_yaw)
        if changed then
            settings.camera_auto_yaw=value;yaw_state=nil
            if value and install_yaw_hook() then settings.head_camera=true;change_camera_mode("griffin") end
            controls.save()
        end
        imgui.text("1档仅转向时跟随；两档共用右摇杆接管阈值与恢复延迟")
        menu.slider("hover_camera_yaw_speed","1档镜头跟随速度（度／秒）",0,360)
        if active and active.hover_camera_error then imgui.text("1档镜头跟随暂不可用") end
        menu.slider("camera_yaw_speed","2档镜头跟随速度（度／秒）",15,360)
        menu.slider("camera_manual_threshold","右摇杆接管阈值",0.25,0.95)
        imgui.tree_pop()
    end
    if imgui.tree_node("座位预设") then
        menu.presets()
        imgui.tree_pop()
    end
    if imgui.tree_node("按键设置") then menu.bindings();imgui.tree_pop() end
    if debug_tools then debug_tools:draw() end
    imgui.tree_pop()
end)
end
