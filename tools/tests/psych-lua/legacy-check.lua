assert(legacyPrivate == nil)
local nativeIncomingChecked = false
legacyPrivate = 'first'
function onCreate()
    assert(type(jit) == 'table' and string.find(jit.version, 'LuaJIT'))
    assert(legacyShared == 42 and legacyPrivate == 'first')
    local packed = table.pack(1, nil, 3)
    assert(packed.n == 3 and table.unpack(packed, 3, 3) == 3)
    assert(jsonParse(jsonStringify({answer = 42, flag = true})).answer == 42)
    assert(require('runtime-helper').value == 42)
    local x = getProperty('boyfriend.x')
    assert(setProperty('boyfriend.x', 700) and getProperty('boyfriend.x') == 700)
    assert(setProperties('boyfriend', {x = 710}) and getProperty('boyfriend.x') == 710)
    assert(setProperties({['boyfriend.x'] = 720}) and getProperty('boyfriend.x') == 720)
    assert(property.setMany({['boyfriend.x'] = x}))
    assert(property.getMany({'boyfriend.x'})['boyfriend.x'] == x)
    assert(property.ref('boyfriend.x').get() == x)
    assert(type(tween) == 'table' and type(getmetatable(tween).__call) == 'function')
    assert(LuaSlice.api.find('setProperties').deprecated == false)
    assert(string.find(LuaSlice.api.luaLS(), '@overload', 1, true))
    local path = script.getPath()
    task.run(function()
        task.wait(0.05)
        assert(script.getPath() == path)
        local value = getProperty('boyfriend.x')
        assert(type(value) == 'number')
        assert(getProperties({'boyfriend.x'})['boyfriend.x'] == value)
        assert(setProperties({['boyfriend.x'] = value}))
        print('LUASLICE_TASK_OK')
    end)
    local cancelled = task.run(function() task.wait(1); error('Cancelled task ran') end)
    assert(task.cancel(cancelled))
    LuaSlice.profiler.start()
    getProperty('boyfriend.x')
    assert(LuaSlice.profiler.snapshot().bridgeCalls > 0)
    LuaSlice.profiler.stop()
    print('LUASLICE_CONVENIENCE_OK')
    print('LUASLICE_LEGACY_CREATE_OK')
end
function onDestroy()
    print('LUASLICE_LEGACY_DESTROY_OK')
end

function onCustom(id, data)
    if id == 'test:lua-cancel' then cancelEvent() end
    if id == 'test:lua-stop' then stopEventPropagation() end
    if id ~= 'test:data' then return end
    assert(data.answer == 42 and data.nested.text == 'UTF-8: ł')
    print('LUASLICE_CUSTOM_EVENT_OK')
end

function onNoteIncoming(event)
    assert(event.type == 'NOTE_INCOMING' and event.note ~= nil and type(event.note.strumTime) == 'number')
    if not nativeIncomingChecked then
        nativeIncomingChecked = true
        print('LUASLICE_NATIVE_EVENT_OK')
    end
end

function onNoteHoldDrop(event)
    assert(event.holdNote ~= nil and event.holdNote.sustainLength == 500)
    assert(type(event.holdNote.strumTime) == 'number' and event.holdNote.direction == 0)
    assert(type(event.holdNote.noteData.time) == 'number' and event.holdNote.noteData.length == 500)
    print('LUASLICE_HOLD_EVENT_OK')
end
