assert(legacyPrivate == nil)
legacyPrivate = 'second'
function onCreate()
    assert(legacyShared == 42 and legacyPrivate == 'second')
    print('LUASLICE_SECOND_ISOLATION_OK')
end
