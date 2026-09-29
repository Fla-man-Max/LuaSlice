package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import hxluajit.Lua;
import hxluajit.LuaL;
import hxluajit.Types.Lua_State;
import funkin.modding.psychlua.PsychLuaConvert as Convert;

class PsychLuaScript
{
  public static inline var CONTINUE = '##PSYCHLUA_FUNCTIONCONTINUE';
  public static inline var STOP = '##PSYCHLUA_FUNCTIONSTOP';
  public static inline var STOP_LUA = '##PSYCHLUA_FUNCTIONSTOPLUA';
  public static inline var STOP_ALL = '##PSYCHLUA_FUNCTIONSTOPALL';
  static var nextId:Int = 0;
  static final instances:Map<Int, PsychLuaScript> = [];
  final callbacks:Map<String, Dynamic> = [];
  public final id:Int;
  public final path:String;
  public final root:String;
  public final host:PsychLuaHost;
  public var lua(default, null):cpp.RawPointer<Lua_State>;
  public var closed:Bool = false;
  public var depth(default, null):Int = 0;
  public var api:PsychLuaAPI;
  var destroying:Bool = false;
  final reported:Map<String, Bool> = [];

  public function new(host:PsychLuaHost, path:String, root:String)
  {
    this.host = host;
    this.path = path;
    this.root = root;
    id = ++nextId;
    lua = LuaL.newstate();
    if (lua == null) throw 'Could not create Lua state for $path';
    luaslice.lua.LuaRuntime.openLibraries(lua);
    instances.set(id, this);
    execute("function __psychWrap(fn) return function(...) local ok, value = fn(...) if not ok then error(value, 2) end return value end end; unpack = unpack or table.unpack; math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end", '@bridge');
    PsychLuaAPI.register(this);
    set('Function_Continue', CONTINUE);
    set('Function_Stop', STOP);
    set('Function_StopLua', STOP_LUA);
    set('Function_StopAll', STOP_ALL);
    set('Function_StopHScript', '##PSYCHLUA_FUNCTIONSTOPHSCRIPT');
    set('version', '1.0.4');
    set('vSliceVersion', '0.8.6');
    set('luaSliceVersion', funkin.util.Constants.LUASLICE_VERSION);
    set('scriptName', path);
    set('modFolder', root);
    set('luaDebugMode', false);
    set('luaDeprecatedWarnings', true);
    set('__psychModulePath', root + '/?.luap;' + root + '/?/init.luap;' + root + '/?.lua;' + root + '/?/init.lua');
    execute("package.path = __psychModulePath .. ';' .. package.path", '@module-path');
    host.updateGlobals(this);
  }

  public function register(name:String, callback:Dynamic):Void
  {
    callbacks.set(name, callback);
    Lua.getglobal(lua, '__psychWrap');
    Lua.pushnumber(lua, id);
    Lua.pushstring(lua, name);
    Lua.pushcclosure(lua, cpp.Callable.fromStaticFunction(dispatchCallback), 2);
    if (Lua.pcall(lua, 1, 1, 0) != Lua.OK) throw 'Could not register Lua callback: $name';
    Lua.setglobal(lua, name);
  }

  static function dispatchCallback(state:cpp.RawPointer<Lua_State>):Int
  {
    var top = Lua.gettop(state);
    try
    {
      var owner = instances.get(Std.int(Lua.tonumber(state, Lua.upvalueindex(1))));
      var name = Std.string(Lua.tostring(state, Lua.upvalueindex(2)));
      if (owner == null || owner.closed) throw 'Script is closed';
      var callback = owner.callbacks.get(name);
      if (callback == null) throw 'Callback not found: $name';
      var args:Array<Dynamic> = [];
      for (index in 1...(top + 1)) args.push(Convert.fromLua(state, index));
      var result = Reflect.callMethod(null, callback, args);
      Lua.pushboolean(state, 1);
      Convert.toLua(state, result);
      return 2;
    }
    catch (error:Dynamic)
    {
      Lua.settop(state, top);
      Lua.pushboolean(state, 0);
      Lua.pushstring(state, Std.string(error));
      return 2;
    }
  }

  public function compile(source:String):Bool
  {
    if (source.length > 0 && source.charCodeAt(0) == 0xFEFF) source = source.substr(1);
    var top = Lua.gettop(lua);
    var result = LuaL.loadstring(lua, source);
    if (result != Lua.OK) report('parse', Std.string(Lua.tostring(lua, -1)));
    Lua.settop(lua, top);
    return result == Lua.OK;
  }

  public function execute(source:String, label:String):Bool
  {
    if (closed || lua == null) return false;
    if (source.length > 0 && source.charCodeAt(0) == 0xFEFF) source = source.substr(1);
    var top = Lua.gettop(lua);
    depth++;
    var result = LuaL.loadstring(lua, source);
    if (result == Lua.OK) result = Lua.pcall(lua, 0, 0, 0);
    if (result != Lua.OK) report(label, Std.string(Lua.tostring(lua, -1)));
    Lua.settop(lua, top);
    depth--;
    return result == Lua.OK;
  }

  public function call(name:String, args:Array<Dynamic>):Dynamic
  {
    if (closed || lua == null) return CONTINUE;
    var top = Lua.gettop(lua);
    Lua.getglobal(lua, name);
    if (Lua.type(lua, -1) != Lua.TFUNCTION)
    {
      Lua.settop(lua, top);
      return CONTINUE;
    }
    depth++;
    var result:Dynamic = CONTINUE;
    try
    {
      for (arg in args) if (!Convert.toLua(lua, arg)) Lua.pushnil(lua);
      var status = Lua.pcall(lua, args.length, 1, 0);
      if (status == Lua.OK) result = Convert.fromLua(lua, -1);
      else report(name, Std.string(Lua.tostring(lua, -1)));
    }
    catch (error:Dynamic) report(name, Std.string(error));
    Lua.settop(lua, top);
    depth--;
    return result == null ? CONTINUE : result;
  }

  public function set(name:String, value:Dynamic):Void
  {
    if (closed || lua == null) return;
    var top = Lua.gettop(lua);
    try
    {
      if (!Convert.toLua(lua, value)) Lua.pushnil(lua);
      Lua.setglobal(lua, name);
    }
    catch (error:Dynamic)
    {
      Lua.settop(lua, top);
      throw error;
    }
  }

  public function get(name:String):Dynamic
  {
    if (closed || lua == null) return null;
    var top = Lua.gettop(lua);
    Lua.getglobal(lua, name);
    try
    {
      var value = Convert.fromLua(lua, -1);
      Lua.settop(lua, top);
      return value;
    }
    catch (error:Dynamic)
    {
      Lua.settop(lua, top);
      throw error;
    }
  }

  public function report(hook:String, message:String):Void
  {
    var key = hook + ':' + message;
    if (reported.exists(key)) return;
    reported.set(key, true);
    host.report('[$path][$hook] $message');
  }

  public function destroy():Void
  {
    if (lua == null || destroying) return;
    if (depth != 0) { closed = true; return; }
    destroying = true;
    if (!closed) call('onDestroy', []);
    closed = true;
    host.releaseOwned(this);
    api?.destroy();
    api = null;
    callbacks.clear();
    instances.remove(id);
    Lua.close(lua);
    lua = null;
  }
}
#end
