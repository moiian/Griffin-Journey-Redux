# Griffin Journey Redux

Dragon’s Dogma 2狮鹫驾驶实验，依赖已安装的NickCore EnemySpawner和run_once，不附带第三方代码。

仓库只追踪两个Lua脚本及版本/测试说明；LOG、设置JSON、完整游戏转储和第三方参考MOD不上传。

- main：Beta0.1.17水平镜头跟随实机基线，保留0.1.16分档操控、Hip显示与头部位置镜头。
- 最新验证标签：beta-v0.1.17-camera-yaw-verified；此前各实机基线标签仍保留。
- experiment/camera-input-blend：Beta0.1.18左摇杆触发双轴镜头、右摇杆小幅叠加/大幅接管。离线通过，实机待验证。
- 阶段三工具保持原脚本，通过原有桥接接管Beta实例。

脚本部署至游戏reframework/autorun。当前测试见TESTING.md，历史变化与失败版本见VERSION_HISTORY.md。
Import archived开头的历史提交为2026-10-11导入旧快照，提交日期不代表原开发日期。
