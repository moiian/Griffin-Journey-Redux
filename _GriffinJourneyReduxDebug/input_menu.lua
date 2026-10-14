return function(ctx)
local _ENV=ctx
return function()
    if imgui.tree_node("长按驾驶 DEBUG") then
        local sampled=input.pad_down or {}
        imgui.text("手柄原始按键："..tostring(input.pad_bits or 0).."；开始："..tostring(sampled.start==true).."；结束："..tostring(sampled.stop==true))
        for _,name in ipairs({"start","stop"}) do
            local h=controls.holds[name] or {}
            local elapsed=h.started and math.max(0,math.min(1,now()-h.started)) or 0
            imgui.text(string.format("%s：%.2f / 1.00 秒；已触发/屏蔽：%s",name=="start" and "开始驾驶" or "结束驾驶",elapsed,tostring(h.consumed==true)))
        end
        imgui.text(controls.hold_status or "等待输入")
        imgui.tree_pop()
    end
end
end
