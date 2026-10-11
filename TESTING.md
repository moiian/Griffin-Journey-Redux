# Beta 0.1.23：乘客保护、预设1调试和动作动画

脚本已完成离线编译与回归；随从消失／刷新是否改善、动作的实际画面仍需游戏验证。

1. 结束旧驾驶后 Reset scripts，确认版本0.1.23。召唤并开始驾驶，先不设置动画，带随从低空悬停约1分钟，再按原路线远距飞行。观察是否仍有随从消失后重新出现。
2. DEBUG中“落座乘客伤害免疫”和“阻止落座乘客自动传送／丢失”默认开启。原坠落请求拦截也保留。计数按player／pawns／companions及座位编号分开；无需逐次截图，发生异常时告诉我大概时间及座位编号即可，我读取专属JSON日志。
3. DEBUG勾选“显示预设[1]（仅手动调试）”。座位列表应出现[1]，可手动选中预览。实体偏移仍在DEBUG预设1编辑器修改；下一个预设／热键轮询始终跳过[1]。关闭显示时，如果正在预览[1]，自动回到上次正常座位。Reset后默认隐藏[1]。
4. 座位预设中，玩家与各随从／同行NPC座位都有“动作名称”和“播放动画”。先填牛车已有动作`SitOnChairActions`，点击播放，确认姿势能建立并继续固定跟随狮鹫。请求仅一次，下一行为帧重新冻结FSM，不循环重发。留空表示不自动请求动画；播放按钮留空也不改变动作。
5. 保存到正常座位预设。结束／再次开始驾驶，或切走再切回该预设，确认动画自动请求一次。动画只保存动作节点名，不包含Motion ID／Bank ID，也没有随机动画。
6. 关闭单个乘客座位、结束驾驶与Reset，确认原FSM／位置恢复，原本未启用的FSM保持原状；保护只作用于当前落座实例，离座立即解除。

## 与牛车MOD的核对结果

| 项目 | 当前牛车MOD | Beta 0.1.23 |
| --- | --- | --- |
| 乘客伤害免疫 | HitController的damageProc／updateDamage按落座对象过滤 | 已按当前接管乘客实例补齐；不扩展为玩家全局无敌 |
| 乘客FSM | 动画请求时短暂开启，下一帧冻结；离座恢复原状态 | 已沿用相同动作请求时序 |
| 跌落重置 | 落座／换坐姿时一次，司机另有一次搬移重置 | 首次固定／切换座位／播放动画／释放时一次，不逐帧重置 |
| 异常状态免疫 | reqStatusConditionApplyCore仅保护牛，状态编号1—14 | 未将牛的专用规则扩展到乘客 |
| 乘客自动传送／丢失 | 未在所检查的落座保护中发现专门Hook | 增加精确落座随从的PawnManager拦截与DEBUG对照开关 |

## 日志证据与范围

本轮读取0.1.22日志`GriffinFlightBeta_20261011T145846Z_5395772_1/2.json`：记录到多次`Passenger unloaded`、名单缩减后再绑定，能确认发生了卸载／重新出现，尚不能证明具体触发源。

本地转储确认PawnManager以下接口均为void，且使用Character实例参数：`safeWarp(app.Character, via.Position)`、`safeWarp(app.Character, via.Position, via.Quaternion)`、`pawnLost(app.Character, System.Boolean, System.Boolean)`、`setPawnLostTimer(app.Character)`。本版只拦截精确接管且已固定的随从，普通NPC、同行NPC、未携带及释放后的角色放行。不拦截整个队伍的生成／丢失流程，不用Character ID接管对象。

保留`requestFallDead()`拦截，新增`rider_protection`分角色计数与`passenger_unloaded`记录。Hook中只累加／暂存，文件输出在普通帧回调进行。若仍刷新，依据新计数和卸载时刻继续检查，不能将离线测试当作已经修复原生刷新机制。

阶段三、牛车MOD、LMD与NickCore未修改；原座位精调值保留。
