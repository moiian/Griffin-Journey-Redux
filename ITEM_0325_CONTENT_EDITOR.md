# 0.3.25 召唤道具分类、使用与描述适配

道具58990、脚本67608110保持。bundle只改SubCategory为Special(3)、脚本调用正文及updated_at/updated_at_time；名称、描述、价格、重量、图标、属性和其他个人值保留。先前手改JSON时缺少更新时间戳说明：Content Editor按bundle时间决定是否重新注入，缓存时间1791981227晚于原bundle1791981187，Reset可能继续沿用旧runtime_instance。此次写入新时间戳，不清全局缓存。

代码确认：Content Editor getElfMsg/getMsg字符串Hook只解析尾部ID，不区分item_detail_与名字，因此item_detail_58990会返回item.name。已在真实旧函数的离线测试中复现。新item_integration.lua只在精确道具的ItemWindowRef五种声明类型setup后写回description，其他道具不改；不修改Content Editor本体。

使用方面原Item/Use/Heal且恢复数值均0，原生使用条件仍先于useItemSub脚本；只挂isUseEnableSub(Character,Character,ItemDataParam)效果检查，限定本道具ID+脚本ID、当前玩家自己/空目标、已加载Content Editor实体与脚本函数。允许不受HP恢复条件限制，已有狮鹫/驾驶/恢复/排队/演出时返回false；外层库存/锁定检查保留，其他道具或其他角色回原生。具体灰色入口须实机确认，DEBUG计数可判断是否进入该检查。

新增GriffinJourneyReduxBridge.summon_performance_from_item(user)，user必须为当前NickCore玩家。道具脚本通过Content Editor注入的input[2].from调用。请求允许背包暂停，冻结当前召唤设置，等待关闭菜单再开始原生赝品演出；最多等30秒，重复/Reset/玩家变化/取消均不重复开始。原summon_performance()菜单接口不变，依然拒绝暂停；两条路径共用原演出与生成/友方/SkipThink流程。

转储确认useItemSub返回Void，因此旧脚本return 1/0不能作为扣除成功/失败契约。新版脚本不伪造返回值，仅失败时输出一条原因。自定义道具与原生赝品的实际扣除情况待实测，没有增加返还或扣除Hook。

一般设置→召唤道具适配DEBUG显示使用检查次数、最近放行结果、描述修正次数、接口错误。无常驻LOG、无场景扫描；模块需随狮鹫MOD分发，ContentEditor/GriffinJourneyRedux_Items.json放入reframework/data/usercontent/bundles。不要装两份同ID bundle。

27Lua54及11组离线测试通过：旧玩法/新默认值/长按/碰撞等保留；本件满血放行、其他ID/脚本/角色隔离、加载器缺失、忙碌与旧generation、五种详情入口、背包暂停等待/配置快照/重复/取消/超时/Reset、真实Content Editor useItemSub Hook执行Void脚本、真实旧描述函数复现、Special及其他物品字段不变/新时间戳。LocalTests/item_integration_0325；全部离线，实机仍需关闭游戏重新启动验证。升级前完整备份，Settings不改，main不合并。
