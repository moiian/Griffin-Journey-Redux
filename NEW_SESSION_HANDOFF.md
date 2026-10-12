# 新会话交接：Griffin Journey Redux（2026-10-13）

## 可直接贴给新会话

继续D:\_Project\Griffin MOD。先读项目AGENTS.md和NEW_SESSION_HANDOFF.md，再读CleanAnimationLab/README.md及对应模块。当前只验证5100/5101隔离播放，不继续扩大旧阶段三脚本。所有测试功能默认关闭，以勾选开关启用；新测试工具按职责拆文件。禁止非必要哈希；不修改OJR/LMD/NickCore；只控制生成接口返回的精确实例。直接完成代码/离线检查/部署并给实测步骤，不反复询问允许继续。

## 当前文件与状态

- Beta：Beta/GriffinFlightBeta.lua，0.1.35，保持不改。用户驾驶、Hip座位分离、头部镜头已反复实测；保护等细节以Beta源码/项目AGENTS.md为准，不用本摘要覆盖。
- 旧实验：根GriffinMountExperiment.lua，0.3.23-stage3-target-ab，保留原样作为参考。不是新工具的运行依赖。
- 干净工具：CleanAnimationLab/GriffinAnimationLab.lua及_GriffinAnimationLab四个模块，0.1.1。原隔离首次位移失败；本版新增落地前后只读记录，实机待验收；没有加入代码飞行、乘客或镜头。
- 游戏：P:\games\steamapps\common\Dragons Dogma 2；部署在reframework/autorun；日志在reframework/data。
- 本地仓库：D:\_Project\Griffin MOD\Repository；远端https://github.com/moiian/Griffin-Journey-Redux；实验分支experiment/oxcart-preset-ui。仅源码/测试/历史说明入Git，设置、日志、转储、备份不入Git。用户授权本地独立改动提交并推送，实测通过才打verified里程碑。
- 转储：游戏根il2cpp_dump.json，约1.1GB，按类型定向读取。旧牛车仅参考，禁止重走牛车生成/跳时失败路线。

## 已验证且应保留

1. NickCore.enemySpawner.spawn_enemy("Griffin", position, thinkStop)异步返回共享表，稍后填go/chara。普通ch253000_00。CharacterID后缀不保证底层唯一。
2. Beta目标导向飞行曾追错目标。已验证TargetController ManualPlayer + setTarget修复，Beta“让狮鹫听话”能正确追玩家。不要再以为两个脚本使用不同生成器。
3. 导航追玩家Transform。仅Hip偏移能移动可见模型而不移动导航目标；已验证的Hip更新/恢复与头部相机管线不要推倒。
4. 玩家防坠落请求拦截解决已测黑屏；跳过狮鹫思考解决主动攻击路人。乘客持续resetFallHeight及SecFall清零实验明显改善消失问题；具体根因仍不全部确认，不能把阻止销毁计数当作已根治。
5. 原生冲刺Ch253WrapAroundStartLoop累积身体抽动，后续确认并非只在俯冲/跌落才发生；悬停和低档动作未观察到同样现象。碰撞挤压只是猜测，不能当作根因。
6. Bank0/5100 ch53_000_com_flight_loop为滑翔；5101 ch53_000_com_flight_loop_flapping为挥翅。完整冲刺内部混合这两种资源；顶层动作名不等于内部动画切换。
7. 0.3.20用户确认两个隔离动画无位移；旧日志最后5101约148秒722样本位置/旋转不变。附加层保留，5197名字带flightshake不证明它造成抽动。

## 失败路线与最新证据

- 0.3.21在隔离播放后代码写Griffin Transform、上下文和controller.warp，玩家随行。用户看到翻转、反向和远距回跳。代码写后读回正确不代表后续引擎不覆盖。
- 0.3.22额外隔离FlightControl碰撞调整事件与Character.onRootApply，仍失败。最新日志碰撞两个Hook各5900次，根应用0次；上下文跟代码，但Transform最大偏离233米。
- 0.3.23同轮切ManualPlayer目标，已确认真实目标为玩家，仍回飞。不能继续将回飞解释为唯一的目标错误。FlightControl缓存(0,0,0)/(128,0,0)本身也不证明导航接管（存在世界原点平移）。
- 之后用户发现纯5100/5101也有时飞走。最新用户发现需多次停止后掉地面，才可原地播放。日志原始动作由NormalLocomotion变为FrontFallLanding/Wait，提示进入状态可能有影响，但未证明唯一原因。
- 旧按钮没有3秒限制；ui_button直接imgui.button，资源播放不经过动作冷却。明确的交互问题：active时capture直接拒绝，切动画必须stop；stop恢复FSM/root，原生行为重新接管。捕获再排队play也没有完整并发防护。
- 新干净工具只解决操作/生命周期：勾选隔离一次，5100/5101只换基础层；原状态只捕获一次；旧排队版本号取消；取消隔离才恢复。没有靠多次Stop、请求落地、锁死Transform掩盖初次残余位移。

## 下一轮实测的两个独立判据

1. 首次启用隔离是否仍位移？如仍移动，保存日志，不能宣布无位移修好。
2. 在有效隔离状态来回切5100/5101，是否不再恢复原生控制/落地？这项与首次残余位移问题分开判断。

如继续调查，优先读新日志坐标/FSM/root与当前原生状态，做窄范围对照；避免再把所有驾驶、姿态、相机保护一起带入实验。

## 未部署草稿和本地证据

工作区C:\Users\Aelinore\Documents\Codex\2026-10-11\dragon-s-dogma-2-mod-1\outputs：drafts里的terrain-sync和isolation-check都是未部署草稿，不是0.3.24正式版本。STAGE3_0320_VS_0323_ISOLATION_COMPARISON.md及各FAILED/POSE证据仅本地。不要将草稿/API签名存在当作实机成功。

旧关键日志：GriffinMountExperiment_Flight_20261012T143008Z_2029048.json（0.3.20静止）；20261012T163617Z_557209与163820Z_679341（0.3.23近期多轮状态）。旧direct_motion.samples可能只保留最后一轮，events才覆盖此前启动/停止；开关一次不等于一次完整记录。

## 2026-10-13 0.1.1最新进展（覆盖0.1.0待验收描述）

用户实测：首次隔离仍位移，反复启停无效；关闭后确实落地一次，再开启才原地播放，落地不稳定。170907Z日志三个隔离段首末样本位移约4.661/4.693/1.793米，FSM=false、RootMotion=0、拦截持续命中。日志没有覆盖关闭后的落地，不能定位唯一根因。

0.1.1只补证据：新增state_probe.lua，记录仍默认关闭；勾选状态与坐标记录后在隔离关闭时也连续采样，包含原生动作、着地／飞行、SecFall、LandingProcessor、飞控移动向量、实体／上下文／碰撞体。启停和Reset前后另存快照，轮号区分隔离会话，切动画不换轮号。最高20Hz、3000条，满额不结束动画。普通帧两秒保存，记录数据不入Git。字段独立记错；内部非零向量不等于已找到实际位移写入者。

Lua54五文件语法、原生命周期与新增状态记录／错误隔离／归属／暂停队列／上限／恢复失败重试模拟通过。本版没有强制落地、清速度或锁Transform；首次位移未修复，原生读数和性能待实机，不打verified标签。按CleanAnimationLab/README.md做一次对照即可，失败落地过程也有用。Beta0.1.35、旧阶段三0.3.23、配置和其他MOD不改。
