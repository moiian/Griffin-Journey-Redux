# 0.3.27 灰色使用入口观测与手动接口测试

用户实机确认0.3.26下Special已进Tools、描述正确，但使用仍灰色，编辑器Try executing绿色成功/null无效果。此前isUseEnableSub适配未证明覆盖实际灰色入口，不能宣称已解决使用。当前道具脚本以input[2].from传角色，Content Editor的Try executing无参数pcall，所以该角色为空，被道具接口拒绝，脚本自己无返回值，UI绿色只说明Lua未报错。

用户发现Script Effects新窗口：其script_effect是带start/update/stop生命周期的效果实体，可引用custom_script；物品useItemSub直接按UseEffect读取custom_script，不读取script_effect。不要把新效果ID当物品脚本ID。用户截图有未保存bundle修改，本轮不覆盖、不改bundle或新效果实体。

一般设置→召唤道具适配DEBUG增加【测试道具接口（模拟当前玩家）】，直接传当前玩家并显示accepted/reason；允许关闭菜单后播放，失败明确显示原因。它是接口单独测试，不经过物品使用检查，不证明灰色按钮已修好，原生赝品演出消耗行为仍保持。

可选Debug包新增item_probe.lua：【记录道具使用探针（只观察）】默认OFF，不保存开关，初次开启才安装5个外层isUseEnable/NoLock/StorageData等原生Bool观察Hook，不改返回值；已有isUseEnableSub适配在ID过滤前补记录实际effect/actor，便于发现没有放行的原因。只记录58990，无其他道具事件。1秒快照保存CE/native参数值、script加载/函数、驾驶/生成/暂停状态；每方法最多4Hz事件、200条上限，1秒刷盘、关闭/Reset最终保存。路径reframework/data/GriffinJourneyRedux_ItemProbe.json，无默认输出，普通包缺Debug也能用手动接口按钮。原12组玩法与道具回归保持。

使用：重置脚本确认0.3.27，先删除已有狮鹫，开启探针，进背包选巧克力并打开使用菜单，回MOD取消勾选保存；随后可独立点模拟玩家按钮测试演出。不要先生成狮鹫再测灰色，否则现有狮鹫会按设计阻止再次召唤。日志到位后再决定应修哪层，不根据例子猜改参数/扩大Hook。

28Lua54及13组离线测试通过：默认无外层Hook/无文件写入、开启后5种观察返回值原样/无关ID不记录、nil角色与false结果、CE/native UseEffect差异/错误效果观测、200上限/关闭保存/Reset OFF、测试按钮accepted与busy理由、背包等待后只启动一次。源码/仓库/游戏限定文件同步，Settings与bundle不写，旧版完整备份。LocalTests/item_probe_0327，main不合并；实际灰色入口仍待用户LOG。
