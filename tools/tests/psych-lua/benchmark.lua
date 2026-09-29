function onCreate()
    local runtime = jit and jit.version or _VERSION
    local x = getProperty('boyfriend.x')
    for round = 1, 3 do
        local sum = 0
        local started = os.clock()
        for i = 1, 1000000 do sum = sum + i end
        local arithmetic = (os.clock() - started) * 1000
        started = os.clock()
        for i = 1, 10000 do
            setProperty('boyfriend.x', x)
            assert(getProperty('boyfriend.x') == x)
        end
        local bridge = (os.clock() - started) * 1000
        assert(sum == 500000500000)
        print('LUA_BENCHMARK ' .. runtime .. ' round=' .. round .. ' arithmeticMs=' .. arithmetic .. ' propertyPairsMs=' .. bridge)
    end
    print('LUA_BENCHMARK_DONE')
end
