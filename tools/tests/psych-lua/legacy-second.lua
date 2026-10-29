assert(legacyPrivate == nil)
legacyPrivate = 'second'
function onCreate()
    assert(legacyShared == 42 and legacyPrivate == 'second')
    print('LUASLICE_SECOND_ISOLATION_OK')
end
function onCustom(id, data)
    if id == 'test:lua-stop' then error('Stopped event reached a later Lua script') end
end

