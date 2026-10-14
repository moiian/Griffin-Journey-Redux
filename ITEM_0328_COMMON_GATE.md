# 0.3.28：巧克力的 Common 使用检查

0.3.27 实机日志确认：CE 与原生字典均为物品 58990、UseEffect 67608110、Use/Special；custom_script 已加载且可调用。玩家打开背包时，Common、Base、NoLock、公开 isUseEnable 依次返回 false，Sub 没有调用。用户确认模拟当前玩家接口能够正常召唤。

本版在实际调用的 isUseEnableNoLockCommon(StorageData, Character, Character, Boolean) 执行原生检查后，仅对该物品和脚本、当前玩家自己或空目标、CE 脚本已加载、无驾驶/恢复/待请求/已有狮鹫/召唤演出/拍照时改写为允许。其他物品、其他角色、缺脚本或错 effect 保留原生结果；本 MOD 忙碌时拒绝。不跳过 Common 原生执行，不改原生消耗和 useItemSub。

接口解析在原完整签名查找失败后尝试去掉逗号后的空格，仍按完整参数类型查找，不使用有歧义的名称回退。能否消除实机缺接口错误待验证。

DEBUG 新增 Common 次数及最近改写；原可选探针由 Common 适配统一记录 native_result、effective_result、override，避免重复安装同一 Common Hook。其他外层探针仍只观察。默认关闭日志。

保留用户 Settings 与正在编辑的 bundle，不改 Content Editor、NickCore 或其他 MOD。13 组既有离线回归和新增 Common 精确范围/忙碌/旧 generation/签名回退测试通过；这不是实机使用成功证明。

## 实机验证

1. Reset scripts，确认版本 0.3.28；删除已有本 MOD 狮鹫。
2. 开启“记录道具使用探针”，在背包选中巧克力，尝试使用，再关闭背包。
3. 关闭探针保存。观察 Common 次数、最近改写，以及是否播放召唤演出。
4. 若仍灰或没有演出，保留 reframework/data/GriffinJourneyRedux_ItemProbe.json；无需重新制作道具。
