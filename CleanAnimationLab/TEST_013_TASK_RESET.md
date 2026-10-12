# CleanAnimationLab 0.1.3：接管前单次原生任务重置实验

首次隔离实际基础层保持5100仍移动，动作完成后重开稳定；只读跟踪尚未定位唯一写入者。因此用单一默认关闭变量检验“接管前已有任务未结束”的解释，不把随机落地或Wait状态当作通用解决条件。

新增task_reset.lua，需显式开启“接管前重置原生任务（实验，每轮一次）”及状态记录。每个新隔离轮次在保存原FSM／RootMotion后、冻结之前调用一次精确角色的resetActionAndAI(app.Character.ResetActionAndAIOption)。切动画与隔离中修改选项不重置；选项只影响下一次接管。默认关闭与原隔离路径相同。

参数由当前游戏il2cpp_dump.json核对：ResetActionAndAIOption继承System.Object，具有无参.ctor()；它是引用对象，不是枚举。构造后设置ActionName=Wait、IsResetAI=true、IsResetCatch=false、IsResetCaught=false，字段读回符合才调用；其他选项保留构造默认。使用sdk.create_instance和托管字符串，没有nil／数字参数回退。对象构造和字段接口核对[REFramework sdk](https://cursey.github.io/reframework-book/api/sdk.html)与[REManagedObject文档](https://cursey.github.io/reframework-book/api/types/REManagedObject.html)。

仅在NickCore行为队列运行；前后核对同实例、同Motion／FSM／FlightControl，拒绝暂停、旧队列、驾驶及原FSM已经关闭的状态。构造或调用失败退出隔离，按原值恢复，失败保留恢复状态，不自动反复重置。准备期飞控Hook放行，避免阻断原生重置；重置返回后才冻结FSM／根模式并播放实际资源。前后状态事件独立留存；“调用返回”不等于任务已取消或位移已修复。

停止恢复接管前FSM／RootMotion，不恢复已取消的任务；不写Transform、碰撞体或速度，不强制着地。原生重置自身可能引起状态／位置变化，需用快照与实测判断。重置后基础层重新读取，组件归属改变时拒绝继续；恢复时也不向已经更换的旧FSM写值。

Lua54七文件语法、既有状态记录／生命周期／方法跟踪回归与新增重置回归通过：默认零额外构造／调用、正确对象／构造／字段读回、精确归属正反例、先重置后冻结、准备期回调放行、每轮一次、切动画／切开关不重置、原root不同于重置结果时正确恢复、参数及原生调用失败不自动重试、原false FSM、未开启记录、暂停／旧队列、FSM替换拒绝写旧对象并保留恢复。全部为离线模拟；原生调用效果、异步完成时机、性能和画面待实机，不打verified标签。

测试：新生成狮鹫，绑定并开记录，显式开启重置实验后首次隔离，观察5秒；不等待原任务完成或自然落地。若静止，在同一隔离切5101约5秒；若仍移动，保存失败即可，不反复开关。最后关闭隔离约2秒后关闭记录。详见README。
