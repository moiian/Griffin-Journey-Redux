-- Griffin Journey Redux: ui
return function(ctx)
local _ENV=ctx
re.on_draw_ui(function()
    if not imgui.tree_node("Griffin Journey Redux###GriffinJourneyRedux") then return end
    imgui.text("v"..VERSION)
    if menu.save_error then imgui.text(menu.save_error) end
    if imgui.tree_node("一般设置") then
        if beta_button("一键生成狮鹫###BetaSpawn") then spawn() end
        if beta_button("开始驾驶###BetaStart") then start_driver() end
        if beta_button("结束驾驶###BetaStop") then menu.stop() end
        if beta_button("删除狮鹫###BetaDelete") then menu.delete() end
        if beta_button("让狮鹫听话###BetaSelectPlayerTarget") then menu.listen() end
        imgui.text(status)
        if active then imgui.text("当前档位："..active.gear.."档") end
        imgui.tree_pop()
    end
    if imgui.tree_node("飞行设置") then
        local ai_changed,ai_value=menu.toggle("方向6：禁用狮鹫决策组件（实验）",ai_takeover.enabled)
        if ai_changed then ai_takeover:set_enabled(ai_value) end
        if ai_takeover.enabled or ai_takeover.held or ai_takeover.errors>0 then imgui.text(ai_takeover.status) end
        local changed,value=menu.toggle("玩家与乘客防抖",settings.anti_jitter)
        if changed then settings.anti_jitter=value;anti_jitter.fall_stop:set_enabled(value);controls.save() end
        if settings.anti_jitter and not anti_jitter.fall_stop.enabled then imgui.text(anti_jitter.fall_stop.status) end
        changed,value=menu.toggle("狮鹫防抖",settings.griffin_anti_jitter)
        if changed then settings.griffin_anti_jitter=value;anti_jitter.griffin_stop:set_enabled(value);controls.save() end
        if settings.griffin_anti_jitter and not anti_jitter.griffin_stop.enabled then imgui.text(anti_jitter.griffin_stop.status) end
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
        changed,value=menu.toggle("3档转向时跟随镜头###BetaCameraYaw",settings.camera_auto_yaw)
        if changed then
            settings.camera_auto_yaw=value;yaw_state=nil
            if value and install_yaw_hook() then settings.head_camera=true;change_camera_mode("griffin") end
            controls.save()
        end
        menu.slider("camera_yaw_speed","镜头跟随速度（度／秒）",15,360)
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
