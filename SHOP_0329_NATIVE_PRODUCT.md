# 0.3.29：独立添加巧克力商品

旧 shop_buy 部分列表是追加合并，不会替换其他 MOD 的完整商店。仍可能发生相同 ID/商品条目的冲突，不能把部分追加描述为无条件兼容。

新增 _GriffinJourneyRedux/shop_item.lua 独立实现本 MOD 单件商品的原生添加，不复制或依赖 editor_shops.lua 的通用实体注册、导入或编辑器代码。

- 目标 Shop 5，物品 58990，库存上限/初始参数 19，每 1 天补 9。
- 等待 Content Editor 的物品 runtime_instance 与 custom_script 均正确加载，且 MainFlowManager 在游戏阶段，再取 ItemManager.getItemShopData(5)。
- 新建 ItemShopBuyParam；已存在单个同 ID 时复用，适配旧版本已有商品。多个同 ID 时不猜测归属，不修改列表并显示冲突。
- 保留其他商品对象及相对顺序，把本件插入原生 _BuyParams 的第二项；空商店放第一项。不使用整店 bundle 覆盖。
- 游戏原生 ItemShopStockData 按 ShopId/ItemId 保存 Stock/StockMax/AddDay/AddInterval/AddNum。本 MOD 只设商品参数，未自行计时补货、未读写库存存档或反复补满。
- 每秒检查一次商店与数组引用；引用不变不遍历、不重新创建数组。数组被其他 MOD 替换时重新合并。Reset 仅移除本代自己创建的精确商品对象，保留后来添加的其他商品；复用旧对象不删除。
- bundle 移除 shop_buy 875224，保留物品、说明换行和召唤脚本。玩家不再需要 Shop Editor；原版 Content Editor 及狮鹫 MOD 既有前置仍需要。
- 不改 Content Editor、Shop Editor、NickCore 或其他 MOD，不改玩家 Settings；未解决全局 ID 撞号问题。

## 发布文件

狮鹫 MOD 入口及完整 _GriffinJourneyRedux 模块目录，包括 shop_item.lua；道具文件置于 reframework/data/usercontent/bundles/GriffinJourneyRedux_Items.json。不发布个人 Settings、缓存、LOG 或游戏转储。

## 验证与限制

既有 13 组回归、0328 Common 入口专项，以及新增加载时序、第二项插入、库存参数、不改原生存档、重复调用、第三方追加、旧条目复用、重复 ID 拒绝、空店/新店引用与 Reset 精确清理模拟通过。

这仅证明离线逻辑。游戏是否保留数组顺序显示第二项、补货的原生时间行为、全新存档首次生成库存，仍待实机验证；不得把数组位置直接当作界面排序成功。

关闭商店后 Reset scripts，确认 0.3.29；可在一般设置→召唤道具适配 DEBUG 查看商店状态，再打开 Shop 5。验证无需 Shop Editor 时，可在游戏关闭后由用户暂时停用 editor_shops.lua 再启动，本次部署不修改该第三方脚本。
