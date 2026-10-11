# Griffin Journey Redux

Dragon’s Dogma 2狮鹫驾驶实验。明确依赖已安装的NickCore EnemySpawner和run_once，不附带第三方代码。

仓库仅追踪两个Lua脚本和版本/测试说明；LOG、设置JSON、完整游戏转储、第三方参考MOD不上传。

- main：Beta 0.1.13已验证基线，Hip显示保持正常；镜头跟随狮鹫头部和恢复由用户确认，其他镜头候选未生效。
- beta-v0.1.12-hip-verified：固定回档标签。
- beta-v0.1.13-head-camera-verified：头部镜头跟随与恢复基线。
- experiment/head-sphere-navigation：Beta 0.1.14头部球面导航、半径与转向角度滑条实验；离线回归通过，实机手感待验证。

脚本部署到游戏reframework/autorun。具体依赖与结果见VERSION_HISTORY.md，当前分支测试步骤见TESTING.md。

历史中Import archived开头的提交于2026-10-11从原快照导入；提交时间是导入时间，不是原开发时间。失败版本保留在历史中，并在版本说明中标注。
