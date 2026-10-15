# 0.3.48 — 修复延迟初始化的模块加载路径

## 已确认原因

用户实机进入存档及Reset均只显示等待。当前游戏re2_framework_log.txt记录：`[Griffin Journey Redux] startup failed: module '_GriffinJourneyRedux.session' not found`。玩家就绪后实际已进入初始化，失败发生在延迟回调加载正式模块；原生Lua搜索路径已不含REFramework autorun目录。0.3.46加入延后初始化时遗漏了这个执行时序；之前模拟始终保持完整package.path，不能证明实际回调加载成功。

对照牛车当前入口：它按明确reframework/autorun路径调用loadfile，不依赖延迟回调中的require搜索路径。

## 修复

狮鹫入口从自身文件路径解析本Mod模块，通过loadfile加载并复用package.loaded缓存；模块环境和共享ctx都使用同一加载器，因此正式版antijitter→fall_stop及可选Debug的嵌套依赖同样覆盖。仅处理本Mod两目录，其他模块仍交给原生require；不修改全局require、package.path/cpath/searchers，不改牛车或NickCore。主菜单仍只装轻量world入口，玩家就绪才加载其余模块。

初始化失败现在保留具体错误并在菜单显示“初始化失败：…”，不再冒充等待存档；仍只报告一次，不逐帧重复尝试或输出。0.3.47高空乘客与15米释放规则保留。

15米检查入口首先判断是否有保留乘客。全部释放后直接返回，不再执行这项距离检测。补测释放后600次入口调用，禁止任何存档暂停查询/validate_spawn仍通过；这不代表独立的43米闲置狮鹫清理也被取消。

## 验证及部署

45 Lua54编译；6次正式/Debug双模式加载专项及1次旧版精确错误复现：入口后清空Lua/C搜索路径、冷启动即移除searchers、嵌套正式/Debug依赖、缓存复用、全局路径不改、失败错误可见且有界。40保留乘客、30世界照片、32自动保存检查，3落体套件、8玩法双模式及默认/HUD回归通过。旧披萨静态文案断言跟随现有源JSON的标点更新，道具文件本身未改。

部署仅3正式Lua（入口/session版本/world错误显示），正式29/Debug16分离；Settings/bundle/Debug/第三方保留。新增离线用例复现了真实日志中的时序，仍需游戏内Reset后确认菜单恢复；不把模拟当作实机验收。不做哈希，不合并main。
