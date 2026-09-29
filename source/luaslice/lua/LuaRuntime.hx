package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
import hxluajit.Lua;
import hxluajit.LuaL;
import hxluajit.Types.Lua_State;

class LuaRuntime
{
  public static inline function absoluteIndex(state:cpp.RawPointer<Lua_State>, index:Int):Int
  {
    return index > 0 || index <= Lua.REGISTRYINDEX ? index : Lua.gettop(state) + index + 1;
  }

  public static function openLibraries(state:cpp.RawPointer<Lua_State>):Void
  {
    if (state == null) throw 'Could not create LuaJIT state';
    LuaL.openlibs(state);
    var top = Lua.gettop(state);
    var result = LuaL.dostring(state, "table.unpack = table.unpack or unpack; table.pack = table.pack or function(...) return { n = select('#', ...), ... } end; luaRuntime = jit.version");
    if (result != Lua.OK)
    {
      var message = Std.string(Lua.tostring(state, -1));
      Lua.settop(state, top);
      throw 'Could not initialize LuaJIT compatibility helpers: ' + message;
    }
    Lua.settop(state, top);
  }
}
#end
