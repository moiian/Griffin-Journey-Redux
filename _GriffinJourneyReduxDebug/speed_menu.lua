return function(ctx)
local _ENV=ctx
return function()
        if active and active.sprint_speed then
            local speed=active.sprint_speed
            imgui.text(string.format("2档实测总速度：%.2f 米／秒%s",speed.total,speed.ready and "" or "（采样中）"))
            imgui.text(string.format("水平：%.2f 米／秒",speed.horizontal))
            imgui.text(string.format("竖直：%+.2f 米／秒",speed.vertical))
        end
        if active and active.sprint_status then imgui.text(active.sprint_status) end
        if active and active.sprint_handoff_speed then imgui.text(string.format("最近LT继承速度：%.2f 米／秒",active.sprint_handoff_speed)) end
end
end
