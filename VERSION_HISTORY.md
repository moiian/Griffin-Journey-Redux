# 狮鹫项目版本索引

当前实测基线：Beta 0.1.12。2026-10-11用户确认Hip偏移与恢复正常。阶段三工具当前0.3.17。镜头独立跟随待实现。

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

用户指定远端：https://github.com/moiian/Griffin-Journey-Redux 。本地仓库为D:\_Project\Griffin MOD\Repository，仅追踪两个Lua脚本及README、测试/版本说明和忽略规则。已有历史快照已导入；beta-v0.1.12-hip-verified标记用户确认的Hip基线。远端推送结果另由实际命令确认。

建议本地Git每完成一个独立改动就提交；重要改动前先留基线。实机通过时打里程碑标签，例如beta-v0.1.12-hip-verified。实验失败版本也可提交到实验分支，保留失败现象。每天收工或完成重要验证后推送GitHub。两者配合：本地提交提供即时回溯，远端推送提供异机备份。

源码、必要测试、变更记录与精简接口证据入库；大量原始日志、完整游戏转储、第三方参考MOD保留在本地资料目录。仓库使用显式允许列表，原项目备份、LOG、第三方资料不入库。后续实验在独立分支提交；本地变更及时提交，实机通过后再更新主分支与里程碑标签。
