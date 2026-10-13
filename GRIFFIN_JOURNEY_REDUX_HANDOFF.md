# Griffin Journey Redux 新会话交接

日期：2026-10-13。

## 当前工作与版本

模组正式名称为 **Griffin Journey Redux**。本轮以已解决垂直抖动和间歇性大抽动的 `0.1.46-beta` 为基线，完成并部署 `0.2.0` 干净版；新菜单及新模块加载的实机验收仍需用户正常使用确认，不能把离线通过写成实机通过。

- Git 仓库：<https://github.com/moiian/Griffin-Journey-Redux>。
- 当前分支：`experiment/oxcart-preset-ui`；本轮不自动合并 `main`。
- 基线标签：`baseline-beta-v0.1.46-jitter-fixed`，已经推送。
- 基线本地备份：`D:\_Project\Griffin MOD\Backups\baseline_0146_before_clean_20261013_084530`，包含源码、部署文件和用户设置。
- 干净版源码目录：`D:\_Project\Griffin MOD\GriffinJourneyRedux`。
- Git 工作目录：`D:\_Project\Griffin MOD\Repository`。
- 游戏部署目录：`P:\games\steamapps\common\Dragons Dogma 2\reframework\autorun`。
- 入口：`GriffinJourneyRedux.lua`。升级后不能同时启用旧 `GriffinFlightBeta.lua`。
- 设置继续使用 `reframework/data/GriffinFlightBeta_Settings.json`，兼容已有座位、按键和精调数据。

`Beta/GriffinFlightBeta.lua` 保留为旧基线源码，后续干净版开发以新目录为准。`CleanAnimationLab` 属于另一条开发路线，本轮没有修改，不根据旧交接中的版本号推断其现状。

## 本轮用户明确要求

玩法代码与开发 Debug 分开，正式给其他玩家发布时可以不带 Debug 文件夹。取消按钮和实验文字的额外颜色高亮，技术诊断集中在 DEBUG。正常菜单按一般设置、飞行设置、镜头设置、座位预设和按键设置组织。

“默认关闭写盘”已经澄清为：**仅关闭调试写盘；用户设置正常保存。** 不能因此关闭座位预设、按键等设置的自动保存，也不能让已验证防抖依赖日志开启。

用户最终限定的移除范围：

- 移除“稳定导航锚点”开关及其根 Transform 固定偏移实现。
- 移除“详细骨骼姿态记录”开关及对应旧记录实现。
- 没有继续保留价值的重复探针可以移除；本轮保留三秒精细探针，移除重复的两个旧六十秒记录器。

必须保留：

- 玩家和所有当前座位预设接管 NPC 的自由落体防抖；随从和同行 NPC 均包含在内。
- 狮鹫防抖独立可选开关。
- 实验 1：持续重置跌落高度与 `SecFall`。
- 实验 2：强制 `IsGround` 查询返回着地。
- 实验 3：当前狮鹫持续重置跌落高度与 `SecFall`。
- 玩家／乘客扣血拦截、落座乘客自动传送／丢失拦截。
- “跳过随从丢失检查”和“阻止乘客被生成器销毁”两个可选开关。
- 跳过狮鹫思考、驾驶角色坠落死亡请求拦截、玩家 FSM 冻结。
- 实体预设 `[1]` 的手动调试入口。

截图中已勾选功能保留；未勾选功能默认关闭。已有用户设置继续读取，不重置精调参数。实验 1／2／3 不与防抖强制互斥，允许组合使用。

## 模块结构

```text
GriffinJourneyRedux.lua             入口、加载顺序
_GriffinJourneyRedux/               功能模块，发布时必需
  session.lua                      设置读取、会话状态、归属校验
  ownership.lua                    防抖所需的精确实例接口
  antijitter.lua / fall_stop.lua    自由落体停止和重新启动拦截
  player.lua                       玩家实体同步、Hip 捕获与恢复
  flight.lua                       分档飞行、导航目标
  griffin.lua                      目标选择、思考跳过、坠落保护
  input.lua                        HID、按键及设置保存
  camera.lua                       头部镜头、水平转向跟随及恢复
  seating.lua / passengers.lua     座位计算、乘客绑定与释放
  protection.lua                   驾驶角色及乘客保护
  spawning.lua / lifecycle.lua     生成、删除、停止与恢复
  presets.lua / ui.lua             预设编辑及用户菜单
  callbacks.lua                    引擎更新阶段、兼容桥接
_GriffinJourneyReduxDebug/          可选开发模块，玩家包可完全省略
  tools.lua                        DEBUG 菜单、实验、按需遥测和观察 Hook
  fine.lua                         三秒逐帧位置记录
```

各功能文件通过同一个私有 `ctx` 共享本次脚本状态，模块工厂内使用 `local _ENV=ctx`。不要随意改成各自复制的局部状态，否则驾驶、恢复与原生 Hook 可能看到不同实例。显式兼容旧状态／桥接名，供原工具使用；功能变量没有直接写入 `_G`。

## 防抖与日志经验

垂直抖动：原生 `FreeFallController` 在 MOD 定位后仍输出位移。已验证方案为对当前驾驶玩家和精确接管 NPC 停止正在运行的自由落体，并拦截其重新启动。狮鹫使用独立开关，只处理本次生成返回的实例。暂停、离座、离队、结束和关闭后放行。不要把数值 `0` 当作 `via.vec3` 返回值拦截更新函数。

水平间歇性大抽动：本 Beta 曾在游戏线程同步序列化、重写不断增大的 JSON 日志。用户观察到探针结束时集中写盘会集中抽动；延后到暂停／结束驾驶写盘后，用户长时间飞行恢复流畅，之前陡峭的大抽动消失。

`0.2.0` 进一步改为默认不运行健康遥测、常规日志采样或诊断观察 Hook。开启常规调试记录才缓存最近 600 个样本、400 个事件；游戏正在驾驶且未暂停时不写日志。三秒探针独立手动启动，到时只停止采样，暂停或结束驾驶后保存；保存失败保留数据等待重试。设置保存独立于这些诊断开关。

完整抖动经验文档另见本会话输出 `DD2_Griffin_Jitter_Solution_and_Mod_Stutter_Handoff.md`。这是本地分析文档，不把包含原始测试数值的内部材料自动加入 Git。

## 需要保留的运行契约

- 依赖已安装的 NickCore、EnemySpawner 和 `run_once`。只控制 `spawn_enemy` 返回的精确实例，不按 Character ID 接管其他狮鹫。
- 不修改 OJR、LMD、NickCore 或其他会话的工具。
- 玩家实体承担导航，Hip 承担座位显示。乘客实体固定各自在预设 `[1]` 的物理坐标，普通预设只改变各自 Hip 显示。
- 保留已验证的 `UpdateJointExpression` 捕获、写入、恢复顺序，以及普通暂停／照片模式显示保持。
- 停止驾驶或释放乘客保持当前真实实体位置，不回到出发点；恢复原 FSM、朝向、Hip 与镜头。恢复失败保留引用供重试。
- 同行 NPC 使用 `NPCUtil.isAccompanyPLParty(app.Character)` 判定；普通路人不接管。离队及失效实例立即退出控制范围。
- 禁止非必要文件哈希校验。Git 只提交源码与通用说明，不提交用户设置、日志、转储、备份和本地测试产物。

## 本轮验证范围

已运行 Lua54 编译、既有完整玩法回归，以及玩家／随从／同行 NPC／狮鹫防抖的实际模块接入测试，覆盖精确实例正反对照、暂停、退出重进、控制器变化、单 NPC 异常隔离和实验组合。

另以实际不包含 Debug 文件夹的玩家目录运行测试：正常驾驶和防抖可用，默认持续驾驶、暂停、退出及 Reset 无调试写盘，健康遥测读取为零；设置修改仍自动保存。带 Debug 的目录验证了缓存上限、暂停只保存变更数据、三秒到时不写盘、保存失败保留及重试。

这些是离线模拟与文件检查，不代替 `0.2.0` 实机加载和画面验收。下一会话先核对本轮部署结果与 Git 状态，不把旧 Beta 路径作为最新源码。

部署内容已逐文件比较：项目、仓库工作区与游戏的 20 个 Lua 文件一致；设置文件与基线内容一致；游戏旧 Beta 入口已撤下。玩家包有 18 个 Lua 文件，不带 Debug；开发包有 20 个 Lua 文件。新版本在结束旧驾驶并 Reset scripts 后加载。

## 用户指定的下一阶段内容（仅转述，不分析）

下一步的开发围绕精细打磨细节，如运动惯性、操作习惯。

还有一个没解决的问题：狮鹫的 AI 问题。虽然停止了它的思考，但狮鹫依然会自主决策，只是无法实施。但每当玩家发出动作指令时，新动作的指令就会以新决策为目标，例如攻击不远的 NPC、飞向下一区域等。

以上为用户要求转述的观察和后续方向，本交接不添加原因分析、修复方案或已解决结论。


## Griffin Journey Redux 0.2.1：动作提交前重选玩家目标（2026-10-13）

复用现有ManualPlayer/setTarget接口，在每次当前狮鹫动作真正提交前重选玩家目标，并紧接requestActionCore；两者处于同一行为队列回调。覆盖手动分档／运动指令、回中及起飞完成的自动悬停、驾驶中外部动作接管，以及非驾驶单次动作桥接。只对精确返回实例／当前玩家执行，每个实际请求一次，不逐帧刷目标、不加短动作或AI冻结，不改变0.35秒请求间隔和动作节点。乘客动作不参与此目标重选。

暂停／已结束驾驶／替换意图／过期会话／删除／归属变化均在原生目标写入前拒绝；非驾驶桥接也检查暂停。目标选择失败不继续发送动作，走原错误处理。Settings、防抖、座位、镜头及默认诊断关闭保持。20个Lua54编译，完整玩法、防抖、玩家包无Debug与默认零诊断输出回归，以及新目标／动作顺序、每请求一次、冷却／暂停／过期／替换／退出／归属和目标失败检查通过；已部署，原生AI效果待实测，不打verified。

0.2.0已获用户基本运行确认。使用0.2.1正常切换运动动作及自动悬停即可，重点观察悬停后的下一动作是否仍短暂失去玩家方向控制；不要求探针或额外开关。说明见AI_021_TARGET_RESELECT.md。仅源码与通用说明入Git，用户观察／日志／设置／备份／本地测试不上传。


## 0.2.1动作前重选撤回；运行恢复0.2.0（2026-10-13）

撤回每次动作提交前强制重选玩家目标的实验，恢复已确认正常的0.2.0完整Lua基线，包括原非驾驶动作桥接。保留原本开始驾驶及“让狮鹫听话”的ManualPlayer选择、防抖、座位、镜头、设置和默认关闭诊断。方向5实验记录保留在历史，不作为已解决方案；不继续修改调用顺序或叠加目标重选次数。

20个Lua与备份0.2.0逐文件内容一致，项目／游戏／仓库一致；Lua54及完整既有玩法、原生精确实例、防抖、玩家／开发包和默认零诊断输出回归通过。当前运行版本0.2.0，原生AI目标问题仍未解决。后续等待用户提供牛车驾驶MOD，再按其实际AI／任务／动作接管机制评估参考价值，不恢复隔离动画路线。


## Griffin Journey Redux 0.2.2：独立决策组件接管实验（2026-10-13）

新增独立ai_takeover模块及飞行设置“方向6：禁用狮鹫决策组件（实验）”，默认关闭、仅本次脚本会话、不写Settings、无需Debug目录或探针。可驾驶前勾选或途中开关，仅取得当前返回狮鹫的AIDecisionMaker，核对角色／GameObject／当前组件引用，保存真实Enabled后设false并读回。行为帧及实际动作提交前检查；仅发现重新启用时补关，不反复无条件写。当前转储确认Maker继承via.Behavior，启用时复核Enabled实例方法、参数数量及Boolean／Void返回签名。

取消开关、结束驾驶和Reset恢复原值，原false保持false；暂停普通更新不写组件，显式退出仍恢复。失效／引用替换拒绝旧引用写入，禁用部分失败保留原值回滚；恢复失败挂到原驾驶recovery并阻止新驾驶／删除，重试或同Lua会话重载沿用保存引用。只接管Maker，不停NavigationAI、MonsterNavigationController、MotionFsm2、ActionManager或FlightControl，不直接播片或写狮鹫位移／朝向，也不恢复已撤回的动作前目标重选。

21个Lua54编译，完整玩法／防抖／玩家包无Debug／默认零诊断输出回归，新组件精确正反例、原true／false、按需补关、暂停／预先勾选／关闭／退出／Reset、签名／归属／读回、部分写入回滚及恢复重试通过；实际UI接入模拟确认Maker关闭时仍发送冲刺／自动悬停，原手动目标选择次数不增加。已部署，真实组件禁用对原生飞行及AI的效果待实机，不打verified。

用法：重载至0.2.2，在飞行设置开启上述开关，正常驾驶、悬停再运动；无需记录或新生成对照批次。确认状态为当前狮鹫AIDecisionMaker已禁用，观察动作起始是否还先沿自主目标转向／移动。若原生飞行停住，取消本开关恢复原值；不叠加其他导航／运动组件禁用。公共说明见AI_022_COMPONENT_TAKEOVER.md。设置、防抖、座位、镜头、0.35秒请求间隔及其他会话工具保持。


## Griffin Journey Redux 0.2.3：取消身体倾斜导致的驾驶退出（2026-10-13）

删除身体前向量水平投影小于等于0.2时触发的“Griffin is too vertical”错误。有效身体姿态接近竖直或倒置时继续驾驶与座位控制，不因倾斜自动结束。正竖直时沿用上次有效水平方向；没有历史方向时从身体右轴推导水平朝向，避免除零。无效旋转和实例归属异常仍走原退出恢复。

21个Lua54编译及既有玩法、防抖、玩家包无Debug、默认零诊断输出和决策组件生命周期回归通过。新增实际驾驶与双随从／同行NPC模拟覆盖原阈值两侧、正负90度、倒置和侧滚，确认驾驶／座位保持、坐标有限及异常旋转恢复。已部署，原生画面效果待验收，不打verified标签。手柄输入角度、座位视觉俯仰参数及Settings保持。

方向6仍为默认关闭的会话实验，正常驾驶保持关闭；本版没有新增AI修复或扩大组件禁用。方向5保持撤回，隔离动画路线保持放弃。

## Griffin Journey Redux 0.2.4: hover and sprint controls (2026-10-13)

RT selects gear 2 sprint directly; LT brakes directly to gear 0 stationary hover. From hover, the left stick enters gear 1 body-relative horizontal movement; centering eases back to stationary hover. The horizontal right stick turns the Griffin with a slight delay. Slow movement and turning share the same hover action. Default slow speed is 3 m/s and turn speed is 75 degrees/s; both are adjustable.

The former native low-speed directional actions are removed from normal controls. Previous sprint guidance, takeoff, landing, seats, camera and protection remain. Code movement uses only the retained spawned Griffin, releases on sprint/landing/external action/stop/Reset, and preserves current-location recovery. AI research is paused; the optional component experiment remains off by default. No native AI fix is claimed.

All 22 Lua54 files and offline gameplay, precise protection, settings, Debug-absent/default-no-diagnostics, movement/input/lifecycle/synchronization regressions pass. In-game native stability and handling remain unverified. See CONTROLS_024_HOVER.md. Development remains on the existing experiment branch; main is unchanged.


## Griffin Journey Redux 0.2.5: directional hover controls (2026-10-13)

Correct low-speed strafe direction; horizontal left stick now controls both strafe and eased facing. Right stick returns to native camera control. Separate forward, strafe, backward, vertical-climb and turn speeds all accept zero, with compatible migration from the old shared speed. Hold RB for code-driven vertical ascent, without the former hover action request. LB landing and gear 2 sprint guidance remain unchanged. Settings, precise ownership, pause/exit/recovery and default-no-diagnostics behavior are preserved.

All 22 Lua54 files and existing/new offline regressions pass, including zero settings/save/reload, input polarity, keyboard compatibility, right-stick camera restoration and continuous RB ascent. Native direction and handling still require an in-game check. See CONTROLS_025_HOVER.md. AI research remains paused.


## Griffin Journey Redux 0.2.6: longitudinal steering and continuous low-speed camera (2026-10-13)

Left-stick forward/back moves along the Griffin's facing; left/right turns without strafing. The low-speed camera continuously follows horizontal body heading, including idle catch-up after releasing the stick, with an independent adjustable speed (0–360 degrees/s, default 120). Existing body-turn and movement settings remain compatible; obsolete strafe data is ignored. Sprint guidance and its camera settings remain unchanged.

All 22 Lua54 files and existing/new offline gameplay, protection, camera, settings and lifecycle checks pass. Exact camera ownership, native-unit calibration, shortest-arc rate bounds, pause/release and camera-failure isolation are covered. Native visual behavior and handling remain unverified. See CONTROLS_026_CAMERA.md.


## Griffin Journey Redux 0.2.7: shared camera-follow policy (2026-10-13)

Low-speed camera following now runs only while body yaw is turning, and stops without idle catch-up when rotation settles. Both gears share right-stick blending, takeover threshold, hysteresis, recovery delay, native-unit calibration and shortest-arc easing. Speed settings remain separate; gear 2's trigger and behavior are preserved. Low-speed right-stick takeover also works with the sprint-follow toggle off.

All 22 Lua54 files and existing/new offline regressions pass. Differential output comparison against saved 0.2.6 source preserves sprint-camera behavior across 2,000 simulated frames. Native handling still requires in-game acceptance. See CONTROLS_027_SHARED_CAMERA.md.


## Griffin Journey Redux 0.2.8: head-camera recovery and safe hook context (2026-10-13)

Replace per-frame head-target writes with action-triggered checks and a 0.5-second fallback, writing only changed bindings. Temporary native target/controller/main transitions retry without permanently disabling head follow; explicit off remains authoritative. Manual-camera hooks safely snapshot missing/nested context, and disabled render diagnostics skip native camera sampling. Existing driving and shared yaw policies are preserved.

All 22 Lua54 files and existing/new offline regressions pass, including bounded healthy reads/zero redundant writes, exact binding recovery, manual off, partial failures and a reproduced old nil-context callback. Native terrain clipping/shake remains unverified and is not claimed fixed. See HEAD_CAMERA_028_GUARD.md.


## Griffin Journey Redux 0.2.9: adjustable low-speed inertia (2026-10-13)

Split low-speed translation into independent acceleration, released/reduced-input deceleration and reverse-braking time constants. Defaults are 0.2/0.6/0.6 seconds; each accepts 0–3 seconds and saves automatically. Horizontal movement and vertical climb share acceleration/deceleration. Opposing input brakes through zero before accelerating in the new direction, without locking input. Analytic integration splits at the zero crossing; body-turn smoothing and LT hard stop remain unchanged.

All 22 Lua54 files and existing/new offline regressions pass, including settings/defaults/zero/bounds/save/reload, horizontal and vertical response, opposing-input crossing, live input changes, rotated 30/120Hz agreement, LT/recenter and unchanged 2,000-frame sprint-camera output. Native handling remains to be checked in game. See CONTROLS_029_INERTIA.md.


## Griffin Journey Redux 0.3.0: two gears and dedicated vertical controls (2026-10-14)

Use gear 1 for all hover/code movement and gear 2 for native sprint; remove gear 0. Ground-only takeoff finishes in gear 1. Gear 1 defaults are A up, Y down and RS native landing. RB dive / LB climb immediately enter gear 2; sprint guidance continues without repeated requests. LT preserves existing low-speed inertia and suppresses held input until neutral. Stick release never restarts the hover action.

Add independent up/down speeds and vertical time constants (default 0.6 seconds each, range 0–3), retain separate horizontal acceleration/coast/reverse-braking settings, and enable player spherical navigation in gear 1. Former default bindings migrate once; custom/None bindings are retained. All 22 Lua54 modules and existing/new offline controls, settings, protection, camera and lifecycle regressions pass, including analytic LT/vertical response, code down versus native landing, shoulder transitions, sphere response and 30/120Hz consistency. Native handling remains for in-game acceptance. See CONTROLS_030_TWO_GEARS.md.


## Griffin Journey Redux 0.3.1: independent vertical startup and stopping (2026-10-14)

Replace the two shared vertical response constants with separate up-start/up-stop/down-start/down-stop controls, defaulting to 0.6/0.2/0.2/0.6 seconds (0–3, zero immediate). Vertical reversal and LT use outgoing stopping response; reversal then uses incoming startup response. Migrate old up/down values to up startup/down stopping, preserving new explicit values and zero. Other controls and horizontal/camera behavior are retained.

All 22 Lua54 modules and existing/new offline regressions pass, including migration/save/reload, independent asymmetric velocity/distance, both reversals, LT, bounds/zero and prior two-gear behavior. In-game feel remains to be checked. See VERTICAL_031_INERTIA.md.


## Griffin Journey Redux 0.3.2: both-gear landing and ordinary action phase guard (2026-10-14)

RS native landing now works from both gears. Grounded ordinary hover/sprint/landing requests are suppressed and queued native submissions recheck phase. DEBUG adds a checked-by-default, session-only prohibition on ordinary cross-phase actions; disabling it permits stage testing, while player packages without Debug keep the guard on. External tools retain their explicit allow_cross contract.

All 22 Lua54 files and existing/new offline regressions pass, including both-gear/held landing, grounded hover cancellation, airborne rearm, Debug toggle/reset, queued invalidation and canceled-takeoff recovery. Gear 2 inertia remains unchanged; native behavior still needs in-game acceptance. See PHASE_032_LANDING.md.


## Griffin Journey Redux 0.3.3: restore automatic gear 1 control after takeoff (2026-10-14)

Wait for valid airborne flags through the native takeoff animation's grounded tail, then explicitly enable gear 1 code controls. Previously a late Flight/Ground update could disable controls permanently until LT. Adopt an already-active exact hover without requesting it again; other airborne nodes receive one hover request. Held input release and manual/external cancellation remain.

The actual 0.3.2 module reproduces the disabled-control failure offline; 0.3.3 passes the same case, including forward/back/up/down without LT. All 22 Lua54 modules and prior controls/inertia/phase/camera/lifecycle regressions pass. In-game acceptance remains pending. See TAKEOFF_033_HANDOFF.md.


## Griffin Journey Redux 0.3.4: earlier hover handoff and continuous held input (2026-10-14)

Request gear 1 hover as soon as valid airborne flags arrive, without waiting for the native takeoff action to end. Remove the automatic takeoff input-release gate: held forward/back, turning and A/Y continue into slow control without a new press. Holding takeoff A now continues code ascent. LT retains its own neutral gate and inertia.

All 22 Lua54 files and previous/new offline regressions pass, including native-takeoff-still-active handoff, each held translation axis, pause/resume and preserved LT behavior. Native control timing remains to be checked. See TAKEOFF_034_HELD_INPUT.md.


## Griffin Journey Redux 0.3.5: minimum takeoff time and gear-specific player anchoring (2026-10-14)

Wait at least 1.5 seconds after observed takeoff start before automatic hover or sprint. Exclude paused time; queue early RT/RB/LB selection with LT replacement while retaining continuous movement input. Gear 1 real player position uses preset [1] instead of spherical navigation; entering gear 2 through RT/RB/LB restores sphere navigation immediately, and LT restores preset anchoring. Current visual seats/preset selection remain independent.

All 22 Lua54 modules and existing/new offline controls, inertia, stage, camera and lifecycle regressions pass. New coverage includes the minimum/queued inputs/pause, nonzero and live preset offsets, physical layers, visual selection retention and same-frame RT/RB/LB/LT navigation switching. Native timing and visuals remain to be accepted in game. See TAKEOFF_035_TIMING_AND_ANCHOR.md.


## Griffin Journey Redux 0.3.6: measured sprint-to-hover momentum (2026-10-14)

Change takeoff minimum to 1.89 seconds. Measure native sprint world velocity from Universal position deltas and inherit it on LT after hover binds, with independent 0–3 second decay (default 0.8). Display measured total/horizontal/vertical speed. Reject stale/gapped/teleported samples and clear momentum on ground, changed binding, external takeover or new sprint. Native displacement and code coasting do not overlap.

Optional Debug native-speed inspection is read-only and bounded. Metadata identifies candidate FlightControl members, but dive/climb speed modulation awaits native validation and is not enabled. All 23 Lua54 modules and previous/new offline regressions pass, including vector/distance, 30/120Hz agreement, transition sampling, pause, lifecycle, zero/save and bounded zero-write inspection. Real sprint speed and LT feel remain for in-game acceptance. See SPRINT_036_LT_MOMENTUM.md.


## Griffin Journey Redux 0.3.7: bounded native speed-rate comparison (2026-10-14)

Add an opt-in Debug A/B test of the native FlySpeedRate getter: original horizontal speed, temporary 0.8 multiplier, then automatic restoration. Return changes are scoped to the exact driven controller/status/native thread; shared objects are not written. Abort on control/phase/pause/ownership/sample changes. Short result lines and separate speed readouts improve readability.

All 24 Lua54 files and previous/new offline regressions pass, including per-call hook storage, exact/shared-object/thread negatives, nesting, nil/retirement/stop behavior, positive response and rejection of a hit without measured speed change. The native candidate remains unverified until game testing; the unified dive/climb model is not enabled. See NATIVE_SPEED_037_AB.md.
