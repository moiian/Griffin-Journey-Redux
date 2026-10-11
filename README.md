# Griffin Journey Redux

Dragon’s Dogma 2狮鹫驾驶实验。明确依赖已安装的NickCore EnemySpawner和run_once，不附带第三方代码。

仓库仅追踪两个Lua脚本和版本/测试说明；LOG、设置JSON、完整游戏转储、第三方参考MOD不上传。

- main：Beta0.1.16分档操控已实机通过，作为后续打磨基线；保留Hip和头部镜头。
- 固定回档标签：beta-v0.1.12-hip-verified、beta-v0.1.13-head-camera-verified、beta-v0.1.14-sphere-verified、beta-v0.1.15-neutral-height-verified、beta-v0.1.16-flight-controls-verified。
- experiment/flight-gears：Beta0.1.16分档按键已实测通过并合并main。
- 阶段三工具保持原文件，可通过原有桥接接管Beta当前实例。

脚本部署到游戏reframework/autorun。当前操控和测试步骤见TESTING.md，版本变化见VERSION_HISTORY.md。

历史Import archived提交于2026-10-11从原快照导入；提交时间为导入时间，不是开发时间。失败版本保留在历史与版本说明。

当前实验分支experiment/camera-yaw-follow：Beta0.1.17，新增3档镜头自动水平跟随开关及速度滑条；右摇杆操作时暂停，松开0.8秒后回正。离线回归通过，实机待验收。main与beta-v0.1.16-flight-controls-verified继续保留已验证操控基线。
