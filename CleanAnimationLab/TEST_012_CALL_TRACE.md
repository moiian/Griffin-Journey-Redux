# CleanAnimationLab 0.1.2：原生方法前后只读定位

2026-10-13。首次隔离仍存在原生位移，本版按精确实例增加只读调用边界与实际动画资源记录，定位未隔离路径；不宣称修复。

## 本版变更

新增默认关闭call_trace.lua，只观察从精确返回角色取得的动作、地形、姿态调整和上下文回滚对象，不跳过或修改任何被测调用。方法前后读Transform Universal／场景、上下文Universal、碰撞体场景、动作、FSM／RootMotion和实际基础层编号／帧。字段独立失败、数字快照；线程Hook存储保存本次调用数据，不采用共享的单个pending对象。前后检查同实例、同模块、同版本及当前记录／暂停状态。

菜单新增独立方法跟踪开关；切换该开关不递增隔离版本、不重播动画。仍需状态记录与绑定开启才工作。每入口20Hz、最多1000采样对，共五入口；变化对全存、稳定每秒存一对。保存仍由普通帧／显式操作触发，Hook只更新有界内存数据。计数区分hits、paired、stored、changed、dropped和errors。

接口依据：本地dump_stage318_motion.json核对ActionManager.update()返回Void及角色PosRotAdjuster／PosRotContextRollbacker引用；dump_stage322_pose_pipeline.json核对AdjustTerrain.update()／updateSubPosition()、CharacterPosRotAdjuster.writeToTransform()返回Void，Rollbacker.updateAndRollbackIfNeeded()返回Boolean，并核对Character／Chara／PosRotContext归属字段。dump_stage318_layers.json核对TreeLayer的Enabled、MotionBankID、MotionID、Frame读方法。运行时逐个查完整签名；缺接口／模块归属失败只禁用该入口并记录错误。没有对转储作文件校验和。

## 离线检查

Lua 5.4六文件语法通过。既有状态探针生命周期回归通过：默认关闭、原生／隔离／落地连续记录、前后快照、数值拷贝、字段错误、飞控归属拒绝、暂停／旧队列、关闭／容量／Reset、恢复失败重试。

新增模拟通过：

- 默认关闭不安装方法Hook；仅打开跟踪不重播动画或修改原生状态。
- 只读基础层实际ID与帧；帧读取失败保留其他读数。
- 精确目标前后捕获真实坐标差、动作与实际资源变化，历史不引用可变原生向量。
- 无关对象零原生读取，正例与错误归属反例；同角色模块替换／当前Beta实例变化均拒读。
- 嵌套入口独立配对并记录前后顺序；原生返回值包括Boolean false保持不变。
- 每入口限频、稳定心跳保存、容量丢弃；容量到达时隔离动画和原方法继续。
- 暂停、记录关闭、版本变化、关闭后未完成调用、暂停到队列执行、部分模块不可用、Reset均安全停止或丢弃。
- Hook内无磁盘写入；独立只读场景无FSM／根模式／动画写入。

这些是离线模拟，不验证引擎虚调用／内联是否经过入口、原生线程时序、性能或实际画面。首次位移尚未修复。实机按README做一轮，总体约30秒；不要求随机落地成功，没有落地也保存。
