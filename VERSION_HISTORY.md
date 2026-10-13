# 狮鹫项目版本索引

当前部署测试版：Beta 0.1.35（新增狮鹫独立跌落重置与读数，待实机）；最近用户确认乘客基本正常的版本为0.1.21，完整驾驶基线为0.1.17。阶段三工具当前0.3.23。下文历史条目的待验证状态以随后用户验收记录为准。

现有记录原先分散在版本快照、测试步骤、STAGE3_NOTES和实测报告中，并非每版都有完整统一的增删清单。本索引集中列出已核对的Beta版本变更与成败；旧文件原文中的“待验证”属于当时状态，当前结论以本索引及后补验收记录为准。源代码快照可用于内容比较和回档；现已将既有脚本快照导入本地Git历史，提交时间为2026-10-11导入时间，不冒充原开发时间。

## Beta版本

| 版本 | 主要新增／删减 | 已知结果与边界 |
| --- | --- | --- |
| 0.1.0 | Beta最小生成、友方、锚定、冻结玩家FSM、A/RT/LT、删除流程 | 初版；不等同当前验证基线 |
| 0.1.1 | 支持阶段三动作接管；距离/FOV设置；默认跨阶段；A可再次触发降落 | 后续由目标选择等修复完善 |
| 0.1.2 | 玩家相对高度滑条；逐帧跌落高度重置 | 高度控制新增；未解决黑屏与错误目标 |
| 0.1.3 | 冻结玩家FSM对照；飞行目标遥测 | 诊断版；不是失控原因已确定 |
| 0.1.4 | 跳过本狮鹫思考开关；仅当前驾驶玩家坠落死亡请求拦截 | 用户确认可抑制主动攻击、消除对应黑屏；仍有目标问题 |
| 0.1.5 | 目标坐标记录与仅一次坐标同步 | 当时目标不是玩家，同步被拒绝；未修复导航 |
| 0.1.6 | 仅一次切换目标到玩家 | 用户确认目标选择后正常操控 |
| 0.1.7 | 跳过失效随从引用，避免远飞时自动退出并返回起点 | 用户确认有效 |
| 0.1.8 | 默认思考跳过与防坠落；开始驾驶合并玩家目标；分层追逐来源实验 | 未选层仍可能留在原处，后续0.1.9调整 |
| 0.1.9 | 所有层跟随中立锚点，仅选中层接收摇杆偏移 | 用户确认Transform决定追逐，Hip可单独影响模型并恢复 |
| 0.1.10 | Hip头顶与旧Camera offset整骨架显示；座位滑条；晚期续写 | 失败：模型脱离，取消恢复异常 |
| 0.1.11 | 整骨架绝对定位；修复取消勾选切回完整同步 | 失败：读回坐标随动，但可见模型仍脱离 |
| 0.1.12 | 删除整骨架头顶模式、姿势缓存及晚期骨架续写；头顶Hip复用0.1.9更新/恢复路径 | 2026-10-11用户确认偏移与恢复正常；当前实测基线 |

| 0.1.13 | 独立镜头互斥测试：BaseOffset三轴滑条、TargetJoint跟随Hip/狮鹫头部、限定驾驶和恢复；保留0.1.12 Hip路径 | 用户确认头部镜头跟随与恢复正常；Hip跟随及偏移滑条无效；仅验证头部镜头路径 |

| 0.1.14 | 默认头部球面导航；独立半径、左右/上下最大角度滑条；保留旧导航开关和已验证Hip/镜头路径 | 用户确认正常；建议半径约2.5米、左右50°、上下45°；回中高度待增加 |

| 0.1.15 | 球面回中高度滑条，抬升时补偿水平距离且保留半径；新默认2.5米/50°/45°，保留现有精调 | 离线回归通过，实机高度待验证；仅记录新分档方案，未实现按键改动 |

## 源码快照实际清单

以下逐个读取脚本头部版本生成；文件夹名的0110代表0.1.10，不能按字符串误判成0.1.1。

| 类型 | 脚本版本 | 本地项目相对路径 |
| --- | --- | --- |
| Beta | 0.1.0-beta | `Beta\beta_010\GriffinFlightBeta.lua` |
| Beta | 0.1.1-beta | `Beta\beta_011\GriffinFlightBeta.lua` |
| Beta | 0.1.10-beta | `Beta\beta_0110\GriffinFlightBeta.lua` |
| Beta | 0.1.11-beta | `Beta\beta_0111\GriffinFlightBeta.lua` |
| Beta | 0.1.2-beta | `Beta\beta_012\GriffinFlightBeta.lua` |
| Beta | 0.1.3-beta | `Beta\beta_013\GriffinFlightBeta.lua` |
| Beta | 0.1.4-beta | `Beta\beta_014\GriffinFlightBeta.lua` |
| Beta | 0.1.5-beta | `Beta\beta_015\GriffinFlightBeta.lua` |
| Beta | 0.1.6-beta | `Beta\beta_016\GriffinFlightBeta.lua` |
| Beta | 0.1.7-beta | `Beta\beta_017\GriffinFlightBeta.lua` |
| Beta | 0.1.8-beta | `Beta\beta_018\GriffinFlightBeta.lua` |
| Beta | 0.1.9-beta | `Beta\beta_019\GriffinFlightBeta.lua` |
| Beta | 0.1.12-beta | `Beta\GriffinFlightBeta.lua` |
| 阶段工具 | 0.3.17-stage3-think-fall | `GriffinMountExperiment.lua` |
| 阶段工具 | 0.1.0-stage1 | `stage1_verified\GriffinMountExperiment.lua` |
| 阶段工具 | 0.2.0-stage2 | `stage2_020\GriffinMountExperiment.lua` |
| 阶段工具 | 0.2.1-stage2 | `stage2_021\GriffinMountExperiment.lua` |
| 阶段工具 | 0.2.2-stage2 | `stage2_022\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.0-stage3-observe | `stage3_030\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.1-stage3-log | `stage3_031\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.10-stage3-anchor-stick | `stage3_0310\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.11-stage3-camera | `stage3_0311\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.12-stage3-slow | `stage3_0312\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.13-stage3-directions | `stage3_0313\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.14-stage3-unlimited | `stage3_0314\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.15-stage3-gears | `stage3_0315\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.16-stage3-beta-bridge | `stage3_0316\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.2-stage3-actions | `stage3_032\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.3-stage3-select | `stage3_033\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.4-stage3-record | `stage3_034\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.5-stage3-test | `stage3_035\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.6-stage3-target | `stage3_036\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.7-stage3-yaw | `stage3_037\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.8-stage3-yaw-fix | `stage3_038\GriffinMountExperiment.lua` |
| 阶段工具 | 0.3.9-stage3-stick-lure | `stage3_039\GriffinMountExperiment.lua` |

| Beta实测基线 | 0.1.12-beta | `Beta\beta_0112_verified\GriffinFlightBeta.lua` |

## 查询与回档

- Beta细节：BETA_011*_TEST.md、THINK_FALL_TEST_0317.md和Beta/README.md。
- 阶段工具细节：STAGE3_NOTES.md、STAGE3_*.md、FLIGHT_RECORDING_*.md、ACTION_TEST_OBSERVATIONS_20261011.md。
- 当前已确认源码另存Beta/beta_0112_verified，避免后续覆盖后失去实测基线。恢复时先结束驾驶，再替换目标脚本并Reset scripts；源码回档不自动恢复用户设置JSON或游戏存档。
- 今后每次变更记录新增、删除、行为变化、离线检查及实机结果；失败版保留并明确标注，不能把离线通过当作实机通过。

## Git状态与后续约定

用户指定远端：https://github.com/moiian/Griffin-Journey-Redux 。本地仓库为D:\_Project\Griffin MOD\Repository，仅追踪两个Lua脚本及README、测试/版本说明和忽略规则。已有历史快照已导入；beta-v0.1.12-hip-verified标记用户确认的Hip基线。主分支与该验证标签已成功推送；镜头改动单独保存在experiment/camera-decoupling分支。

建议本地Git每完成一个独立改动就提交；重要改动前先留基线。实机通过时打里程碑标签，例如beta-v0.1.12-hip-verified。实验失败版本也可提交到实验分支，保留失败现象。每天收工或完成重要验证后推送GitHub。两者配合：本地提交提供即时回溯，远端推送提供异机备份。

源码、必要测试、变更记录与精简接口证据入库；大量原始日志、完整游戏转储、第三方参考MOD保留在本地资料目录。仓库使用显式允许列表，原项目备份、LOG、第三方资料不入库。后续实验在独立分支提交；本地变更及时提交，实机通过后再更新主分支与里程碑标签。


## Beta 0.1.15 实机通过（2026-10-11）
球面回中高度与恢复正常。用户舒适参数：4.019米半径、0.991米高度、50.276°左右、22.018°上下。主分支里程碑 beta-v0.1.15-neutral-height-verified。

## Beta 0.1.16：分档手柄控制（待实机）
RT直达3档、LT沿触发逐档减速；3档RB/LB为±69°球面导航；2档目标高度方向动作与回中前移；1档向目标微移/回中悬停。1/2档LB降落、RB原地悬停，并保持请求，回中再拨杆或切档恢复。A仅地面起飞，禁止空中调用原生双用途节点。保留实验工具动作接管，新的明确手柄操作再恢复调度。新增肩键滑条、中文档位显示、日志档位和肩键读数。保留生成、友方、跳过思考、防坠落、Hip显示与镜头路径；未修改阶段三工具。
首次分档升级采用截图上下角度22.018°，其余已有精调保留。离线回归通过，待用户确认游戏手感与动作衔接。


## Beta 0.1.16 实机通过（2026-10-11）
用户确认操作基本目标已实现，可作为后续打磨基线。分档按键、A仅起飞及RB/LB分档行为本轮验收。标签beta-v0.1.16-flight-controls-verified。镜头旋转跟随尚未实现；现有头部跟随仅负责位置。


## Beta 0.1.17：3档镜头水平跟随（待实机）
新增默认关闭的中文高亮开关及15—360度/秒跟随速度滑条，默认120。启用后使用原有狮鹫头部TargetJoint跟随位置；在原生手动镜头更新后，仅对当前驾驶玩家当前镜头控制器调用setYaw。单位由YawRange/YawRangeDeg核对，角度偏置由实际镜头到目标射线校准，追随身体水平朝向，短弧限速缓动。右摇杆输入暂停，松开0.8秒后恢复。仅3档生效，降档/实验工具接管/退出头部模式让出旋转；关闭开关保留头部位置跟随，结束驾驶恢复原跟随对象、距离和FOV。异常只停用自动转向，不停止驾驶。保留所有0.1.16动作和导航参数。新增日志事件和采样。离线回归通过，待实机方向、更新时机及手感验收。


## Beta 0.1.17 实机通过（2026-10-11）
用户确认3档水平镜头跟随效果很好；保留为下一轮输入触发、上下跟随及右摇杆叠加的基线。标签beta-v0.1.17-camera-yaw-verified。


## Beta 0.1.18：左摇杆触发的双轴镜头与右摇杆混合（待实机）
仅左摇杆死区外时旋转跟随，回中立即停；新增setPitch升降跟随，使用导航球面角相对回中角的变化，保留基础俯仰并夹紧原生范围。翻滚不变。小右摇杆输入在原生手动更新后读取实际增量并累加至跟随偏角，保留用户观察方向；自动补偿随右摇杆幅度平滑减弱，阈值以上停用自动跟随。默认径向阈值55%、恢复余量8%、恢复等待0.8秒，新增阈值和上下速度滑条（默认90度/秒）。水平速度保留120。仅按肩键、左摇杆回中时不触发镜头旋转；有左摇杆输入时肩键升降纳入俯仰目标。现有驾驶与友方/防坠落/Hip/头部位置镜头恢复不变。离线回归通过，实机待验收。


## Beta 0.1.18 实机反馈（2026-10-11）
上下镜头跟随不好用，用户要求删除，不标记该功能通过。用户报告LB/RB升降角度超过59°曾触发黑屏；“玩家过快坠落引起”仅为猜测，尚未确认引擎原因。

## Beta 0.1.19：用户菜单、热键和玩家座位预设（待实机）
移除所有自动俯仰写入及上下镜头滑条；保留左摇杆触发的水平镜头与右摇杆混合。肩键默认/最大59°，旧设置加载自动截断。用户菜单参考OJR布局，分一般、飞行、镜头、座位预设、按键、DEBUG；保护与旧导航参数在DEBUG；“切换目标到玩家”改为用户栏“让狮鹫听话”，删除其余目标测试按钮和废弃分层/无效镜头选项。默认仅Hip头顶，完整同步互斥可选；默认头部位置镜头。生成自动启用友方、跳过思考、防坠落和FSM冻结选项，开始驾驶时冻结FSM。新鲜日志显示自动SkipThink因DecisionModule mismatch关闭；本版保留所有归属检查，并在模块未就绪时0.25秒自动重试，错误日志限频，不再单次失败永久关闭。
新增独立直接HID输入与OJR式动作/手柄/键鼠绑定布局，不依赖或修改Hotkeys/OJR；捕获先释放再按新键、录入禁触发、恢复默认、清除与冲突提示；支持无手柄键盘驾驶，鼠标按钮可绑定。新增玩家座位预设保存/另存/重命名/切换/删除和重载，包含相机距离/FOV，保留未来pawn/同伴字段，当前不实现其座位。精调沿用原设置JSON，仅肩键强制截断到59°。离线回归通过，菜单观感、HID和新初始化重试需实机验收。


## Beta 0.1.20：2档前飞、菜单保持与头颈座位锚点（待实机）
2档前推改为阶段三同一FlightTarget单次节点；保持输入不连发，RB可手动中断为悬停，回中原前移惯性及其他方向保留，无自动一秒截断。旧代码在NickCore.isPaused时直接stop_driver并恢复位置；本版暂停只挂起位置/动作/骨骼/相机更新与采样，保留驾驶、FSM和待发动作，恢复时屏蔽菜单中按住的飞行/结束热键。正常失效、换玩家、读档时间上下文变化仍保留恢复检查。
用户进一步实测确认头部锚点能跟随头部摆动；站在脖子上不同步是部位不同。因此新增头部/颈部座位锚点与实际颈部骨骼列表，锚点随座位预设保存/切换，旧预设默认头部。仅位置跟随，沿用已验证Hip骨骼更新/恢复路径；导航球面和镜头仍跟头部。未找到颈部时提示并暂用头部。自动颈部默认按名称排序选第一个，不能宣称已确认颈根。偏移仍为身体水平轴/世界竖直，未新增骨骼旋转绑定。
Lua54编译和回归通过，包括暂停/恢复、菜单热键、延后动作、前推去重复、RB中断、头颈动画和预设锚点切换、缺骨骼回退及既有驾驶恢复。待用户实机；未标记验证里程碑。测试见BETA_0120_MENU_NECK_TEST.md。


## Beta 0.1.21：乘客座位、FSM与动态友方名单（待实机）
用户观察远距离后随从重新攻击，旧生成/驾驶时名单可能漏掉卸载重载后的新实例；本版每0.25秒刷新当前有效队伍，每1秒通过牛车MOD已验证的NPCUtil.isAccompanyPLParty(app.Character)识别同行NPC。友方仍仅生成狮鹫和当前成员的精确实例双向过滤，不作全局阵营或自动仇恨清除；该次重新敌对根因尚未证明。
新增随从与同行NPC独立Hip座位、头/颈部锚点、偏移和携带开关，按当前名单顺序分配并动态追加槽位。乘客真实Transform、上下文、碰撞体固定读取座位预设列表[1]的玩家位置，Hip显示使用当前预设的乘客位置，冻结各自FSM并捕获原状态。沿用玩家验证的UpdateJointExpression世界位置捕获/恢复顺序，未增加骨骼旋转绑定。
按用户补充，[1]仅DEBUG校正，排除正常下拉与全部轮询/热键；仅旧[1]时克隆生成[2]，旧坐标保留。正常预设保存/另存/切换同时携带玩家、pawns、companions及相机参数，已有未知字段保留。关闭座位、离队、停止/删除/Reset恢复原位置及原FSM；无效旧实例不做原生操作，新实例重新绑定；部分失败回滚，恢复失败保留恢复状态并阻止提前删除。成员缺接口只跳过该成员并提示。读NPC成员失败保留上次已确认对象，确认false才释放。
Lua54编译和既有回归通过，新增双随从/真同行与路人对照、物理与Hip分离、[1]排除/布局切换、新实例友方、NPC结束同行、部分冻结失败回滚/恢复失败重试、原false FSM和Reset恢复模拟。实机座位、NPC离队/恢复与远距友方待验收；见BETA_0121_PASSENGER_TEST.md。


## Beta 0.1.21 基本实机反馈（2026-10-11）
用户反馈“基本正常”，继续要求朝向/身体倾斜及乘客防坠落完善。只记录基本乘客流程可用，不宣称NPC离队与所有恢复边界已实机验收。

## Beta 0.1.22：角色Look At、身体倾斜与非逐帧跌落重置（待实机）
确认零座位偏移只是参考点在骨骼世界位置，现有Hip原姿态补偿保留。新增玩家及各乘客Look At X/Z（右/前为正、默认0/1、零向量回退前方），角色身体倾斜跟随开关及倾斜修正角，随正常预设保存/切换。参考OJR以up向量lookAt的实现，已核对本地via.Transform.lookAt(via.vec3,via.vec3)、get_Rotation及set_Rotation(via.Quaternion)转储。只跟狮鹫身体俯仰，不跟头颈骨骼旋转和侧滚，不新增镜头俯仰。座位偏移轴可随身体倾斜，修正角仅用于角色朝向不移动座位；DEBUG[1]旧偏移保持水平。行为更新/骨架更新前修正面向，结束/离队/Reset按归属恢复原旋转，接口错误隔离为本角色朝向功能停用。
用户补充不需要逐帧跌落重置；当前OJR乘客reset_fall仅落座/切换坐姿调用、司机另有单次搬移。Beta玩家与乘客改首次固定/切换预设/释放恢复时一次，DEBUG实体校正变化给乘客补一次。每帧保留位置/碰撞体同步，坠落死亡Hook从仅玩家扩展到精确接管乘客，未携带和释放角色放行。
Lua54编译及回归通过，新增面向四方向/零向量、爬升俯冲与up向量、倾斜位置轴、直立/修正角、原旋转恢复、乘客死亡请求范围、连续移动零重置、镜头俯仰零写入；原生视觉效果和取消逐帧重置后的稳定性待实机，见BETA_0122_FACING_TEST.md。


## Beta 0.1.23：DEBUG预设1、乘客保护与动作动画（待实机）

读取用户本轮0.1.22专属日志，确认多次Passenger unloaded、队伍名单缩减／重新绑定；日志只能证明卸载重现，尚不能证明坠落或自动传送是唯一原因。原坠落总计未分角色，本版新增player/pawns/companions分角色／座位的rider_protection计数、passenger_unloaded事件及乘客采样字段；Hook内不写文件，暂存后在普通帧输出。

核对OJR journey.lua：落座乘客有HitController.damageProc和updateDamage伤害拦截；异常状态免疫只保护牛，不能声称乘客也有。Beta补齐精确接管乘客的伤害免疫，DEBUG可关；不将玩家设为全局无敌。核对本地PawnManager转储后增加safeWarp两个Character重载、pawnLost(Character,bool,bool)、setPawnLostTimer(Character)的落座随从过滤，默认开启、DEBUG可对照；普通NPC、同行NPC及已释放乘客放行。不拦截CharacterID或全队生成／丢失接口。效果仍待实机验证，不宣称已阻止所有卸载路径。

DEBUG新增显示预设[1]开关，默认隐藏；开启可在正常座位列表手动选中调试预览，DEBUG实体坐标编辑实时更新预览。轮询与热键仍跳过[1]；隐藏时回到上次正常座位，保护[1]不被普通保存／删除／重命名覆盖。

玩家／随从／同行NPC座位新增动作节点名与播放按钮，空值不自动播放；正常预设保存与切换携带anim字段，首次落座和切换只请求一次。参考OJR暂时开启FSM、priority1动作请求、下一行为帧冻结，暂停保留、错误隔离、结束恢复原状态；原false FSM在动画开启窗口中离座也恢复false。无Motion ID／Bank ID／随机动画，不新增逐帧跌落重置，仅动作请求追加一次重置。

Lua54编译和既有回归通过；新增DEBUG[1]显示／手动选中／排除轮询／隐藏恢复、按接收对象伤害过滤、自动传送／丢失精确实例过滤及开关、动作请求FSM窗口／失败隔离／自动换预设／保存字段／离座撤销保护与原false FSM恢复。实际动画及随从刷新修复待用户实机。测试见BETA_0123_PASSENGER_ANIMATION_TEST.md。未修改阶段三、OJR、LMD、NickCore；已保留0.1.22基线。

## Beta 0.1.24：OJR式预设菜单、自动保存与实体/Hip契约（待实机）

修复旧版“运行时座位草稿已保存，但切换从旧预设恢复”的双份数据问题。菜单直接编辑权威预设；随从/同行NPC运行时列表引用当前正常预设，不再复制草稿。一次性迁移旧版当前草稿及相机设置，保留其他预设和未知字段；迁移后重载不再让旧镜像覆盖新预设。保存失败明确显示错误。

复刻OJR当前布局选择、新增克隆（最多15项）、删除确认/取消、直接改名及玩家→各乘客的菜单顺序；修改即保存，移除保存/另存/重命名等重复按钮。每布局玩家参数包含相机距离/FOV。动作名称仍直接保存，播放机制不变。切换按预设对象排队，暂停时保留到继续游戏再应用。

按用户澄清：所有已携带乘客Transform/位置上下文/碰撞体永久读取[1].player；手动选择[1]时全部乘客Hip也读取[1].player，选[2+]时Hip回到各自座位。玩家Transform继续由摇杆导航，只有Hip使用座位。保留Hip自然姿态偏移。[1]实体编辑可用±100米范围，读取已有有限坐标不裁剪；默认水平坐标轴。[1]默认隐藏、仅DEBUG开放手动选择，轮询排除，关闭显示/重载返回正常布局。

Lua54编译与回归通过，包括[1]实体/Hip同步可视调试、[2]独立Hip、玩家导航不变、直接编辑/切换/重载保存、旧镜像不覆盖新数据、磁盘保存失败提示、新增克隆和删除取消。原生效果需实机确认；不将模拟通过等同游戏安全。0.1.23和升级前设置已本地备份；未修改阶段三/OJR/LMD/NickCore。

## Beta 0.1.25：预设[1]逐乘客独立实体位置（待实机）

按用户最新要求取消共用[1].player。每位随从/同行NPC的Transform、上下文、碰撞体读取[1].pawns[i]或[1].companions[i]，与当前座位及摇杆输入独立。选[1]时Hip也读取各自[1]槽，选[2+]时仅Hip换座。玩家Transform仍由摇杆导航，所有预设的player只影响玩家Hip。

预设[1]开放与正常预设相同的逐角色参数树、携带开关、面向和动作编辑；坐标允许±100米调试，沿用自动保存和排除轮询。首次迁移physical_seat_revision=1将旧共用点复制到各自独立配置，以保持原实际实体位置；原[1]乘客字段此前未参与实体定位，正常预设数据保留。新槽独立初始化，已有坐标重载不被共用点覆盖。

Lua54编译和既有回归通过，新增双随从及同行NPC互不联动、[1]可视Hip调试、切回正常预设仍保留各实体位置、玩家参数与乘客实体独立、重载保留和[1]菜单可见性检查。实机待用户验收。0.1.24与升级前设置本地备份，未修改阶段三/OJR/LMD/NickCore。

## Beta 0.1.26：照片模式保持与切换座位（待实机）

对照OJR原生GuiManager.<IsDispPhotoModeAll>k__BackingField处理，确认Beta之前所有骨骼更新都被普通暂停条件跳过。新增照片模式显示例外：沿用已验证Hip捕获/写入/恢复管线，在UpdateJointExpression及PrepareRendering前更新玩家和已接管乘客座位。渲染前补写覆盖照片模式不执行行为/骨架更新的情况；先恢复自有偏移再重算，避免累积。

照片模式允许菜单预设切换立即应用，普通暂停继续排队；保留逐乘客预设1实体契约。照片模式只更新座位显示/角色朝向，不更新真实实体、碰撞体、FSM、飞行输入或AI，不覆盖照片相机。待发动画和动作留到恢复游戏。视觉失败在照片模式仅报告且保留驾驶绑定，不在渲染暂停内执行退出/传送清理。原玩家/狮鹫/乘客实例检查保留。

Lua54编译和回归通过，新增照片模式仅渲染仍应用玩家/乘客编辑、立即切换、连续渲染无累积偏移、实体/物理/动作/AI计数不变、NickCore暂停标记滞后仍停游戏输入、普通暂停排队及退出恢复。实机画面待验收。0.1.25及设置本地备份，不修改阶段三/OJR/LMD/NickCore。

## Beta 0.1.27：普通菜单及过渡帧Hip座位保持（待实机）

用户观察普通菜单瞬间Hip回到真实Transform、照片模式又拉回预设，造成斗篷拉扯。代码确认0.1.26视觉例外仅允许照片模式，普通菜单会跳过座位更新。本版让视觉座位保持跨越普通菜单与照片模式；每个驾驶渲染帧均通过同一Hip捕获/恢复路径补应用，覆盖暂停标记滞后的菜单过渡，不将真实实体同步到Hip。

真实Transform/位置上下文/碰撞体仍逐乘客固定预设[1]。暂停驾驶输入、AI、FSM和物理同步不变。普通菜单预设切换仍排队，照片模式立即应用。视觉操作继续核对当前玩家与返回狮鹫/乘客实例；暂停或渲染回调中视觉错误只报告，不在该回调内触发退出传送。

Lua54编译和既有回归通过，新增普通暂停骨架更新保持、跳过骨架更新的菜单渲染保持、暂停标记未变的过渡帧补写、反复重置模型后保持位置、实体/物理/动作/AI计数不变及照片-菜单-游戏恢复。没有模拟衣服物理，不能宣称斗篷已实机修复。0.1.26及设置本地备份，未修改阶段三/OJR/LMD/NickCore。

## Beta 0.1.28：扣血/丢失探针与当前位置释放

用户报告玩家/随从掉血死亡、随从集体消失重载及卡顿。最新0.1.27日志确认多次passenger_unloaded，单实例pawnLost计数曾达132298；旧计数表引用会更新历史记录，不能据此推算每个时刻的频率，更不能认定FPS根因。旧伤害规则只覆盖乘客，玩家保护缺失。

新增：玩家纳入精确接管实例伤害拦截；HitController.updateDamageHp更近端扣血拦截；damageProc跳过后明确bool false；pawnLost(InstanceInfo, DummyArg)按已捕获精确容器拦截。没有自动回血、强制复活或全局无敌。

自动只读探针：角色HP/死亡原因/坠落和盐水状态/真实位置；setHp、setHpValue、BrineProcessor.onKillCommon、PawnManager.onLostCheck及GenerateManager.requestDestroy的路径命中。Character和CharacterID的onLostCheck共享原生地址，前置只对比原始参数指针，绝不将未知参数强转Character。DEBUG两项实验拦截默认关：上游随从丢失检查、精确乘客容器销毁。容器不向父节点/共享区域扩张。计数在Hook中聚合，普通帧限频记录，历史表复制保存；减少高频日志开销。

删除：结束驾驶/退出座位/确认离队/Reset恢复时返回开始位置。改为保持当前实体Transform，同步上下文/碰撞体，单次跌落重置，恢复Hip/朝向/原FSM；失败继续保留恢复状态。

Lua54编译、原有回归与新增玩家/乘客/无关对象对照、底层HP路径、bool返回、替代丢失重载、原始指针对照、精确容器开关、盐水只读、不可变计数与HP日志、当前位置释放均通过。实机效果未验收；不宣称根治所有死亡/卸载/掉帧。0.1.27及升级前设置备份Beta/beta_0127；未修改阶段三、OJR、LMD、NickCore及用户设置JSON。实验分支experiment/oxcart-preset-ui，未新增实测里程碑标签。

## Beta 0.1.29：清理菜单、2档动作与释放诊断

用户0.1.28实测默认保护下仍有随从消失刷新；逐项开启两项额外拦截后没有明显消失，但仍见短暂解除/重绑，不能标记刷新BUG已解决。最新日志显示PawnCharacterList短暂变空，0.25—0.53秒后返回相同引用，期间脚本释放并重新绑定。NickCore.object.get_party直接读取原生PawnCharacterList，没有距离过滤；仅凭这些记录无法证明引擎未卸载/刷新或确定根因。最初提出的1秒名单等待补丁已在部署前撤下，保持原动态座位逻辑，不用等待掩盖刷新现象。

2档：回中改Ch253HoverWaitHoHomingHeight，前推HoverForward，后推HoverBackward；RB改HoverBackwardTargetHeight，LB降落不变，左右目标高度移动不变。3档/1档及阶段三工具兼容保留。

清理：移除重复DEBUG原镜头/头部镜头选项、无效Hip/偏移镜头路径及camera_x/y/z，保留用户镜头栏的唯一头部跟随开关；移除旧player_distance/player_height、sphere_navigation关闭分支与界面，统一球面导航。移除无法从当前界面调用的目标坐标60秒录制/单次坐标同步测试及未开放的单层导航分支；已不再使用的开始位置捕获移除。更新旧“本轮/新增/实验”界面文字，保护计数折叠到运行诊断。保留完整同步/仅Hip、已验证Hip恢复管线、所有有效预设/半径/高度/角度/FOV/距离/热键参数及当前位置释放。

自动诊断新增passenger_release_context：区分实例无效、座位关闭、原生名单缺失，释放前记录有效性、接口归属、HP、生成器状态与原引用是否变化。GenerateInfo.applyDestroy和Character.onDestroyCharacterByGenerator仅观察，不跳过销毁执行/通知；get_IsExecutedDestroy字段状态读数已核对本地转储。原有两项额外拦截仍默认关闭，不将用户观感当作根因确认。

Lua54编译及既有/新增回归通过，含2档前后/回中/RB、不重复请求、旧配置项剔除、唯一镜头控制、球面/相机/预设保留、名单缺失即时释放与有效状态日志、销毁入口只读、NPC离队/无效实例/当前位置恢复。0.1.28和升级前设置备份Beta/beta_0128。未修改阶段三/OJR/LMD/NickCore；不修改现有用户JSON内容，下一次脚本正常保存清理废弃顶层键。实机效果待验收，未新增已验证标签。


## Beta 0.1.30：跌落状态与丢失参数关联探针

连续实测确认：销毁拦截能阻止部分刷新，但开启时也曾集体刷新；名单缺失会释放有效乘客并撤去保护，是已确认空档，不是根因已确定。59降到49度未明显减少请求；实体目标同点后丢失请求仍集中槽1。此版本只新增诊断，不修正名单生命周期，避免同时改变待观察条件。

每0.5秒读取IsGround、SecFall、FallInfoHolder高度/最高与基准位置、Transform场景/Universal、位置上下文/碰撞体位置、LandingProcessor物体着地/保持标志和安全位置记录。字段/方法已核对本地转储；分组pcall隔离诊断错误，缺失项显示errors，不做强制着地或跌落累计写入。原生承载对象具体身份与调用栈尚未获取，不能宣称已经定位调用者。

高频请求按5秒汇总首次/末次游戏时间、行为帧、同帧命中峰值和当时健康/跌落快照。pawnLost InstanceInfo记录其Character与当前容器匹配角色是否一致、容器匹配列表、Canceled/Deleted/Failed，排查按容器归属导致计数集中槽1的可能。Native Hook中只更新内存，不逐次保存；驾驶中的普通事件并入2秒定时保存，退出/Reset及分卷仍写盘。

Lua54编译及既有/新增回归通过：只读原始读数、无跌落重置、错误隔离、参数角色与容器匹配角色不一致对照、同帧80次请求计数、Hook零写盘、批量释放事件零同步全量写盘、定时保存后释放记录可读。原生运行待验证，未打验收标签。升级前0.1.29和Settings备份Beta/beta_0129；不修改用户JSON、阶段三/OJR/LMD/NickCore。


## Beta 0.1.31：持续跌落重置与强制着地查询对照

按用户要求新增两个互相独立、默认关闭、不持久化的高亮DEBUG开关。实验1在已落座玩家/随从/同行NPC实体与碰撞体锚定完成后持续重置FallInfoHolder基准和高度并清零Character.SecFall；错误按角色隔离且只记一次，关闭/重新开启可重试。解除控制后停止，原普通单次重置流程保持。

转储确认app.Character.get_IsGround返回Boolean且无set_IsGround/独立IsGround字段。实验2仅覆盖精确已控制角色该查询的返回值为true，保留原始结果/时间，不改碰撞体着地接触、不重写安全点、不自动清计时；不影响狮鹫、未落座和无效角色。原生内联或直接读取底层状态不一定经过查询，所以不宣称已实现完整物理着地。

新增模式事件与physics实验状态/重置次数/失败/原始着地遥测。编译与原有29组左右回归通过，覆盖独立UI开关、玩家/随从/同行NPC重置、关闭放行、原始结果保留、无关/无效/离座角色排除、写入失败不终止驾驶。模拟不代表原生安全或根因已修复。0.1.30及Settings备份Beta/beta_0130；保留用户参数、阶段三、OJR/LMD/NickCore，未新增验收标签。


## Beta 0.1.32：短时逐帧闪现与狮鹫抽动探针

用户长测未出现严重消失刷新，但看到随从/血条瞬间闪现，同时狮鹫飞行抽动。现有0.5秒采样无法定位一两帧变化，本版只增加默认关闭的高亮短时诊断，不修改驾驶/骨架/保护/预设逻辑。

同一回调周期对照行为锚定前后、骨架原生更新与座位重写前后、渲染阶段前后。只读当前玩家、已落座乘客和精确返回狮鹫实例的场景/Universal、碰撞体、位置上下文及Hip。狮鹫同时记录飞行目标、动作/档位/输入及渲染末期跟随镜头目标，缺失接口/读错保留在记录中。

缓存最近6帧，异常仅保存前6帧与含触发帧在内后6帧；最多6个窗口、60秒墙钟或3600渲染回调帧，阶段每帧最多8条。上下文/实体跳变与修正后Hip差触发，正常骨架恢复中间态不按Hip差触发；狮鹫加速度为候选而非根因确认。阶段回调无磁盘I/O，普通帧归入原日志；退出/Reset保留未完整窗口并释放对象引用。

Lua54编译和完整旧/新增回归通过：UI启动、受控玩家/乘客/狮鹫范围、上下文短跳和狮鹫世界跳变捕获、异常前后缓存、零位置/骨骼写入、阶段零写盘、墙钟/帧数/窗口上限、手动停止/排空。实机效果待验证，不标记已修复。升级前0.1.31与用户设置备份Beta/beta_0131，用户参数和阶段三/OJR/LMD/NickCore未修改。


## Beta 0.1.33：俯冲后抽动记录覆盖修正

用户确认抽动从俯冲后开始，爬升正常。0.1.32记录44.016至47.159游戏秒、约4秒墙钟即用满6窗：狮鹫上下文固定不动，持续距离差反复触发，夹杂21个加速度候选。片段内狮鹫碰撞体与场景实体位置一致、修正后Hip误差最大约0.000025米；场景坐标原点切换不能当作Universal位置跳变。没有充分记录持续抽动阶段，不推定根因或已修复。

本版只修正诊断：上下文/碰撞体/Hip差异按角色和阶段出现边沿触发，消失后可再次触发；加速度仅作数据。6个异常窗与6次定时采样独立额度，约5/15/25/35/45/55游戏秒取样，总计最多12窗，不因异常额度用尽提前退出。60秒墙钟不变，周期上限18000以适配高刷新率；前后缓存和每周期阶段上限不变，不改变实体/Hip/飞行/保护/设置。

Lua54编译及30组完整回归通过，新增持续差异不耗尽、恢复后再现重新触发、异常额度用尽仍能定时取样及定时上限检查。阶段无写盘、无位置修改、停止排空与原有驾驶回归通过。实机待验收，未标记根因已修复。旧0.1.32及升级前设置备份Beta/beta_0132。


## Beta 0.1.34：视频复核与连续姿态探针

用户确认悬停后重新冲刺不能消除抽动。已逐帧检查用户24.5秒、60FPS录像，约2.65至2.70秒身体/翼腿姿态快速变化，开头已处于此前俯冲后的抽动状态；背景不呈同幅变化。不能将现象仅归为实体大幅瞬移或镜头整体抖动，也不能仅凭视频断言动画/旋转/碰撞中的具体根因。旧探针缺少身体/骨架旋转与真实相机Transform，未触发15米阈值不排除抽动。

沿用原按钮，新增连续渲染末期frame_probe_motion，每120条普通帧归入日志，最多7200条；不依赖异常阈值。记录精确返回狮鹫身体四元数、头部相对偏移、最多8个匹配Root/Hip/Spine/Chest/Wing骨骼位置/旋转，以及主相机Transform的位置/旋转、导航输入等。Joint.get_Rotation和MainCameraController._Transform已核对本地转储。骨骼名称及接口缺失记错，单部件失败隔离；停止排空尾批并释放引用。不改运行行为或用户参数。

Lua54编译与30组完整回归通过，包括连续帧不依赖窗口、7200条边界、120条分批/停止尾批、镜头读取成功/失败、骨骼失效隔离、四元数/位置数值副本、阶段无写盘和原驾驶回归。原生开销/抽动根因待实机；0.1.33及设置备份Beta/beta_0133。视频复核见Beta/BETA_0134_VIDEO_REVIEW.md，测试见Beta/BETA_0134_POSE_PROBE_TEST.md。


## Beta 0.1.35：独立狮鹫跌落重置对照

用户提出狮鹫自身也可能触发跌落保护。此前实验1/2及跌落读数只作用于落座玩家/乘客，未涵盖狮鹫。Character的FallInfoHolder、SecFall及resetBaseHeight/resetFallHeight已核对转储，新增仅当前驾驶精确狮鹫的独立默认关闭DEBUG实验3，每行为帧重置基准/跌落高度和SecFall；不强制IsGround、不联动乘客/AI/动作/物理位置，不改用户JSON。暂停/结束/无效或接口变化停止，失败停用当前实例，关开重试。

每0.5秒读取狮鹫SecFall/FallInfo/原生着地与飞行/LandingProcessor/安全位置及物理坐标，保存重置前后快照并在DEBUG显示简短读数；切换时强制下一帧采样。缺字段分组记错。详细骨骼姿态改为可选默认关闭，连续记录默认保留狮鹫Transform和相机位置/旋转；最近跌落快照也关联至motion，不声称每渲染帧都重新采样所有跌落字段。

Lua54编译及31组完整回归通过，包括原始累计只读、独立UI开关、前后快照、精确角色及不作用乘客/强制着地、暂停/关闭/旧归属/错误隔离与重试、实验不持久化、默认不读详细骨骼。实机根因与重置效果未验证；旧0.1.34及设置备份Beta/beta_0134，阶段三/OJR/LMD/NickCore不变。测试见Beta/BETA_0135_GRIFFIN_FALL_TEST.md。

## 阶段三 0.3.18：动画隔离实验（2026-10-12）

用户最新观察：冲刺在起飞/水平飞行已累积抽动，俯冲与跌落不是必要触发条件，切换动作不能清除。只改实验工具，Beta仍0.1.35。新增高亮中文捕获/隔离重播/恢复按钮：读取当前实例已加载各层动画bank/ID，保存并关闭动作FSM和根位移，仅拦截该FlightControl.update/lateUpdate/eventFlightUpdate。直接TreeLayer.changeMotion重播，不猜编号、不请求导航动作、不锁Transform，不加入代码位移。是否完全无位移及是否抽动待实机；残余物理/动画表达式未保证被屏蔽。

精确同实例，Beta/四档驾驶须先结束；开始驾驶、对象失效/变更及Reset退出隔离，恢复原RootMotion和FSM，恢复失败保留重试。direct_motion日志5Hz、2秒写盘、3000条上限。取消手动动作3秒间隔，保留自动驾驶0.35秒节流。补充旧实测中WrapAroundEnd、ThreatAir、WingWindAttackStartLoop/End按钮，均为完整动作，不冒称新滑翔动画。Lua54编译及隔离、阶段三驾驶、桥接、日志/选择回归通过，原生效果待验收。0.3.17备份stage3_0317；配置、NickCore/OJR/LMD不变。详见STAGE3_DIRECT_MOTION_0318.md。
## 阶段三0.3.19：保留原生调度的位移隔离＋扑翼只读探针（2026-10-12）

用户确认0.3.18隔离播放可无位移，只有滑翔且头部仍追踪玩家。最新7次冲刺捕获均为层0 Bank1/Motion0、层5 Bank0/Motion5197、层9 Bank100/Motion0，顶层编号不足以区分挥翅；不继续要求用户卡时机。新增20秒墙钟/20Hz只读探针，normal/raw内部节点名称/资源编号/权重/帧/Active/Empty和扑翼/混合变量、根模式/Universal位置/位移拦截状态自动写独立MotionProbe日志。渲染零写盘、普通帧2秒保存，最多420样本/16层/每集合12节点/每样本64节点；截断明确，字段失败本轮隔离，不影响驾驶。菜单显示实际捕获编号。

按用户新思路新增独立默认关闭“仅隔离原生位移”：只拦截精确FlightControl.updatePosition并关闭Motion根位移，保留动作FSM、飞控更新/扑翼/目标/朝向，不写Transform、不加代码移动。与完整动画隔离互斥，关闭/结束Beta驾驶/失效/Reset恢复原根模式；原生残余位移或内联路径尚待实测，不宣称已覆盖。Lua54编译、新增两实验及完整阶段三驾驶/桥接/旧动画隔离/日志选择回归通过，原生效果待验收。Beta仍0.1.35，用户配置和其他MOD未改，旧0.3.18备份stage3_0318。详见STAGE3_NATIVE_MOVEMENT_0319.md。
## 阶段三0.3.20：位移隔离失败，确认滑翔/挥翅子资源（2026-10-12）

0.3.19实测会话141455Z：updatePosition拦截确实命中，RootMotion=0但仍移动，第4轮18.4秒140→1233次拦截、位置明显改变，原生位移未完全隔离。Beta在28.087、119.004、124.617秒因Griffin is too vertical退出，工具随后才恢复位移；黑屏调用链未捕获，不能宣称已确证黑屏根因。保留Beta检查，本版未改Beta。

扑翼探针确认基础层内部Bank0/Motion5100 ch53_000_com_flight_loop与5101 ch53_000_com_flight_loop_flapping，两者在原生冲刺中权重切换；顶层Bank1/Motion0不变。层5 5197为add_wing_flightshake、层9 100/0为面部中立；名字不证明抽动根因。三个Variable字段本轮不存在，不当作零值。

新增已确认5100滑翔/5101挥翅无位移按钮，先验证当前精确实例资源已加载，再替换基础层并沿用完整隔离，不猜ID、不写Transform、不运行冲刺导航；其他附加层保留，尚未排除附加动画影响。失败位移实验移至折叠DEBUG并禁止驾驶/玩家固定期间开启，开始驾驶即归还位移。Lua54编译、资源加载/驾驶禁用/恢复及原隔离、只读探针、完整驾驶/桥接模拟通过，原生视觉待验收。Beta仍0.1.35、配置不改，旧版备份stage3_0319。详见STAGE3_0320_RESULTS_AND_CLIPS.md。

## 阶段三0.3.21：代码水平飞行＋玩家随行（2026-10-12）

用户确认0.3.20的滑翔5100与挥翅5101隔离播放符合预期。新增独立中文高亮代码飞行：先播放5100，再开始，默认8米/秒、相对起点高8米；左摇杆左右转与左右15度按钮，速度/转向速度/高度可调。玩家前上方随行，前后/高度和镜头距离/FOV可调，冻结玩家FSM并自动精确防坠落。暂停前进仍随行；结束在当前位置恢复FSM和镜头、归还狮鹫原生控制，不传回起点。无60秒运行上限，样本各最多3000条后不再新增但继续控制。

只控制保留的精确狮鹫/玩家，UpdateBehavior后同步Transform、位置旋转上下文与碰撞体warp；不运行原生导航，不加入惯性/俯仰/避障/动画混合。失效上下文停止，恢复失败可重试；防坠落仅绑定且已移动的玩家。新增code_flight样本自动随会话JSON保存。Lua54语法、新增3组代码飞行、原隔离/资源及16组阶段三驾驶回归、只读扑翼与失败位移隔离测试通过；均为离线模拟，原生稳定性/性能/抽动待验收。Beta仍0.1.35、用户配置及NickCore/OJR/LMD不改；旧0.3.20备份stage3_0320。测试见STAGE3_CODE_FLIGHT_0321.md。

## 阶段三0.3.22：补充代码飞行位姿隔离（2026-10-12）

0.3.21用户实测转向后反向/翻转和远处回跳。153736Z会话最后一轮代码写入后误差最大约0.000004米，但其他回调读取的Transform与最近代码样本偏离最大约158.90米，旋转X/Z重新非零；根Transform亦被覆盖，并非只证明模型分离。两采样非同一时刻，不能据此断定唯一原因或实际模型偏移量。

只在代码飞行活动/恢复期，按精确FlightControl/Character指针补拦截eventBeforeColliderAdjust(via.GameObject)、eventAfterColliderAdjust(via.GameObject, via.motion.ExpressionUpdate)、onRootApply(via.vec3, via.Quaternion)，均核对本地转储。结束后通过，普通无位移播放与其他对象不受此新增拦截。菜单仅增加三条计数；会话日志增加写入前/后/渲染位姿、位置上下文/碰撞体、当前RootMotion和计数；渲染零位置写入/零写盘。没有改整个Character.update或普遍禁用物理。

Lua54编译、新增4组精确位姿/恢复/三阶段回归、原动画2组、只读扑翼与失败位移各1组、既有驾驶16组通过，均为离线模拟；原生修复效果待验收。操作仍先5100再开始代码飞行＋随行，连续多次左右转观察。Beta0.1.35、用户设置与NickCore/OJR/LMD不改，旧0.3.21备份stage3_0321；详见STAGE3_POSE_ISOLATION_0322.md。原始日志与证据摘要不入Git。

## 阶段三0.3.23：复用ManualPlayer目标修复作同轮对照（2026-10-13）

0.3.22直飞无输入仍翻转朝初始位置。160611Z日志两条碰撞回调各5900次、角色根应用0次，RootMotion持续0；471样本中渲染上下文与代码完全一致，但Transform偏移最大233.21米。说明原拦截未解决，旧记录缺少目标数据，不能证明导航是唯一源。

核对Beta旧修复select_player_target/ManualPlayer/setTarget，新增阶段三代码飞行专用“让狮鹫听话：重新锁定当前玩家（一次对照）”。可在同一飞行回飞时点击，不结束/不重播动作/不重新生成；开始飞行不自动调用以保留A/B。精确TargetController/FlightControl归属与预写日志检查，过期排队取消。code_flight样本增加玩家/目标类型/角色比较/飞控及目标场景坐标、切换次数；切换前后独立事件自动保存。只读探针错误不终止飞行。

Lua54编译、新增目标A/B及原代码飞行/位姿共5组、既有驾驶16组、动画资源2组通过；离线不能证明原生效果。旧0.3.22备份stage3_0322；Beta0.1.35、配置和其他MOD不改。测试见STAGE3_TARGET_AB_0323.md；日志证据摘要仅本地。

## 2026-10-13 独立动画实验室0.1.0（新路线，实机待验收）
用户要求停止扩充臃肿工具，今后测试功能默认关闭、勾选启用、模块化。新增CleanAnimationLab入口及lab/isolation/recorder模块，绑定Beta精确实例；旧0.3.23及Beta0.1.35未修改。仅测试Bank0/5100、5101，切换基础层保持隔离，取消开关才恢复原FSM/根位移；无3秒冷却、无自动驾驶/搬移/生成。记录默认关闭，最多3000样本，不因采样上限停止播放。旧菜单active时拒绝capture，要求stop恢复原生后重启，是已确认交互问题；首次隔离后位移仍未确认修复。
Lua54四文件语法及默认零写入/零Hook/零日志、精确Hook正反对照、直接切片只改动画、原状态恢复、过期排队取消、Reset模拟通过。原生效果待验收，不打verified标签。交接见NEW_SESSION_HANDOFF.md；使用步骤见CleanAnimationLab/README.md。

## 2026-10-13 CleanAnimationLab 0.1.1（只读探针，首次位移未修复）
用户确认首次隔离仍位移，重复启停无效；只有某次关闭后实际落地，再开启才有效，落地不稳定。旧0.1.0没有记录隔离关闭时段，无法比较该状态变化。

最新170907Z日志三个隔离段，在约1.041/1.025/0.400秒内的首末样本位移分别约4.661/4.693/1.793米；各样本RootMotion=0、FSM=false，拦截数持续增加。它们是采样区间位移，不是每轮完整距离。该日志没有成功落地后的对照，不能推定唯一根因。

本版新增state_probe.lua，记录默认关闭。记录开启后对已绑定精确实例连续只读，包括隔离关闭时；应用及Reset前后保存快照，隔离轮号只在首次接管递增，5100/5101切换保留轮号。原隔离措施保持，无新的位移／落地／速度写入。补充暂停排队到执行之间的检查，暂停期间不执行启停。

已通过Lua54五文件语法检查，以及原生命周期回归与新增状态探针回归：默认关闭不写日志／不安装Hook、精确Hook正反对照、切动画不恢复FSM/root、原状态恢复、过期队列与Reset；隔离前后／原生落地连续记录、数值快照、字段失败隔离、错误飞控归属拒读、暂停到执行间检查、关闭／满额不再采样、满额不结束动画、恢复失败保留并重试。

最高20Hz、3000样本，正常帧每两秒保存；原生性能和字段读取尚待实机。只读行为队列快照不是GPU最终画面，也不能定位所有原生写入调用者。未修复／未确认首次位移根因，不打verified标签。

按README的五步进行一次“原生2秒→隔离3秒→关闭约10秒→若落地则再隔离”的对照即可。若没有落地，保留失败日志，不需要继续重复开关。

## 2026-10-13 CleanAnimationLab 0.1.2（只读方法定位，已部署待实测）
新增独立默认关闭的call_trace模块，精确角色所拥有动作管理／地形调整／姿态写回／上下文回滚五入口，只读前后坐标、动作、FSM/root及基础层实际资源／帧，保持原调用和返回值。状态记录增加实际基础层读数；切跟踪不重播动画。每入口20Hz／1000采样对，变化对和每秒稳定心跳保存；Hook无写盘、暂停／过期／实例模块变化／Reset拒读或丢弃，满额不结束动画。六Lua语法和既有／新增模拟通过，源码已部署；原生效果与首次位移仍待实机。无位置／落地／速度写入，Beta和旧阶段三不改。使用见CleanAnimationLab/README.md及TEST_012_CALL_TRACE.md。

## 2026-10-13 CleanAnimationLab 0.1.3（单次原生任务重置实验，默认关闭）
新增task_reset职责模块，显式开启且状态记录打开时，每轮首次接管前以真实构造的选项对象请求Wait／ResetAI一次，切片不重复。保存原FSM/root、准备期放行飞控、前后留快照，返回后再执行隔离；失败／暂停／过期／归属变化拒绝或恢复，无坐标／速度写入。七文件Lua54语法及新旧模拟通过，已部署备份，原生残留任务是否结束及首次位移修复待实机。Beta与旧阶段三不改。说明见CleanAnimationLab/TEST_013_TASK_RESET.md。

## CleanAnimationLab 0.1.4：悬停指令刷新实验（2026-10-13）

同步原生重置后立即冻结未解决首次隔离位移，本版撤下task_reset，新增默认关闭action_refresh，仍为七个Lua文件。按隔离→精确ActionManager请求HoverWait→恢复首次捕获的FSM/root并放行飞控→至少一次实际UpdateBehavior→观察HoverWait与已替换隔离资源的原生基础层→重新隔离的顺序执行。保留原始控制值和同一隔离轮；每轮一次、切片不重发。请求返回或动作名变化不能单独证明原生已进入。

需状态记录，3秒有效行为时间未确认则退出并恢复、不自动重试；暂停、取消、Reset、旧队列、记录关闭、实例／模块／驾驶归属变化拒绝迟到冻结。放行阶段mode=refreshing，阶段快照含计数与行为序号；轮询不逐帧写事件。没有新增位置／碰撞体／速度／AI／着地写入，也不撤销已提交的新原生动作。Beta0.1.35、旧阶段三0.3.23和用户JSON保持。

Lua54七文件语法、既有回归及新增异步时序、原生资源确认、延迟动作、切片、原值恢复、暂停／取消／Reset／超时／异常、精确实例／模块／驾驶／记录与原false FSM拒绝模拟通过。已部署，实机效果待验收，不打verified标签。测试见CleanAnimationLab/README.md与TEST_014_ACTION_REFRESH.md。仓库白名单替换模块并添加测试说明；日志、实测分析、设置、转储、备份和本地回归工具不入Git。

## CleanAnimationLab 0.1.5：分帧请求与原生稳定观察（2026-10-13）

修正0.1.4把隔离／请求／放行放在同一回调、随后读到瞬态HoverWait就复隔离的时序问题。action_refresh改为隔离后至少一次实际UpdateBehavior才请求，继续保持隔离两个行为更新后放行；不以持续HoverWait为必要条件。放行后实际基础层离开5100／5101，同一动作／资源及整个1厘米位置窗口稳定至少0.3秒／3次行为观察，才播放当前选择并复隔离。允许原生自然转为跌落／落地／Wait，无强制落地或位置／速度／AI写入。这个有限窗口不是旧任务清空证明，实机效果待验收。

5秒有效行为时间未稳定退出，不自动重试；保留原暂停／取消／Reset／过期队列／记录／精确实例／组件／驾驶／原false FSM保护，原控制值和隔离轮保留。阶段记录增加stage、稳定时间与实际动作，UI改为复隔离计数，不再把首次瞬态动作称为成功确认。默认关闭、不写设置，Beta0.1.35和旧阶段三0.3.23不改。

七Lua54及既有／新增分步顺序、瞬态悬停转落地、累计慢漂移／资源变化、无悬停也可稳定、切片、原值恢复、各阶段取消、暂停／Reset／异常／超时及实例归属回归通过。已部署待实机；TEST_015_REFRESH_SEQUENCE及README给出一次新实例测试，不重复原失败流程。不打verified标签；源码与通用说明按白名单同步，日志、实测分析、设置、转储、备份和本地回归不上传。

## CleanAnimationLab 0.1.6：控制与基础层换片分步对照（2026-10-13）

新增默认关闭isolation_ab模块及勾选开关。仅从原生空中HoverWait、原FSM=true且实际基础层非隔离资源开始：A捕获原值并冻结FSM／RootMotion及精确本实例FlightControl，所有层零changeMotion；用户显式进入B才在同一轮、同一控制快照下仅基础层播放5100一次。B不重播附加层、不重新冻结／放行、不请求原生动作。普通隔离的附加层重播及0.1.5刷新保留。A/B不与悬停刷新同时开始，需状态记录；选项变化只影响下一轮，本轮挥翅不换片，B不能退回A。

记录增加A/B阶段与四个边界事件，周期及方法前后快照保留同轮关联。关记录、取消／解绑／Reset、过期队列、实例／组件／驾驶变化拒绝迟到B并按原值恢复，暂停挂起，恢复失败保留重试。没有增加位置／碰撞体／速度／AI／着地写入。Lua54八文件、既有状态／调用跟踪／0.1.5刷新及新增零重播／单次基础层／同轮同快照／开关／暂停／取消／归属／失败恢复回归通过。已部署，原生效果待验收，首次位移未确认修复，不打verified标签。

本轮按CleanAnimationLab/TEST_016_ISOLATION_AB.md：隔离关闭时用已有单次按钮准备HoverWait并飞行true，开状态与方法记录；关闭刷新，勾选A/B再开启隔离。A观察约2秒，已跌落直接保存；否则同一隔离内进入B观察约2秒，关闭隔离后记录约2秒保存。不要在A/B间发动作或关闭隔离，不需要等落地后重试。八Lua及通用说明按精确白名单提交；日志、实测报告、设置、转储、备份和本地回归不上传。Beta0.1.35、旧阶段三0.3.23和其他MOD不改。


## Beta0.1.36：原路线导航锚点与玩家抖动探针（2026-10-13）

用户观察玩家在狮鹫前方持续小抖，并周期大闪现，与狮鹫抽动同步；尚未确认因果方向。新增独立默认关闭／不持久化的稳定导航中心与只读位置探针，模块为_GriffinRouteProbe/anchor、probe、route。稳定中心首次捕获头部对根的偏移，以根位置和身体水平朝向重建，只排除后续头部骨骼摆动，不改座位／镜头、AI或原生飞行动作。退出驾驶关闭两个开关。

探针按行为写入前／Transform写后／上下文与碰撞体同步后／原生行为前后／骨架与座位／渲染阶段排序，记录玩家实体／上下文／主控制器／Root／Hip、计划目标、狮鹫根与头、实际追踪目标及动作输入。Universal对照排除原点切换误判；每阶段读、20Hz常规存帧，最多8个前5后6异常窗，60秒墙钟／12000帧／200000读数／32阶段／240待存帧边界；普通帧批量写独立GriffinRouteProbe日志。无新sdk.hook或原生写入；读错字段组隔离、归属变化停采、写盘失败限频重试。

Lua54四文件、新模块、实际Beta接入和完整既有回归通过，实机效果／性能待验收，未认定修复。游戏与项目Beta更新0.1.36，保留游戏已允许的130米菜单并同步设置读取上限；用户JSON未改。旧Beta／设置备份于Beta/beta_0135_original_route_时间目录。旧阶段三、CleanAnimationLab、NickCore／OJR／LMD不改。此条为本原路线会话现状，另一会话旧文所称Beta0.1.35是历史状态；共享文件修改前复核。仓库精确白名单增加上述3模块与BETA_0136_ORIGINAL_ROUTE_TEST.md，日志／设置／备份／本地回归不上传。

## CleanAnimationLab 0.1.7：精确动作更新隔离对照（2026-10-13）

新增默认关闭action_gate模块及“隔离时暂停原生动作更新（仅A/B，下次开启生效）”。在既有A/B中只额外暂停精确当前ActionManager.update，从A捕获控制后持续到B；无动作请求或位置／碰撞体／速度／AI／着地写入。当前转储确认零参数、实例System.Void，启用再次核对签名。只作用于当前返回实例与原管理器／FSM／Motion，其他角色放行。普通隔离及悬停刷新拒绝混用，选项本轮内修改只影响下一次A。

记录动作更新拦截次数、启用状态和错误，方法边界带本轮计数；被拦截调用的只读前后快照不代表原更新实际执行。暂停放行原动作更新并挂起步骤；取消／解绑／Reset、记录关闭、实例／组件／驾驶变化停止拦截，Hook异常放行并结束实验，恢复失败也先撤下拦截再保留原控制恢复状态。九Lua54及既有状态／调用跟踪／刷新／A/B和新增精确正反例、签名／原返回、开关／暂停／过期／归属／异常／恢复回归通过，源码／游戏／仓库Lua内容一致。已部署待实机，首次位移未确认修复，不打verified标签。

本轮按CleanAnimationLab/TEST_017_ACTION_GATE.md做一轮：隔离关闭时准备原生HoverWait与飞行true，开状态／方法记录；关闭悬停刷新，同时勾选A/B和新增动作更新隔离。A约2秒检查实际动作与拦截次数；同一隔离内进入B约3秒，区分入口跳变与持续移动；关闭后记录约2秒保存。无需重复无拦截的旧对照。Beta0.1.35、旧阶段三0.3.23及用户JSON不改；仅九Lua及通用说明按精确白名单提交，日志／实测报告／设置／转储／备份／本地回归不上传。


## Beta0.1.37：原路线玩家状态与目标探针修正（2026-10-13）

移除TargetController／FlightControl不存在的get_Valid调用，保留精确Owner／Character归属。独立记录玩家实际动作名、着地结果／已有原生结果时间，以及请求冻结与实际FSM。动作管理器核对当前玩家GameObject和FSM；字段组失败不影响实体／上下文／碰撞体等其他组。两开关默认关闭、不写Settings，无新的原生写入或Hook，不改变锚点／动作／物理／AI／FSM控制。

Lua54四文件、新模块及实际Beta接入与完整既有回归通过；新增字段原生效果待验证，尚未修复抽动。入口与3模块配套部署，测试见BETA_0137_PROBE_FIX.md。仓库精确白名单只增加通用说明，原日志／实测报告／设置／备份／本地测试工具不入Git。另一会话CleanAnimationLab和旧阶段三不改。


## CleanAnimationLab 0.1.8：根应用与飞控碰撞回调只读定位（2026-10-13）

新增默认关闭pose_trace，观察精确返回实例的FlightControl.updatePosition、碰撞调整前／后回调及Character.onRootApply四入口；启用核对实例方法、参数数量、System.Void和归属，全部放行原调用及返回值。复用可配置只读配对器，旧call_trace接口及数据保持独立。每入口20Hz／1000对、总4000，变化与稳定心跳保留、Hook内不写盘，暂停／取消／记录关闭／过期队列／实例或组件变化拒读或丢弃；部分入口失败独立报告。状态／事件另记用户当前隔离开关及修订号，区分关闭后的异步恢复窗口。

控制流程保持0.1.7，没有新增动作请求、拦截或位置／速度／着地写入。十Lua54编译、原状态／调用／刷新／A/B／动作更新隔离与新四入口精确正反例、原返回、嵌套与数字历史、独立开关／数据、签名与部分失败、暂停／过期／Reset、限频／心跳／容量和阶段关联回归通过。已部署，原生命中及首次位移根因仍待实机，不打verified标签。

按CleanAnimationLab/TEST_018_POSE_TRACE.md只做一次短记录：开状态、旧方法和新增位置入口跟踪；隔离关闭时准备原生HoverWait／飞行true；关闭刷新，勾选A/B及动作更新隔离，A约2秒、同一隔离内B约3秒，关闭后约2秒保存。画面继续位移也可定位，无需反复开关或等落地。当前Beta、原路线探针、旧阶段三及用户JSON保持；只同步十Lua及通用说明，日志／实测分析／设置／转储／备份／本地回归不上传。


## Beta0.1.38：玩家原生落体与物理接触只读探针（2026-10-13）

现有默认关闭原路线探针增加独立fall模块，仅行为写入前／原生行为后／渲染前读取精确当前玩家FreeFallController字段、IsDisableGravityUntilMotionEnd及MainCharacterController的Ground／NumGroundContactPoints／GravityDirection。接口已核对当前转储，保留原生单位；字段按组隔离，无对象记available=false，向量数值复制。不新增Hook／原生写入或设置项，不改变玩家／乘客／狮鹫行为。

Lua54五文件、新增只读状态／复制／缺对象／错误隔离及既有模块与完整Beta接入回归通过，原生读数待实测，尚未修复抽动。入口与四模块配套部署；复用原60秒探针做一次冲刺→悬停状态读取，不重复着地覆盖或锚点对照。见BETA_0138_NATIVE_FALL_PROBE.md。白名单仅新增fall.lua与通用说明，用户JSON／实测分析／日志／转储／备份／测试工具保持本地；其他会话与MOD不改。


## Beta0.1.39：停止当前玩家原生自由落体单变量实验（2026-10-13）

新增独立fall_stop模块与默认关闭／不持久化开关，需保持原路线探针，拒绝旧实验1／2／3混用。仅精确当前驾驶玩家同步后，对其当前且激活的FreeFallController调用stop()并读回false；当前转储及启用时核对实例零参System.Void。暂停不调用；控制器更换拒写旧引用，驾驶／玩家／归属／记录变化、异常或退出停用。不处理乘客／狮鹫，不新增Hook、位置setter／着地／AI／FSM／共享重力写入。停用停止后续调用，不重建已取消的旧落体轨迹。

探针记录启用／尝试／成功／错误次数和最近前后状态，成功后增加player_free_fall_stop_after与落体读数。Lua54六文件、新模块门限／归属／替换／读回／暂停／错误／退出、实际Beta同步后接入和快照／探针关闭停用／设置隔离及完整既有回归通过。已部署，原生效果仍待实测，尚未认定修复；测试见BETA_0139_PLAYER_FALL_STOP_TEST.md。源码／通用说明按白名单同步实验分支，用户JSON／日志／分析／转储／备份／本地测试工具不入Git，其他会话及MOD保持。


## CleanAnimationLab 0.1.9：普通隔离允许Beta驾驶中使用（2026-10-13）

移除普通隔离的Beta驾驶拒绝，以及持续校验中的驾驶自动解绑。绑定／开启／5100与5101切换／关闭均可在驾驶中执行；不主动结束或暂停Beta驾驶，不改变其导航、座位、镜头或动作请求。只作用当前精确返回实例，默认关闭、按本轮捕获值恢复FSM／RootMotion，无新位置／物理／AI写入。

A/B及自动刷新保留非驾驶前置，开始前拒绝、已运行时归属改变按原恢复；普通隔离内更改下轮实验选项不追溯限制本轮。旧工具驾驶冲突、暂停／取消／Reset／精确实例／组件变化保护保持。本轮关闭分步对照、动作更新隔离和自动刷新，直接在Beta驾驶中使用普通开关；不要求状态记录或探针。十Lua54、新驾驶生命周期回归及既有刷新／A/B／动作隔离／位置跟踪回归通过；已部署，原生共存及无位移效果待实机，不打verified。当前Beta及路线探针、旧阶段三、用户配置不改，日志／实测观察／本地回归／备份不入Git。


## Beta0.1.40：玩家防抖脱离探针独立使用（2026-10-13）

原路线防抖开关改名为“【原路线防抖】停止玩家原生自由落体”，默认关闭／不写Settings，不再依赖记录或60秒时限。驾驶前或途中可切换；未驾驶只等待，驾驶后校验精确当前玩家并沿用0.1.39的active-only实例stop()／false读回。结束驾驶释放引用但保留本次脚本内勾选，新驾驶重新捕获，Reset关闭；关闭勾选停止后续调用，不重建已取消落体。暂停不调用，旧实验1／2／3冲突和归属／控制器／接口／调用异常保护保留。不处理乘客／狮鹫，不改变锚点、AI、FSM、着地、共享重力或原生位置写入。

探针可选，关闭或到时不影响防抖；未记录时不采集防抖阶段诊断。六Lua54、新无探针／驾驶前／退出重进／暂停／Reset／手动关闭／记录关闭与到时／归属／控制器更换／错误保护及完整Beta回归通过，已配套部署。0.1.39玩家抖动改善已获用户实测，0.1.40独立生命周期原生效果尚待正常使用确认，见BETA_0140_PLAYER_ANTIJITTER.md。实验分支仅同步源码与通用说明；实测日志／分析、设置、备份及本地回归不入Git，其他会话及MOD保持。


## Beta0.1.41：座位NPC防抖及狮鹫独立开关（2026-10-13）

沿用已由用户确认有效的原生自由落体停止方案。原开关改为“【原路线防抖】玩家和座位NPC停止原生自由落体”，包含当前座位预设接管的全部随从／同伴NPC；各自实体同步后处理，只对精确当前绑定／当前控制器且active=true调用stop()并读回false。离座、确认离队、卸载、恢复和结束驾驶不再处理；单NPC异常本次绑定停止重试，不中断玩家或其他乘客，重绑／重开可重试。

新增独立默认关闭“【原路线防抖】狮鹫停止原生自由落体”，仅本Beta当前驾驶的spawn_enemy返回chara／go，捕获后引用变化拒绝旧调用；可独立于玩家／NPC开关使用。两开关无需探针／无60秒限制，可预先勾选；暂停不调用，退出释放引用并保留本次勾选，重进重新捕获，Reset关闭且不写Settings。没有新增Hook／位置setter、共享重力、着地、AI或FSM写入，不修改其他狮鹫、路人、未接管角色、其他MOD或另一会话工具。

六Lua54、完整Beta回归及实际Beta同步后接入／两随从与真同行NPC和路人对照／NPC失败隔离／离座／离队／卸载／实例及控制器更换／狮鹫独立开关／暂停／退出重进／Reset与设置隔离均通过，源码／游戏／仓库六文件内容一致，已部署。玩家方案已获用户实机确认，本次NPC和狮鹫扩展仍待正常使用实机确认；见BETA_0141_SEATED_NPC_GRIFFIN_ANTIJITTER.md。不要求重复60秒对照。实验分支白名单仅源码与通用说明，设置／日志／实测分析／备份／本地回归不上传。


## Beta0.1.42：解除防抖与旧跌落实验的强制互斥（2026-10-13）

用户明确要求组合使用，撤销早期单变量测试门限：删除fall_stop的conflict查询／启用门限／持续门限，以及入口fall_conflict／griffin_conflict回调。玩家／座位NPC防抖与实验1高度及SecFall重置、实验2IsGround覆盖可同时开启；狮鹫防抖亦可和旧实验3组合。开关彼此独立，不自动更改另一项，先后启用顺序均可。不改变原调用顺序、实现、默认值或Settings；精确归属／控制器引用／签名／暂停／退出／读回与原生调用异常保护保持。

六Lua54、完整Beta回归与实际Beta两种组合启用顺序均通过：玩家／随从／同伴NPC／狮鹫停止仍执行，高度与SecFall重置仍执行，IsGround覆盖仍有效、未接管角色排除，开关及退出保持独立。已配套部署且源码／游戏／仓库内容一致，组合画面效果待实机；见BETA_0142_COMBINED_FALL_CONTROLS.md。不要求探针或额外审批，不将旧单变量偏好解释为持续使用限制。历史说明中强制关闭旧实验的要求不再适用于0.1.42。实验分支仅同步源码和通用说明，用户设置／日志／本地测试与备份不入Git，其他会话不改。


## Beta0.1.43：精确实例自由落体启动拦截（2026-10-13）

原防抖开关保留active-only stop()，新增驾驶期间阻止FreeFallController重新启动。启用时校验8个start/startWithFrame/startWithSec（含KeepGravityAccel）Void重载，按原生地址去重安装共享Hook；只匹配实体同步处登记的当前控制器指针，复核精确驾驶／玩家／座位NPC／可选狮鹫归属后跳过原生启动。inactive控制器同样登记，覆盖stop后同帧重启。未接管／已释放／关闭／暂停放行；不改via.vec3返回、位置setter、碰撞、重力、AI或FSM。Hook保留安装，停用清绑定并放行；NPC异常隔离、控制器替换复核、退出／Reset和设置隔离保持。

菜单增加玩家／座位NPC及狮鹫阻止重新落体次数，原路线探针快照增加按角色及入口计数、最近入口及去重后入口数；共享入口别名合并，不伪称区分具体重载。防抖仍独立于探针、默认关闭／不持久化，旧实验1／2／3组合继续可用，狮鹫独立开关保持。

六Lua54、完整Beta回归、新启动入口／共享地址去重／同帧位移模拟／正反实例／暂停与退出／计数快照／控制器替换及错误隔离、实际Beta座位和旧实验组合集成通过。已配套部署，真实原生Hook命中及水平抖动改善待实机；见BETA_0143_FALL_START_GUARD.md，不打verified标签。仅源码和通用说明进入实验分支，原始日志／数值分析／设置／备份／本地测试不上传，其他会话不改。


## Beta0.1.44：修复自由落体启动签名格式（2026-10-13）

用户实机确认0.1.43防抖无法开启，截图报缺少start(via.vec3,via.vec3,System.Single,System.Single)。当前原生转储存在该重载，本机已用get_method多参数签名均为逗号后带空格；0.1.43手写紧凑签名导致查找失败。0.1.44修正全部多参数start／startWithFrame／startWithSec签名，保持8入口及原生地址去重、实例范围、stop与启动拦截、计数、暂停／退出／异常隔离、旧实验组合及Settings契约不变。

离线模拟改为严格匹配REFramework格式，新增截图错误签名必须拒绝、修正签名必须成功的回归；8个入口类型与当前转储核对，六Lua54与完整Beta回归通过。源码／游戏／仓库内容一致并已部署，用户Settings未改；真正开启、原生Hook命中和画面效果待用户实测，未标记verified。见BETA_0144_FALL_SIGNATURE_FIX.md；日志／转储／备份和本地回归仍不上传，其他会话文件保持。


## Beta0.1.45：三秒逐帧精细探针（2026-10-13）

新增默认关闭、不持久化的原路线三秒只读探针，保留每个渲染帧的行为／实体写入／骨架恢复前后／渲染及普通回调边界坐标。保存世界原点、精确玩家／狮鹫位置、碰撞体／上下文、Root／Hip／头部、导航目标、双时钟、NickCore原始delta及动作帧、防抖快照与最近普通日志写盘起止时间。仅读取当前驾驶及spawn返回实例，不安装位置Hook，不改变防抖、旧实验组合、控制器、AI、FSM或座位。

三秒内暂缓本Beta普通日志写盘，原采样／事件继续缓存，录制结束再保存探针并恢复普通日志；其他模组和设置保存不受控制。与60秒原路线探针录制／待保存互斥，仅为减少观测开销。最大1000帧／20000阶段，暂停、实例变化、退出及Reset提前停止；写盘失败保留并重试。阶段边界采样不承诺记录全部原生位置setter。七Lua54、既有完整Beta及新增180连续帧／单帧跳返／零采样I-O／主脚本日志暂缓恢复／精确范围／生命周期和失败重试模拟通过，实机捕获待验证。见BETA_0145_THREE_SECOND_PROBE.md；原始日志、数值复核、设置、备份、本地测试不上传，其他会话不改。


## Beta0.1.46：驾驶期间缓存日志、暂停或结束后保存（2026-10-13）

普通日志及两种原路线探针改为驾驶且游戏未暂停时不做自动JSON序列化／写盘；三秒探针到时只停止采样，状态提示暂停游戏或结束驾驶保存。暂停自动保存普通脏日志一次，无新数据不反复保存；失败保留重试，Reset先释放驾驶再保存。其他模组及用户主动保存Settings不在自动日志控制范围内，不修改原有历史文件。

普通日志保留最近600样本／400事件并记录淘汰计数，长时间不停航保持最新记录且不尝试旋转写盘。旧60秒探针队列提升至1800帧以缓存完整录制及异常窗，暂停后仍120帧分卷；三秒探针边界／容量及防抖／旧实验组合／导航／座位／FSM均保持。七Lua54、既有完整Beta与新增长时间驾驶零自动输出／满缓存滚动／三秒结束不突发保存／暂停保存一次／旧探针超240帧缓存及分卷／失败重试检查通过，实际画面改善待用户验收。见BETA_0146_DEFERRED_LOG_OUTPUT.md。仅源码及通用说明进入实验分支，原始记录、内部数值分析、本地测试和Settings不上传，其他会话不改。


## Griffin Journey Redux 0.2.0 — clean gameplay and optional Debug (2026-10-13)

Preserve pushed baseline tag baseline-beta-v0.1.46-jitter-fixed. Replace the Beta autorun entry with GriffinJourneyRedux.lua and independent gameplay modules. Optional Debug retains experiments 1/2/3 and protection controls; remove stable-navigation-anchor and detailed-skeleton-recording implementations plus duplicate legacy recorders. Diagnostics default off, settings continue saving. Native free-fall anti-jitter is gameplay and defaults on for player/seated NPCs; Griffin remains optional/off. Menu uses the default theme. Lua54 and gameplay, exact-scope, lifecycle, no-diagnostics and Debug-absent regressions pass; 0.2.0 in-game visual acceptance remains pending. No AI-target fix is claimed. See CLEAN_020_TESTING.md and GRIFFIN_JOURNEY_REDUX_HANDOFF.md.


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


## Griffin Journey Redux 0.2.4 — hover movement and simplified controls (2026-10-13)

RT selects gear 2 sprint; LT brakes directly to gear 0 hover. Left-stick input from hover selects gear 1 body-relative horizontal movement, using the same hover action with eased Transform movement; horizontal right stick controls eased facing. Centering returns to stationary hover. The former native low-speed directional actions are removed; prior sprint guidance, takeoff, landing, seats and protection remain. Slow speed and turn rate are adjustable. AI research is paused.

Lua54 compilation and existing gameplay/protection/camera/settings/default-no-diagnostics and Debug-absent checks pass, with new actual-module movement, input, pause, native-update synchronization, scope and recovery checks. Native in-game stability and handling remain unverified. See CONTROLS_024_HOVER.md.


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


## Griffin Journey Redux 0.3.8: native instance-vector comparison (2026-10-14)

Replace the inconclusive speed-rate getter experiment with an opt-in, automatically restored 0.8 A/B test of the exact driven FlightControl's FlightMoveVector during updatePosition. The getter remains read-only diagnostic. Report update/late/position/getter call counts, vector values and context/interface errors. Shared status parameters are not modified. Pending restoration survives reset and participates in lifecycle recovery.

All 24 Lua54 files and prior/new offline regressions pass, including nested calls, unrelated controllers, engine overwrites, nil/reset/cancellation cleanup, restoration failure/retry, measured response and rejection of writes without speed change. Native control is still unverified; dive/climb speed modulation is not enabled. See NATIVE_SPEED_038_VECTOR_AB.md.


## Griffin Journey Redux 0.3.9: read-only native movement timing (2026-10-14)

Replace the inconclusive A/B menu entries with an opt-in three-second read-only timing probe. Record exact-controller positions, vectors and old speed before/after flight update and collider methods, native forward-distance returns, and adjacent-stage movement. Show missing optional methods and context/interface errors. No fields, return values, settings or files are modified. Earlier pending vector restoration remains supported.

All 25 Lua54 modules and prior/new offline regressions pass, including exact/unrelated controllers, nesting, bounded sampling, unchanged returns, idle zero reads, zero writes, cancellation and optional-method failure. Native timing must be observed before choosing another speed modification point; dive/climb speed modulation is not enabled. See NATIVE_TIMING_039.md.


## Griffin Journey Redux 0.3.10: opt-in sprint displacement overlay (2026-10-14)

Add a bounded Debug comparison of original sprint, six seconds of +6 m/s code displacement and original-speed recovery. Add each step to the current native position after UpdateBehavior and synchronize Transform, position context and controller without absolute locking, rotation changes or sprint restarts. Show actual A/B/recovery speed and immediate coordinate errors; partial setter failures participate in current-position recovery. Normal flight stays unchanged until the experiment is started.

All 26 Lua54 modules and prior/new offline regressions pass, including simulated pullback rejection, 30/120Hz, no speed-magnitude feedback, default zero writes, cancellation/reload repair and actual callback integration with LT inheriting the corrected measured velocity. Native coexistence, pullback and visual quality remain for in-game acceptance. Dive/climb modulation is not enabled. See SPRINT_OVERLAY_0310.md.


## Griffin Journey Redux 0.3.11: late-phase sprint overlay comparison (2026-10-14)

Move the opt-in +6 m/s overlay's injection and speed sampling from post-UpdateBehavior to post-LateUpdateBehavior. Retain the same synchronization and A/B/recovery sequence. Add read-only signed-position checkpoints before joint/rendering and the next behavior update; no extra pose writes or absolute pinning. Immediate readback and reverse-motion counters alone do not establish persistent movement.

All 26 Lua54 modules and previous/new offline regressions pass, including zero early injection, actual late-callback integration/LT inheritance and simulated same-frame rollback vs retained boost at checkpoints. Effective native speed addition and visual stability remain for game acceptance. Dive/climb modulation is not enabled. See SPRINT_OVERLAY_0311_LATE.md.
