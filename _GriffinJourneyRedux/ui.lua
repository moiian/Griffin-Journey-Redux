-- Griffin Journey Redux: ui
return function(ctx)
local _ENV=ctx
re.on_draw_ui(function()
    if not imgui.tree_node("Griffin Journey Redux###GriffinJourneyRedux") then return end
    local aligned=type(imgui.indent)=="function" and type(imgui.unindent)=="function"
    if aligned then imgui.indent(0) end
    imgui.text("v"..VERSION)
    menu.editor()
    if aligned then imgui.unindent(0) end
    if imgui.tree_node("镜头设置") then
        menu.slider("distance","相机距离",0,80)
        menu.slider("fov","FOV",40,120)
        if imgui.tree_node("镜头跟随") then
            menu.edit_toggle("head_camera","切换到狮鹫视角")
            menu.edit_toggle("camera_auto_yaw","转向时镜头跟随###BetaCameraYaw")
            menu.slider("hover_camera_yaw_speed","1档镜头跟随速度（度／秒）",0,360)
            menu.slider("camera_yaw_speed","2档镜头跟随速度（度／秒）",15,360)
            menu.slider("camera_manual_threshold","右摇杆接管阈值",0.25,0.95)
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
    if imgui.tree_node("按键设置") then menu.bindings();imgui.tree_pop() end
    if imgui.tree_node("座位预设") then
        menu.presets()
        imgui.tree_pop()
    end
    if imgui.tree_node("详细配置") then
    if imgui.tree_node("飞行设置") then
        if imgui.tree_node("移动速度") then
        menu.slider("hover_forward_speed","悬停前进速度（米／秒）",0,12)
        menu.slider("hover_backward_speed","悬停后退速度（米／秒）",0,12)
        menu.slider("hover_climb_speed","悬停垂直爬升速度（米／秒）",0,12)
        menu.slider("hover_descend_speed","悬停垂直下移速度（米／秒）",0,12)
        imgui.tree_pop()
        end
        if imgui.tree_node("惯性") then
        menu.slider("sprint_stop_tau","冲刺转悬停缓冲时间（秒）",0,3)
        menu.slider("hover_up_accel_tau","悬停上移启动缓冲时间（秒）",0,3)
        menu.slider("hover_up_decel_tau","悬停上移停止缓冲时间（秒）",0,3)
        menu.slider("hover_down_accel_tau","悬停下移启动缓冲时间（秒）",0,3)
        menu.slider("hover_down_decel_tau","悬停下移停止缓冲时间（秒）",0,3)
        menu.slider("hover_accel_tau","悬停水平加速缓冲时间（秒）",0,3)
        menu.slider("hover_decel_tau","悬停水平松杆减速缓冲时间（秒）",0,3)
        menu.slider("hover_reverse_tau","悬停水平反向刹车缓冲时间（秒）",0,3)
        imgui.tree_pop()
        end
        if imgui.tree_node("转向与导航") then
        menu.slider("hover_turn_speed","悬停左摇杆转向速度（度／秒）",0,180)
        menu.slider("steering_yaw","左右转向灵敏度（最大角度）",1,85)
        menu.slider("steering_pitch","摇杆上下微调（最大角度）",1,80)
        menu.slider("bumper_pitch","冲刺升降角度（最高59°）",1,59)
        menu.slider("navigation_radius","导航范围（米）",2,130)
        menu.slider("navigation_height","导航中心高度（米）",-menu.draft.navigation_radius*0.9,menu.draft.navigation_radius*0.9)
        imgui.tree_pop()
        end
        hover_collision:draw()
        if imgui.tree_node("稳定性") then
            menu.edit_toggle("anti_jitter","玩家与乘客防抖")
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
    hud:draw()
    if imgui.tree_node("测试按钮") then
        if beta_button("一键生成狮鹫###BetaSpawn") then spawn() end
        if beta_button("狮鹫召唤演出###BetaSummonPerformance") then bridge.summon_performance() end
        if imgui.tree_node("召唤演出设置") then
            menu.slider("summon_delay","生成时间（演出开始后秒数）",0,30)
            menu.slider("summon_height","生成上方距离（米）",0,50)
            menu.slider("summon_forward","生成前方距离（米）",0,50)
            imgui.tree_pop()
        end
        imgui.text(summon.status)
        if shop_item then imgui.text(shop_item.status) end
        if consumables then imgui.text(consumables.status) end
        if beta_button("开始驾驶###BetaStart") then start_driver() end
        menu.slider("boarding_distance","热键开始驾驶距离（严格小于／米）",1,50)
        if beta_button("结束驾驶###BetaStop") then menu.stop() end
        if beta_button("删除狮鹫###BetaDelete") then menu.delete() end
        imgui.text(status)
        if active then imgui.text(active.gear==2 and "当前状态：冲刺" or "当前状态：悬停") end
        imgui.tree_pop()
    end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
end
