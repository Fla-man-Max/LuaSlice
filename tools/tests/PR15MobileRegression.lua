local ok, failure = pcall(function()
assert(type(mobile) == 'table', 'Mobile helpers are missing')
assert(mobile.has('buttons') and mobile.has('camera'), 'Mobile callbacks are incomplete')
assert(type(mobile.isAvailable()) == 'boolean')
assert(type(mobile.isTouchSupported()) == 'boolean')
assert(mobile.button('pr15-button', {x=21, y=34, width=50, height=60, alpha=0.4}))
assert(mobile.exists('pr15-button'))
assert(mobile.setPosition('pr15-button', 31, 45))
assert(mobile.setSize('pr15-button', 80, 90))
assert(mobile.setCamera('pr15-button', 'hud'))
assert(mobile.setVisible('pr15-button', false))
assert(not mobile.pressed('pr15-button'))
assert(mobile.removeAll() and not mobile.exists('pr15-button'))
assert(not mobile.layout({{tag='pr15-rollback'}, {tag=''}}))
assert(not mobile.exists('pr15-rollback'))
assert(not mobile.layout({{tag='pr15-duplicate'}, {tag='pr15-duplicate'}}))
assert(not mobile.exists('pr15-duplicate'))
assert(mobile.button('pr15-existing', {}))
assert(not mobile.layout({{tag='pr15-existing'}}))
assert(mobile.exists('pr15-existing'))
assert(mobile.removeAll())
local callback = function() end
assert(timer.after(60, callback) ~= timer.after(60, callback), 'Timer tags collide for the same callback')
local seen = 0
song.atBeat(8123, function() seen = seen + 1 end)
song.atBeat(8123, function() seen = seen + 2 end)
onBeatHit(8123)
assert(seen == 3, 'Beat callbacks overwrite each other')
song.atStep(8123, function() seen = seen + 4 end)
song.atStep(8123, function() seen = seen + 8 end)
onStepHit(8123)
assert(seen == 15, 'Step callbacks overwrite each other')
local events = 0
event.once('update', function() events = events + 1 end)
event.once('update', function() events = events + 1 end)
local update = function() events = events + 10 end
event.on('update', update)
onUpdate(0)
assert(events == 12, 'Removing an event skipped the next callback')
assert(event.off('update', update))
onUpdate(0)
assert(events == 12, 'Removed event still runs')
local before = _G.jit
_G.jit = nil
assert(LuaSlice.runtimeInfo().runtime == _VERSION and LuaSlice.runtimeInfo().jit == false)
_G.jit = before
local path = _G.getCurrentLuaScriptPath
_G.getCurrentLuaScriptPath = function() return 'C:\\mods\\example.lua' end
assert(script.getName() == 'example.lua')
_G.getCurrentLuaScriptPath = path
local raw = _G.setLuaWindowTitle
_G.setLuaWindowTitle = nil
assert(window.setTitle('missing callback') == false)
_G.setLuaWindowTitle = raw
local docs = LuaSlice.api.luaLS()
assert(not string.find(docs, '\\n', 1, true), 'Generated LuaLS contains escaped newlines')
assert(loadstring(docs), 'Generated LuaLS is not valid Lua')
assert(LuaSlice.api.find('mobile.layout'))
assert(string.find(LuaSlice.api.docs(), '\n## mobile.layout', 1, true))
assert(mobile.button('pr15-cleanup', {}))
print('PR15_MOBILE_LUA_OK')
end)
if not ok then debugPrint('PR15_MOBILE_REGRESSION_FAILED: ' .. tostring(failure)) end
