return function(ctx)
local _ENV=ctx
local adapter=item_integration
local function current_generation() return alive and state.generation==generation end
function adapter:draw()
    if not imgui.tree_node("召唤道具适配 DEBUG") then return end
    if beta_button("测试道具接口（模拟当前玩家）###BetaTestItemSummon") then
        local c=core()
        local ok,accepted,reason=pcall(bridge.summon_performance_from_item,c and c.properties.player)
        self.test_result=ok and tostring(reason) or tostring(accepted)
        self.test_accepted=ok and accepted==true
    end
    if self.test_result then imgui.text("接口测试："..self.test_result) end
    if item_probe then item_probe:draw() end
    if shop_item then imgui.text(shop_item.status) end
    if consumables then imgui.text(consumables.status) end
    if consumables and beta_button("测试发放披萨（1个）###BetaTestPizzaGrant") then
        run_once(function()
            if not current_generation() then return end
            if menu.gameplay_paused() then consumables.status="请先关闭游戏物品菜单，再测试发放";return end
            local c=core()
            local ok,err=pcall(consumables.grant,consumables,c and c.properties.player)
            if not ok then consumables.status="披萨发放失败："..tostring(err) end
        end)
    end
    if exit_landing_status then imgui.text(exit_landing_status) end
    if spawn_watch then
        imgui.text(spawn_watch.status)
        imgui.text(string.format("生命周期回收 %d；沉水Hook %s；检查错误 %d；迟到生成 %d",spawn_watch.removed,tostring(spawn_watch.sink_hook),spawn_watch.errors,#state.pending_cleanup))
        imgui.text(string.format("状态接口可读：IsDead %s／IsDown %s",tostring(spawn_watch.reads.get_IsDead),tostring(spawn_watch.reads.get_IsDown)))
    end
    imgui.text(self.status)
    imgui.text(string.format("道具 %d / 脚本 %d；使用检查 %d；最近放行 %s",self.id,self.script_id,self.use_checks,tostring(self.last_allowed)))
    imgui.text(string.format("Common检查 %d；最近改写 %s",self.common_checks or 0,tostring(self.common_override)))
    imgui.text(string.format("描述修正 %d；接口错误 %d",self.description_writes,self.errors))
    imgui.tree_pop()
end
end
