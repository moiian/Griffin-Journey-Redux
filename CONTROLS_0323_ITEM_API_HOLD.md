# 0.3.23 召唤接口与驾驶热键

## 道具调用

```lua
local api = rawget(_G, "GriffinJourneyReduxBridge")
if not api or type(api.summon_performance) ~= "function" then
    return 0
end
local accepted, reason = api.summon_performance()
return accepted and 1 or 0
```

将以上代码放进 Item Editor 对该道具创建的 Custom script / UseEffect 脚本正文；不放进每帧回调。参考目录实际 item_data.lua 的 useItemSub Hook 调用该脚本。保留编辑器分配的 custom_script ID 并随道具 bundle 发布，不手填任意 ID。这里提供接口与调用正文，尚未修改用户的道具 bundle。

`GriffinJourneyReduxBridge.summon_performance()` 返回 `accepted:boolean, reason:string`，只表示请求接受/拒绝，实际演出和 NickCore 生成异步执行。菜单【狮鹫召唤演出】也调用同一接口；请求时冻结当前保存/调整的生成时间、上方距离、前方距离。沿用赝品飞石流程、精确实例生成与友方/SkipThink等初始化。已有狮鹫、驾驶/恢复、其他车辆接管、暂停、飞石忙碌等仍拒绝。Reset 后旧接口引用拒绝执行，请在每次道具使用时重新取全局接口。

接口不会自动开始驾驶。原生赝品飞石流程的现有消耗行为保持；本接口不管理自定义道具的扣除/返还。脚本示例的 1/0 对应请求接受/拒绝，不代表狮鹫已出现。

## 热键

- 开始驾驶：B（via.hid.GamePadButton.RRight），键盘 F；长按满1秒后，仅检查一次玩家 Transform 与本 MOD 保留的狮鹫 Transform 的 UniversalPosition 三维距离。严格小于10米才调用原开始驾驶；等于10米拒绝。读取失败、未就绪、实例变更不驾驶。
- 同一次按住只尝试一次。距离太远时需松开、靠近、重按，持续按住不会每帧重查距离。排队开始仍绑定检查时的精确实例。
- 结束驾驶：原自定义绑定、键盘默认 X；长按1秒执行一次。暂停、录入按键、输入读取失败中断计时；恢复后需松开重按。Reset 时已按住也不触发。
- 首次升级将开始驾驶手柄 None 迁移到 B，其他自定义键保留；boarding_bindings_revision=1 保存后可再次清除绑定并永久保持 None。配置继续随菜单更改自动保存，不直接重写用户现有 Settings 文件。
- 菜单开始/结束驾驶按钮仍立即执行，距离/长按门槛仅作用于热键。共享开始/结束绑定时结束优先，同一按住不同时开始与结束。
- 移除【让狮鹫听话】按钮、绑定行、H 热键和 menu.listen；生成/开始驾驶内部原有目标设置保留。向上／前、向下／后更名为向前、向后。

## 验证

26 个 Lua54 源文件编译与8组既有回归通过；15项专项离线测试覆盖短按/1秒边界、严格10米边界/三维距离、持续按住一次检查、临界时取当前位置、结束长按、暂停/按键录入/重载屏蔽、无效实例、同键冲突、实例变更、移除指令和方向标签、接口配置快照/忙碌/旧引用拒绝、显式 None 保存重载。保留的碰撞、ROOT 座位和个人预设回归通过。测试位于 LocalTests/controls_0323；没有游戏内视觉验收。
