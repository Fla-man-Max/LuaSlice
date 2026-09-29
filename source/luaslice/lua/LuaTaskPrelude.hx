package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
class LuaTaskPrelude
{
  public static function source():String
  {
    return '
local tasks = {}
local nextId = 0
local clock = 0
local function resumeTask(id, item, ...)
    local previousPath = __luaTaskPath
    __luaTaskPath = item.path
    local ok, delay = coroutine.resume(item.thread, ...)
    __luaTaskPath = previousPath
    if not ok then
        tasks[id] = nil
        debugPrint("Task error in " .. item.path .. ": " .. tostring(delay))
    elseif coroutine.status(item.thread) == "dead" then
        tasks[id] = nil
    else
        delay = tonumber(delay) or 0
        if delay ~= delay or delay < 0 or delay == math.huge then delay = 0 end
        item.wake = clock + delay
    end
end
task = {}
function task.run(callback, ...)
    assert(type(callback) == "function", "task.run expects a function")
    nextId = nextId + 1
    local id = nextId
    local item = {thread = coroutine.create(callback), wake = clock, path = getCurrentLuaScriptPath()}
    tasks[id] = item
    resumeTask(id, item, ...)
    return id
end
function task.wait(seconds)
    seconds = seconds or 0
    assert(type(seconds) == "number" and seconds == seconds and seconds >= 0 and seconds < math.huge, "task.wait expects finite non-negative seconds")
    return coroutine.yield(seconds)
end
function task.cancel(id)
    local exists = tasks[id] ~= nil
    tasks[id] = nil
    return exists
end
function __luaTaskUpdate(elapsed)
    if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 then return end
    clock = clock + elapsed
    if next(tasks) == nil then return end
    local ready = {}
    for id, item in pairs(tasks) do
        if item.wake <= clock then ready[#ready + 1] = id end
    end
    table.sort(ready)
    for _, id in ipairs(ready) do
        local item = tasks[id]
        if item then resumeTask(id, item) end
    end
end
return true
';
  }
}
#end
