-- Menu edits are drafts; preview is independent of explicit disk persistence.
return function(ctx)
local _ENV=ctx
menu.realtime=false
menu.draft=menu.clone(settings)
menu.saved=menu.clone(settings)
menu.edit_revision=0
menu.applied_revision=0
menu.edit_dirty=false
local function current() return alive and state.generation==generation end
local function normalize(config)
    config.griffin_anti_jitter=false
    config.anchor_mode="rider"
    config.hover_collision_config.return_to_safe=false
end
local function retain_generated_seats(config)
    for index,preset in ipairs(settings.seat_presets) do
        local target=config.seat_presets[index]
        if target and target.name==preset.name then
            for _,group in ipairs({"pawns","companions"}) do
                target[group]=target[group] or {}
                for slot,seat in ipairs(preset[group] or {}) do
                    if target[group][slot]==nil then target[group][slot]=menu.clone(seat) end
                end
            end
        end
    end
end
normalize(menu.draft)
normalize(settings)
local native_pending=false
local reset_session_pending=false
local function equal(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function native_options()
    if reset_session_pending then
        if menu.reset_debug_defaults then menu.reset_debug_defaults() end
        menu.block_cross_phase=true;block_player_fall=true
        if active then apply_player_freeze(active,settings.freeze_player) end
        local r=active and active.spawn or state.spawns[#state.spawns]
        if r and r.ready and not r.delete_requested then set_skip_think(true) end
        reset_session_pending=false
    end
    local cfg=settings.hover_collision_config
    if hover_collision.enabled~=cfg.enabled then
        hover_collision:set_enabled(cfg.enabled)
        assert(hover_collision.enabled==cfg.enabled,hover_collision.status)
    end
    if hover_collision.auto_land~=cfg.auto_land then hover_collision:set_auto_land(cfg.auto_land) end
    local changed=false
    for _,key in ipairs({"radius","height","span","lateral","margin","center_margin","center_distance","end_distance","side_distance","land_distance","land_grace"}) do
        if hover_collision[key]~=cfg[key] then hover_collision[key]=cfg[key];changed=true end
    end
    if changed then
        hover_collision.retry_at=nil;hover_collision.land_hits=0;hover_collision.land_next=nil
        hover_collision.land_since=nil;hover_collision.land_driver=nil
    end
    if anti_jitter.fall_stop.enabled~=settings.anti_jitter then anti_jitter.fall_stop:set_enabled(settings.anti_jitter) end
    local wanted=settings.head_camera and "griffin" or "original"
    if camera_mode~=wanted then change_camera_mode(wanted) end
    if settings.camera_auto_yaw then install_yaw_hook() else yaw_state=nil end
    native_pending=false
end
local function apply_native()
    menu.applying_edits=true
    local ok,err=pcall(native_options)
    menu.applying_edits=false
    if not ok then
        native_pending=false;menu.edit_dirty=true
        menu.save_error="设置应用未完成，请修正后重新应用："..tostring(err)
    end
    return ok
end
-- Existing gameplay callers only mark configuration dirty; they never write files.
controls.save=function()
    if not menu.applying_edits then
        menu.edit_dirty=true
        menu.edit_revision=menu.edit_revision+1
    end
    return true
end
menu.queue_edits=function(save,snapshot)
    if not current() then return end
    local ticket={config=menu.clone(snapshot or menu.draft),save=save==true,revision=menu.edit_revision,replace_seats=menu.defaults_draft==true}
    if save then menu.pending_save=ticket else menu.pending_edit=ticket end
    if type(run_once)=="function" then run_once(function() if current() then menu.apply_edits() end end) end
end
menu.changed=function()
    menu.edit_dirty=true;menu.edit_revision=menu.edit_revision+1
    if menu.realtime then menu.queue_edits(false) end
end
menu.apply_edits=function(visual)
    if not current() then return end
    local paused=menu.gameplay_paused()
    if paused and not (visual and menu.photo_active()) then return end
    local ticket=menu.pending_save or menu.pending_edit
    if ticket then
        if ticket.save then
            menu.pending_save=nil
            if menu.pending_edit and menu.pending_edit.revision<=ticket.revision then menu.pending_edit=nil end
        else menu.pending_edit=nil end
        local old_index=settings.seat_index
        local old_anim=settings.rider_anim
        local previous=settings.seat_presets[old_index]
        local old_physical=settings.seat_presets[1]
        local next_config=ticket.config
        if not ticket.replace_seats then
            retain_generated_seats(next_config)
            retain_generated_seats(menu.draft)
        end
        normalize(next_config)
        settings=next_config
        menu.pending_preset=nil
        menu.applying_edits=true
        menu.reindex();menu.pull_values(settings.seat_index)
        menu.applying_edits=false
        native_pending=true
        if ticket.replace_seats then reset_session_pending=true end
        local selected=settings.seat_presets[settings.seat_index]
        local seat_changed=old_index~=settings.seat_index or not equal(old_physical.player,settings.seat_presets[1].player)
            or not equal(previous.player,selected.player)
        if active then
            if seat_changed then active.fall_reset_pending=true end
            if old_index~=settings.seat_index or old_anim~=settings.rider_anim then active.pose_pending=settings.rider_anim end
            for _,a in pairs(active.passengers or {}) do
                local before=previous and previous[a.group] and previous[a.group][a.slot]
                local after=passengers.visual_seat(a.group,a.slot)
                local old_slot=old_physical[a.group] and old_physical[a.group][a.slot]
                local new_slot=settings.seat_presets[1][a.group] and settings.seat_presets[1][a.group][a.slot]
                if old_index~=settings.seat_index or not equal(before,after) or not equal(old_slot,new_slot) then a.fall_reset_pending=true end
                if old_index~=settings.seat_index or not before or before.anim~=after.anim then a.pose_pending=after.anim end
            end
        end
        menu.applied_revision=ticket.revision
        if not paused and not apply_native() then return end
        if ticket.save then
            local ok,result=pcall(json.dump_file,settings_path,settings)
            if ok and result~=false then
                menu.saved=menu.clone(settings)
                menu.edit_dirty=menu.edit_revision~=ticket.revision
                menu.save_error=nil
                if not menu.edit_dirty then menu.defaults_draft=false end
                menu.edit_status="设置已应用并保存"
            else
                menu.edit_dirty=true
                menu.save_error="设置保存失败，当前内容仍在内存中："..tostring(result)
            end
        elseif ticket.discard then menu.edit_status="未保存修改已撤销"
        else menu.edit_status="修改已预览，尚未保存" end
    elseif native_pending and not paused then
        apply_native()
    end
end
menu.edit_toggle=function(key,label)
    local changed,value=menu.toggle(label,menu.draft[key])
    if changed then menu.draft[key]=value;menu.changed() end
    return changed,value
end
-- Reset the editable configuration; disk writes still require explicit save.
menu.restore_defaults=function()
    menu.pending_save=nil;menu.pending_edit=nil;menu.pending_preset=nil
    menu.draft=menu.build_defaults()
    menu.defaults_draft=true
    menu.realtime=false;menu.show_physical=false
    menu.selected_index=2;menu.last_normal=2;menu.confirm_delete=nil
    controls.capture=nil;controls.release_gate=true;controls.previous={}
    menu.save_error=nil
    menu.changed()
    menu.edit_status="默认配置已恢复到草稿，点击应用并保存后生效。"
end
menu.editor=function()
    local highlight=menu.edit_dirty and (menu.edit_revision~=menu.applied_revision or menu.save_error~=nil)
    local styled=highlight and type(imgui.push_style_color)=="function" and type(imgui.pop_style_color)=="function"
    if styled then
        imgui.push_style_color(21,0xff98652b)
        imgui.push_style_color(22,0xffb77d38)
        imgui.push_style_color(23,0xff86551e)
        imgui.push_style_color(0,0xffe8f5ff)
    end
    local save=beta_button("应用并保存###GriffinApplySave")
    if styled then imgui.pop_style_color(4) end
    if save and menu.edit_dirty then menu.queue_edits(true) end
    if imgui.same_line then imgui.same_line() end
    if beta_button("恢复未修改###GriffinDiscardEdits") then
        menu.pending_save=nil;menu.pending_edit=nil
        menu.defaults_draft=false;reset_session_pending=false
        menu.draft=menu.clone(menu.saved)
        menu.selected_index=menu.draft.seat_index
        menu.confirm_delete=nil
        menu.edit_revision=menu.edit_revision+1
        menu.queue_edits(false)
        menu.pending_edit.discard=true
        menu.edit_dirty=false
        menu.edit_status="未保存修改已撤销"
    end
    if imgui.same_line then imgui.same_line() end
    if beta_button("恢复默认配置###GriffinRestoreDefaults") then menu.restore_defaults() end
    if imgui.same_line then imgui.same_line() end
    local changed,value=menu.toggle("实时应用修改###GriffinLiveApply",menu.realtime)
    if changed then
        menu.realtime=value
        if value and menu.edit_dirty then menu.queue_edits(false) end
    end
    if imgui.same_line then imgui.same_line() end
    imgui.text("[?]")
    if type(imgui.is_item_hovered)=="function" and type(imgui.set_tooltip)=="function" and imgui.is_item_hovered() then
        imgui.set_tooltip("方便调试参数，开启后实时应用配置。默认关闭可节省性能。")
    end
    if menu.edit_dirty then imgui.text("有未保存修改；拖动参数不会写入配置文件。") end
    if menu.pending_save then imgui.text("保存已排队，继续游戏或进入照片模式后应用。") end
    if menu.edit_status then imgui.text(menu.edit_status) end
end
end
