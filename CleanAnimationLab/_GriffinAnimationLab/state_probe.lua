-- Read-only snapshots. No hooks, setters, action requests or retained native refs.
local M={}
local function vector(v)
    assert(v,"坐标不可用")
    return {x=v.x,y=v.y,z=v.z}
end
local function reader(row)
    row.errors={}
    return function(key,fn)
        local ok,value=pcall(fn)
        if ok and value~=nil then row[key]=value
        else row.errors[key]=ok and "unavailable" or tostring(value) end
    end
end
function M.base_layer(ch)
    local layer=assert(ch:call("get_Motion()"):call("getLayer(System.UInt32)",0),"没有基础层")
    local row={}
    local read=reader(row)
    read("enabled",function() return layer:call("get_Enabled()") end)
    read("bank",function() return layer:call("get_MotionBankID()") end)
    read("id",function() return layer:call("get_MotionID()") end)
    read("frame",function() return layer:call("get_Frame()") end)
    return row
end
-- Small numeric snapshot for native-call boundaries; never retain native refs in rows.
function M.boundary(instance,isolation,phase)
    local ch=instance.chara
    local d=isolation.active
    local row={time=os.clock(),phase=phase,character=tostring(ch:get_address()),
        mode=d and (d.recovering and "recovering" or d.released and "refreshing" or "isolated") or "native",
        interval=d and d.serial or isolation.serial or 0,requested_clip=d and d.clip}
    local read=reader(row)
    read("position",function() return vector(ch:call("get_Transform()"):call("get_UniversalPosition()")) end)
    read("scene_position",function() return vector(ch:call("get_Transform()"):call("get_Position()")) end)
    read("context_universal",function() return vector(ch:get_field("<PosRotContext>k__BackingField"):call("get_Pos()")) end)
    read("controller_scene",function() return vector(ch:get_field("<AdjustTerrain>k__BackingField").MainCharacterController:call("get_Position()")) end)
    read("action",function() return ch:call("get_ActionManager()").CurrentAction.Name end)
    read("fsm_enabled",function() return ch:call("get_ActionManager()").Fsm:call("get_Enabled()") end)
    read("root_motion",function() return ch:call("get_Motion()"):call("get_RootMotion()") end)
    read("base_layer",function() return M.base_layer(ch) end)
    return row
end
function M.read(instance,isolation,phase)
    local d=isolation.active
    local row={time=os.clock(),phase=phase,mode=d and (d.recovering and "recovering" or d.released and "refreshing" or "isolated") or "native",
        interval=d and d.serial or isolation.serial or 0,blocked=isolation.blocked,errors={}}
    local function read(key,fn)
        local ok,value=pcall(fn)
        if ok and value~=nil then row[key]=value
        else row.errors[key]=ok and "unavailable" or tostring(value) end
    end
    if not instance then row.errors.instance="未绑定";return row end
    local ch=instance.chara
    local ok,valid=pcall(function() return instance.go:get_Valid() and ch:get_Valid() end)
    if not ok or not valid then row.errors.instance="实例失效";return row end
    row.character=tostring(ch:get_address())
    read("position",function() return vector(ch:call("get_Transform()"):call("get_UniversalPosition()")) end)
    read("scene_position",function() return vector(ch:call("get_Transform()"):call("get_Position()")) end)
    read("context_universal",function() return vector(ch:get_field("<PosRotContext>k__BackingField"):call("get_Pos()")) end)
    read("controller_scene",function()
        local terrain=assert(ch:get_field("<AdjustTerrain>k__BackingField"))
        return vector(terrain.MainCharacterController:call("get_Position()"))
    end)
    read("ground",function() return ch:call("get_IsGround()") end)
    read("flight",function() return ch:call("get_IsFlight()") end)
    read("sec_fall",function() return ch:get_field("SecFall") end)
    read("action",function() return ch:call("get_ActionManager()").CurrentAction.Name end)
    read("root_motion",function() return ch:call("get_Motion()"):call("get_RootMotion()") end)
    read("fsm_enabled",function() return ch:call("get_ActionManager()").Fsm:call("get_Enabled()") end)
    read("base_layer",function() return M.base_layer(ch) end)
    read("landing",function()
        local l=assert(ch:get_field("<LandingProcessor>k__BackingField"))
        return {object_ground=l:get_field("<IsObjectGround>k__BackingField"),
            keep_ground=l:get_field("<IsKeepGround>k__BackingField"),
            previous_keep_ground=l:get_field("<IsPrevKeepGround>k__BackingField"),
            last_ground_universal=vector(l:get_field("<LastGroundPosition>k__BackingField"))}
    end)
    local flight
    read("flight_owned",function()
        flight=assert(ch:call("get_FlightCtrl()"))
        assert(flight:call("get_CachedCharacter()")==ch,"飞控归属变化")
        return true
    end)
    if row.flight_owned then
        read("flight_action",function() return flight:call("get_IsFlightAction()") end)
        for _,name in ipairs({"FlightMoveVector","FlightMoveOffset","NowISMoveVector","ISMoveVector","HoveringAttitudeMoveVec","PrevMovePos","MoveOldPos"}) do
            read(name,function() return vector(flight:get_field(name)) end)
        end
        read("old_fly_speed_xz",function() return flight:get_field("OldFlySpeedXZ") end)
    end
    if d then row.clip=d.clip;row.original_root=d.original_root;row.original_fsm=d.original_enabled end
    return row
end
return M
