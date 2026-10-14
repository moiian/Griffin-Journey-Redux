-- Griffin Journey Redux: ownership
return function(ctx)
local _ENV=ctx
AntiJitter=require("_GriffinJourneyRedux.antijitter")
anti_jitter=AntiJitter.new({driver=function() return active end,
            passenger_owned=function(d,a)
                return a and a.owner==d.player and a.spawn==d.spawn and passengers.controlled(a.player)==a
                    and owned_player(a,false) and player_fsm(a.player)==a.fsm
            end,
            griffin=function(d)
                local result=d.spawn and d.spawn.result
                return result and result.chara,result and result.go
            end,
            griffin_owned=function(d,ch,go)
                local result=d.spawn and d.spawn.result
                return result and result.chara==ch and result.go==go and ch:get_Valid() and go:get_Valid()
                    and ch:call("get_GameObject()")==go
            end,
            owned=function(d)
                if not alive or state.generation~=generation or not d or active~=d or not owned_player(d,true)
                    or player_fsm(d.player)~=d.fsm then return false end
                local r=d.spawn;local result=r and r.result
                return result and r.owner==d.player and result.go and result.chara
                    and result.go:get_Valid() and result.chara:get_Valid()
                    and result.chara:call("get_GameObject()")==result.go
            end,
            paused=menu.gameplay_paused,time=now,wall=os.time,clock=os.clock,behavior_frame=function() return passengers.frame end,
            can_dump=function() return not active or menu.gameplay_paused() end,
            timing=function()
                local c=core();local p=c and c.properties or {}
                return {nick_delta=p.deltaTime,nick_frame=p.frame,log_sequence=menu.log_io and menu.log_io.sequence or 0}
            end,
            bind=function(d) return menu.route_bind(d) end})
anti_jitter.fall_stop:set_enabled(settings.anti_jitter)
settings.griffin_anti_jitter=false
end
