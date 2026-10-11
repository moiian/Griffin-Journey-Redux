# Beta 0.1.29：2档、菜单与释放记录

1. 结束旧驾驶后Reset scripts，确认0.1.29。一键生成并开始驾驶，RT冲刺后LT进入2档。
2. 2档回中应原地悬停；前推悬停前移、后推悬停后移；RB应播放HoverBackwardTargetHeight，LB仍悬停转降落。左右不变。确认1档RB仍原地悬停、3档操控不变。
3. 镜头栏只有“镜头跟随狮鹫头部”，关闭即恢复游戏跟随；DEBUG不再显示“恢复原镜头”、旧玩家距离/高度与球面关闭选项。FOV和相机距离仍在座位预设的玩家参数中。检查已有座位、导航半径/回中高度、灵敏度、热键精调仍保留。
4. 随从问题继续按之前流程逐项测试额外拦截，开关现名为“跳过随从丢失检查”“阻止乘客被生成器销毁”。本版没有添加名单等待/延迟释放；发生消失或脱绑后告诉我当时的开关状态即可，不需要截图或手动录制。

自动日志新增passenger_release_context，记录释放原因（invalid_instance/seat_disabled/absent_from_engine_roster）、当时有效性、HP、接口归属与生成器状态；rider_protection增加GenerateInfo.applyDestroy和Character.onDestroyCharacterByGenerator观察。两处销毁入口均只读，不跳过。后续依靠实际命中与实例状态分辨引擎刷新路径，当前不能认定问题已修复。

两个额外开关仍默认关闭；探针始终自动记录。脚本正常保存时剔除废弃顶层设置键，有效座位与精调设置保留。原版和设置备份Beta/beta_0128。离线回归通过，原生实测待确认。
