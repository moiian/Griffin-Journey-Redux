# Beta 0.1.28：扣血、随从重载与释放测试

1. 先结束旧驾驶，再Reset scripts，确认0.1.28。召唤并开始驾驶，带随从沿此前出问题的路线飞行。先保留默认设置，观察是否还掉血/死亡、随从是否消失重刷及掉帧。
2. 如果仍消失，在DEBUG仅开启“【探针验证】跳过落座随从丢失检查”，再次飞同类距离。若仍发生，再单独开启“【探针验证】拦截落座乘客生成器销毁”对照；测试第二项时先关闭第一项，以便分辨哪条路径有效。两个开关默认只观察，勾选才拦截，修改会记入日志。
3. 落到另一处地面后结束驾驶，确认玩家/随从留在当前所在地，FSM和镜头恢复，不返回起点。乘客仍按各自预设[1]的当前真实位置释放，Hip显示位置不作为传送点。

不需要截图或手动启动录制。GriffinFlightBeta_*.json会自动记录；告诉我掉血/刷新是否发生，以及当时开了哪个开关即可，我读取本机日志。运行时确认DEBUG没有“部分保护／探针不可用”；若有，告知文字即可。

主要日志：rider_health_changed为实际HP/死亡/盐水状态变化；rider_protection为分角色限频汇总；passenger_unloaded和passenger_bound为卸载及新实例接管；lost_check_guard_mode/destroy_guard_mode为实验开关；driver_stopped包含current_physical_position和玩家释放坐标。

这版默认新增玩家伤害保护、updateDamageHp拦截与pawnLost的InstanceInfo重载保护；两项上游实验拦截默认关。没有自动补血/复活，也没有逐帧跌落重置。离线回归不能代替原生游戏验证。
