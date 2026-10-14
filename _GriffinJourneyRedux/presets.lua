-- Griffin Journey Redux: presets
return function(ctx)
local _ENV=ctx
function beta_button(label) return imgui.button(label) end
-- Player-facing menu. Debug controls share this script and are collapsed by default.
settings.anchor_mode=loaded_settings and loaded_settings.anchor_mode=="full" and "full" or "rider"
anchor_mode=settings.anchor_mode
settings.head_camera=not loaded_settings or loaded_settings.head_camera~=false
menu.clone=function(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=menu.clone(v) end;return result
end
-- OJR preset contract: edit the persisted layout itself, never a second draft.
menu.snapshot=function(name,source)
    local preset=menu.clone(source or {})
    preset.schema=5;preset.name=name
    preset.player=preset.player or {}
    for k,v in pairs(passengers.player_config()) do preset.player[k]=v end
    preset.camera=preset.camera or {};preset.camera.distance=settings.distance;preset.camera.fov=settings.fov
    preset.pawns=menu.clone(settings.pawn_seats or preset.pawns or {})
    preset.companions=menu.clone(settings.companion_seats or preset.companions or {})
    return preset
end
settings.pawn_seats=menu.clone(loaded_settings and loaded_settings.pawn_seats or {})
settings.companion_seats=menu.clone(loaded_settings and loaded_settings.companion_seats or {})
settings.seat_presets={}
if loaded_settings and type(loaded_settings.seat_presets)=="table" then
    for _,preset in ipairs(loaded_settings.seat_presets) do
        if type(preset)=="table" and type(preset.name)=="string" and type(preset.player)=="table"
            and finite(preset.player.height) and finite(preset.player.forward) and finite(preset.player.side) then
            settings.seat_presets[#settings.seat_presets+1]=menu.clone(preset)
        end
    end
end
if #settings.seat_presets==0 then settings.seat_presets[1]=menu.snapshot("实体位置校正") end
if #settings.seat_presets==1 then
    settings.seat_presets[2]=menu.clone(settings.seat_presets[1]);settings.seat_presets[2].name="默认乘坐座位"
end
settings.seat_index=math.max(2,math.min(#settings.seat_presets,math.floor(tonumber(loaded_settings and loaded_settings.seat_index) or 2)))
-- Recover legacy edits that were written only to the runtime mirrors, once.
if loaded_settings and loaded_settings.preset_store_revision~=1 and loaded_settings.seat_index~=1 then
    local preset=settings.seat_presets[settings.seat_index]
    for key,value in pairs(passengers.player_config()) do
        if loaded_settings["rider_"..key]~=nil then preset.player[key]=value end
    end
    preset.camera=type(preset.camera)=="table" and preset.camera or {}
    for _,key in ipairs({"distance","fov"}) do if loaded_settings[key]~=nil then preset.camera[key]=settings[key] end end
    for _,entry in ipairs({{"pawn_seats","pawns"},{"companion_seats","companions"}}) do
        if type(loaded_settings[entry[1]])=="table" then preset[entry[2]]=menu.clone(loaded_settings[entry[1]]) end
    end
end
if not finite(settings.seat_presets[1].player.tilt_follow) then settings.seat_presets[1].player.tilt_follow=0 end
if not finite(settings.seat_presets[1].player.pitch_offset) then settings.seat_presets[1].player.pitch_offset=0 end
menu.migrate_physical=function()
    if loaded_settings and loaded_settings.physical_seat_revision==1 then return end
    local preset=settings.seat_presets[1]
    for _,group in ipairs({"pawns","companions"}) do
        local count=group=="pawns" and 3 or 0
        for _,entry in ipairs(settings.seat_presets) do count=math.max(count,type(entry[group])=="table" and #entry[group] or 0) end
        preset[group]=type(preset[group])=="table" and preset[group] or {}
        for i=1,count do
            local seat=menu.clone(preset[group][i] or {})
            for _,field in ipairs({"anchor","neck_joint","height","forward","side","tilt_follow","pitch_offset"}) do seat[field]=preset.player[field] end
            seat.enabled=true;seat.anim="";preset[group][i]=seat
        end
    end
end
menu.migrate_physical()
settings.physical_seat_revision=1
settings.preset_store_revision=1
menu.show_physical=false
menu.selected_index=settings.seat_index
menu.last_normal=settings.seat_index
menu.reindex=function()
    for i,preset in ipairs(settings.seat_presets) do
        preset.name="["..i.."] "..preset.name:gsub("^%[%d+%]%s*","")
        preset.enabled=true
        if type(preset.pawns)~="table" then preset.pawns={} end
        if type(preset.companions)~="table" then preset.companions={} end
    end
end
menu.pull_values=function(index)
    local preset=settings.seat_presets[index]
    local player=preset.player
    player.anchor=player.anchor=="root" and "root" or (player.anchor=="neck" and "neck" or "head")
    player.neck_joint=type(player.neck_joint)=="string" and player.neck_joint or ""
    player.anim=type(player.anim)=="string" and player.anim or ""
    for _,spec in ipairs({{"height",1,-5,15},{"forward",0,-15,15},{"side",0,-10,10},
        {"lookX",0,-1,1},{"lookZ",1,-1,1},{"tilt_follow",index==1 and 0 or 1,0,1},{"pitch_offset",0,-45,45}}) do
        local value=player[spec[1]]
        local coordinate=spec[1]=="height" or spec[1]=="forward" or spec[1]=="side"
        player[spec[1]]=finite(value) and ((index==1 or player.anchor=="root") and coordinate and value or math.max(spec[3],math.min(spec[4],value))) or spec[2]
    end
    for key,value in pairs(player) do
        if ({anchor=true,neck_joint=true,anim=true,height=true,forward=true,side=true,lookX=true,lookZ=true,tilt_follow=true,pitch_offset=true})[key] then
            settings["rider_"..key]=value
        end
    end
    -- The current layout controls visible seats and carry options, including debug [1].
    settings.pawn_seats=preset.pawns;settings.companion_seats=preset.companions
    if index~=1 then
        preset.camera=type(preset.camera)=="table" and preset.camera or {}
        for _,spec in ipairs({{"distance",30,0,80},{"fov",90,40,120}}) do
            local value=preset.camera[spec[1]]
            preset.camera[spec[1]]=finite(value) and math.max(spec[3],math.min(spec[4],value)) or spec[2]
            settings[spec[1]]=preset.camera[spec[1]]
        end
    end
end
menu.persist_preset=function(preset)
    for index,entry in ipairs(settings.seat_presets) do
        if entry==preset and index==settings.seat_index then menu.pull_values(index);break end
    end
    menu.reindex()
    controls.save()
end
menu.apply_preset=function(index)
    local preset=settings.seat_presets[index]
    if not preset or index==1 and not menu.show_physical then return end
    if index~=1 then menu.last_normal=index end
    settings.seat_index=index;menu.selected_index=index
    menu.pull_values(index)
    if active then
        active.fall_reset_pending=true;active.pose_pending=settings.rider_anim
        for _,a in pairs(active.passengers or {}) do
            a.fall_reset_pending=true;a.pose_pending=passengers.visual_seat(a.group,a.slot).anim
        end
    end
    controls.save();status="当前生效预设："..preset.name
end
menu.apply_pending_preset=function()
    local preset=menu.pending_preset
    if not preset or not core() or menu.gameplay_paused() and not menu.photo_active() then return end
    menu.pending_preset=nil
    for index,entry in ipairs(settings.seat_presets) do if entry==preset then menu.apply_preset(index);return end end
end
menu.queue_preset=function(index)
    local preset=settings.seat_presets[index]
    if not preset or index==1 and not menu.show_physical then return end
    menu.selected_index=index;menu.confirm_delete=nil;menu.pending_preset=preset
    if type(run_once)=="function" then run_once(function() if alive then menu.apply_pending_preset() end end) end
end
menu.next_preset=function()
    local index=settings.seat_index+1
    menu.queue_preset(index>#settings.seat_presets and 2 or index)
end
menu.reindex();menu.pull_values(settings.seat_index)
-- No settings file is overwritten during deployment. This migration runs on script load.
if loaded_settings then controls.save() end

menu.edit_facing=function(seat,id)
    local dirty=false
    for _,spec in ipairs({{"lookX","Look At X（右正／左负）",0,-1,1},
        {"lookZ","Look At Z（前正／后负）",1,-1,1},
        {"pitch_offset","角色倾斜修正角（度）",0,-45,45}}) do
        local key=spec[1]
        if not finite(seat[key]) then seat[key]=spec[3] end
        local changed,value=imgui.slider_float(spec[2].."###"..id..key,seat[key],spec[4],spec[5])
        if changed and finite(value) then seat[key]=math.max(spec[4],math.min(spec[5],value));dirty=true end
    end
    local changed,value=menu.toggle("角色身体倾斜跟随###"..id.."Tilt",(seat.tilt_follow or 1)>0)
    if changed then seat.tilt_follow=value and 1 or 0;dirty=true end
    imgui.text("Look At X左右面向、Z前后面向；(0, 1)朝狮鹫前方。倾斜仅作用于角色身体。")
    return dirty
end
menu.animation=function(seat,id,preset)
    if type(seat.anim)~="string" then seat.anim="" end
    if type(imgui.input_text)=="function" then
        local changed,value=imgui.input_text("动作名称###"..id.."Anim",seat.anim)
        if changed and type(value)=="string" then seat.anim=value:sub(1,160);menu.persist_preset(preset) end
    end
    if beta_button("播放动画###"..id.."Play") then
        local d=active
        local a=id=="BetaPlayerPose" and d or nil
        for _,member in pairs(d and d.passengers or {}) do
            if id=="BetaSeat"..member.group..member.slot then a=member end
        end
        if not a then status="请先开始驾驶并启用该座位。"
        else a.pose_pending=seat.anim end
    end
end
menu.number=function(label,value,step,lo,hi)
    if type(imgui.drag_float)=="function" then return imgui.drag_float(label,value,step,lo,hi) end
    return imgui.slider_float(label,value,lo,hi)
end
menu.edit_seat=function(seat,id,preset)
    local dirty=false
    if type(imgui.combo)=="function" then
        local changed,index=imgui.combo("骨骼锚点###"..id.."Anchor",seat.anchor=="root" and 3 or (seat.anchor=="neck" and 2 or 1),{"头部","颈部","根节点（Transform）"})
        if changed then seat.anchor=index==3 and "root" or (index==2 and "neck" or "head");dirty=true end
        if seat.anchor=="neck" then
            local names={"自动（首个颈部骨骼）"};local selected=1
            for _,entry in ipairs(active and active.rider_necks or {}) do
                names[#names+1]=entry.name;if entry.name==seat.neck_joint then selected=#names end
            end
            local changed,index=imgui.combo("颈部骨骼###"..id.."Neck",selected,names)
            if changed then seat.neck_joint=index==1 and "" or names[index];dirty=true end
        end
    end
    if seat.anchor=="root" then imgui.text("根节点为狮鹫Transform原点；测量检测球时关闭角色身体倾斜跟随。") end
    for _,spec in ipairs({{"side","X（左右）",-10,10},{"forward","Z（前后）",-15,15},{"height","Y（高度）",-5,15}}) do
        if not finite(seat[spec[1]]) then seat[spec[1]]=0 end
        if preset==settings.seat_presets[1] or seat.anchor=="root" then spec[3],spec[4]=-100,100 end
        local changed,value=menu.number(spec[2].."###"..id..spec[1],seat[spec[1]],0.05,spec[3],spec[4])
        if changed and finite(value) then seat[spec[1]]=math.max(spec[3],math.min(spec[4],value));dirty=true end
    end
    if menu.edit_facing(seat,id=="BetaPlayerSeat" and "BetaPlayerFacing" or id) then dirty=true end
    if dirty then
        menu.persist_preset(preset)
        if active then
            if id=="BetaPlayerSeat" then active.fall_reset_pending=true end
            for _,a in pairs(active.passengers or {}) do
                if id=="BetaSeat"..a.group..a.slot then a.fall_reset_pending=true end
            end
        end
    end
    menu.animation(seat,id=="BetaPlayerSeat" and "BetaPlayerPose" or id,preset)
end
menu.passenger_seats=function(preset)
    for _,group in ipairs({"pawns","companions"}) do
        local roster=(passengers.roster or {})[group] or {}
        local count=math.max(group=="pawns" and 3 or 0,#roster,#preset[group])
        for i=1,count do
            if imgui.tree_node((group=="pawns" and "随从 " or "同伴NPC ")..i.."###BetaSeat"..group..i) then
                local seat=passengers.seat(group,i,preset)
                local changed,value=menu.toggle("自动携带／冻结FSM###BetaSeatEnabled"..group..i,seat.enabled~=false)
                if changed then seat.enabled=value;menu.persist_preset(preset) end
                menu.edit_seat(seat,"BetaSeat"..group..i,preset)
                imgui.tree_pop()
            end
        end
    end
end
menu.presets=function()
    imgui.text("当前生效预设："..settings.seat_presets[settings.seat_index].name)
    if imgui.separator then imgui.separator() end
    local first=menu.show_physical and 1 or 2
    local names={};for i=first,#settings.seat_presets do names[#names+1]=settings.seat_presets[i].name end
    menu.selected_index=math.max(first,math.min(#settings.seat_presets,menu.selected_index or settings.seat_index))
    if type(imgui.combo)=="function" then
        local changed,index=imgui.combo("当前布局###BetaPresetSelect",menu.selected_index-first+1,names)
        if changed and names[index] then menu.queue_preset(index+first-1) end
    end
    local index=menu.selected_index
    local preset=settings.seat_presets[index]
    if index~=1 then
        if #settings.seat_presets<15 and beta_button("＋新增预设（最多15项）###BetaPresetNew") then
            local clone=menu.clone(preset)
            clone.name="狮鹫座位 - "..(#settings.seat_presets+1)
            settings.seat_presets[#settings.seat_presets+1]=clone
            menu.reindex();controls.save();menu.queue_preset(#settings.seat_presets)
            return
        end
        if #settings.seat_presets>2 then
            if imgui.same_line then imgui.same_line() end
            if menu.confirm_delete~=preset then
                if beta_button("删除预设###BetaPresetDelete") then menu.confirm_delete=preset end
            else
                if beta_button("确认删除###BetaPresetConfirmDelete") then
                    table.remove(settings.seat_presets,index)
                    if settings.seat_index>index then settings.seat_index=settings.seat_index-1
                    elseif settings.seat_index==index then settings.seat_index=math.max(2,math.min(index,#settings.seat_presets)) end
                    menu.last_normal=math.max(2,math.min(menu.last_normal or 2,#settings.seat_presets))
                    menu.selected_index=math.max(2,math.min(index,#settings.seat_presets));menu.confirm_delete=nil
                    menu.reindex();menu.pull_values(settings.seat_index);controls.save();menu.queue_preset(settings.seat_index)
                    return
                end
                if imgui.same_line then imgui.same_line() end
                if beta_button("取消###BetaPresetCancelDelete") then menu.confirm_delete=nil end
            end
        end
        if type(imgui.input_text)=="function" then
            local changed,name=imgui.input_text("预设名称###BetaPresetName",preset.name)
            if changed and type(name)=="string" and name:match("%S") then preset.name=name:sub(1,120);menu.persist_preset(preset) end
        end
    else imgui.text("调试[1]：各随从／同伴的实体与当前Hip使用各自参数；玩家参数只控制玩家Hip。") end
    if imgui.tree_node("玩家参数###BetaPlayerParameters") then
        menu.edit_seat(preset.player,"BetaPlayerSeat",preset)
        if index~=1 then
            preset.camera=type(preset.camera)=="table" and preset.camera or {distance=settings.distance,fov=settings.fov}
            for _,spec in ipairs({{"distance","相机距离偏移",0,80},{"fov","FOV",40,120}}) do
                local changed,value=menu.number(spec[2].."###BetaPresetCamera"..spec[1],preset.camera[spec[1]],0.1,spec[3],spec[4])
                if changed and finite(value) then preset.camera[spec[1]]=math.max(spec[3],math.min(spec[4],value));menu.persist_preset(preset) end
            end
        end
        imgui.tree_pop()
    end
    menu.passenger_seats(preset)
    imgui.text("与牛车MOD相同：调整立即保存；新增复制当前布局，删除需确认。")
    if menu.pending_preset then imgui.text("布局切换已排队，继续游戏或进入照片模式后应用。") end
    if active and menu.photo_active() then imgui.text("照片模式：保持座位显示；飞行输入和动画请求暂停。") end
    if menu.save_error then imgui.text(menu.save_error) end
end

menu.stop=function()
    operation=nil;queued=false
    if type(run_once)~="function" then stop_driver("手动结束");return end
    run_once(function() if alive then stop_driver("手动结束") end end)
end
menu.delete=function()
    if summon then summon:cancel("手动删除") end
    operation=nil;queued=false
    if type(run_once)~="function" then status="等待依赖加载后再删除。";return end
    run_once(function()
        if not alive or not stop_driver("删除狮鹫") then return end
        set_skip_think(false)
        for _,r in ipairs(state.spawns) do r.delete_requested=true;delete_one(r) end
    end)
end
menu.slider=function(key,label,low,high)
    if type(imgui.slider_float)~="function" then return end
    local changed,value=imgui.slider_float(label,math.max(low,math.min(high,settings[key])),low,high)
    if changed and finite(value) then settings[key]=math.max(low,math.min(high,value));controls.save() end
end
menu.toggle=function(label,value)
    if type(imgui.checkbox)~="function" then return false,value end
    return imgui.checkbox(label,value)
end
menu.bindings=function()
    local table_open=type(imgui.begin_table)=="function" and imgui.begin_table("GriffinBindings",3,1)
    if table_open then
        imgui.table_next_row()
        for _,label in ipairs({"动作","手柄","键盘／鼠标"}) do imgui.table_next_column();imgui.table_header(label) end
    end
    for _,row in ipairs(controls.rows) do
        if table_open then imgui.table_next_row();imgui.table_next_column() end
        imgui.text(row[2])
        for _,device in ipairs({"gamepad","keyboard"}) do
            if table_open then imgui.table_next_column() end
            local capture=controls.capture
            local label=capture and capture.action==row[1] and capture.device==device and "请按新按键…" or settings.bindings[row[1]][device]
            if beta_button(label.."###BetaBind_"..row[1].."_"..device) then
                controls.capture={action=row[1],device=device};controls.previous={}
            end
        end
    end
    if table_open then imgui.end_table() end
    if controls.capture then
        imgui.text("先松开已按住的键，再按新键。录入期间暂停驾驶输入。")
        if beta_button("取消录入###BetaBindCancel") then controls.capture=nil;controls.release_gate=true end
        if beta_button("清除此绑定###BetaBindClear") then
            settings.bindings[controls.capture.action][controls.capture.device]="None"
            controls.capture=nil;controls.release_gate=true;controls.save()
        end
    end
    if beta_button("恢复默认按键###BetaBindDefaults") then
        for _,row in ipairs(controls.rows) do settings.bindings[row[1]]={keyboard=row[3],gamepad=row[4]} end
        controls.capture=nil;controls.release_gate=true;controls.previous={};controls.save()
    end
    local used={}
    for _,row in ipairs(controls.rows) do
        for _,device in ipairs({"keyboard","gamepad"}) do
            local name=settings.bindings[row[1]][device];local key=device..":"..name
            if name~="None" then
                if used[key] then imgui.text("重复绑定："..used[key].."／"..row[2].." → "..name) else used[key]=row[2] end
            end
        end
    end
end
end
