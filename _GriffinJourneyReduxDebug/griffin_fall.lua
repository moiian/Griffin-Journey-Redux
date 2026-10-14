-- Reuse the release fall-control engine for the optional exact Griffin scope.
return function(FallStop,env)
    local manager
    local options=setmetatable({label="狮鹫",group="griffin",resolve_actor=function(d)
        local ch,go=env.griffin(d)
        assert(ch and go and (not manager.character or manager.character==ch and manager.go==go),"精确狮鹫实例变化")
        manager.character=ch;manager.go=go
        return ch,function()
            manager:check_driver(d)
            return env.griffin_owned(d,ch,go)
        end
    end},{__index=env})
    manager=FallStop.new(options)
    return manager
end
