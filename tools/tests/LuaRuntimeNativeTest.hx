import hxluajit.Lua;
import hxluajit.LuaL;
import luaslice.lua.LuaRuntime;

class LuaRuntimeNativeTest
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    var state = LuaL.newstate();
    check(state != null, 'LuaJIT did not create a state');
    LuaRuntime.openLibraries(state);
    check(Lua.gettop(state) == 0, 'Library setup changed the Lua stack');
    Lua.register(state, 'nativeSum', cpp.Callable.fromStaticFunction(LuaRuntimeNativeCallbacks.sum));
    check(LuaL.dostring(state, 'assert(nativeSum(13, 29) == 42)') == Lua.OK, 'A native Lua callback did not execute');
    var regularMethod = Reflect.field(LuaRuntimeNativeCallbacks, 'label');
    check(regularMethod != null && Reflect.callMethod(null, regularMethod, []) == 'LuaJIT', 'Normal bridge methods lost reflection');
    check(Reflect.field(LuaRuntimeNativeCallbacks, 'sum') == null, 'Native callback was exposed through reflection');
    check(Type.resolveClass('LuaRuntimeNativeCallbacks') == LuaRuntimeNativeCallbacks, 'Native bridge runtime class identity changed');
    #if polymod
    polymod.Polymod.addImportAlias('LuaRuntimeNativeCallbacks', LuaRuntimeNativeCallbacks);
    check(polymod.hscript._internal.PolymodScriptClass.importOverrides.get('LuaRuntimeNativeCallbacks') == LuaRuntimeNativeCallbacks,
      'Polymod lost the public bridge alias');
    @:privateAccess polymod.hscript._internal.PolymodScriptClass.registerScriptClassByString(
      'import LuaRuntimeNativeCallbacks; class NativeBridgeScriptProbe { public static function readLabel() { return LuaRuntimeNativeCallbacks.label(); } }',
      'native-bridge-probe.hxc');
    check(polymod.hscript._internal.PolymodScriptClass.callScriptClassStaticFunction('NativeBridgeScriptProbe', 'readLabel', []) == 'LuaJIT',
      'HScript could not call the public native bridge alias');
    #end
    Lua.pushinteger(state, 17);
    Lua.pushinteger(state, 29);
    check(LuaRuntime.absoluteIndex(state, -1) == 2, 'Relative stack index was not resolved');
    check(LuaRuntime.absoluteIndex(state, 1) == 1, 'Absolute stack index changed');
    check(LuaRuntime.absoluteIndex(state, Lua.REGISTRYINDEX) == Lua.REGISTRYINDEX, 'Registry pseudo-index changed');
    Lua.settop(state, 0);
    check(LuaL.dostring(state, 'local t = table.pack(4, 8); assert(t.n == 2); assert(table.unpack(t) == 4); assert(type(luaRuntime) == "string")') == Lua.OK,
      'Lua compatibility library initialization failed');
    hxluajit.wrapper.LuaConverter.toLua(state, {label: 'Lua', values: [4, 8], enabled: true});
    var roundTrip:Dynamic = hxluajit.wrapper.LuaConverter.fromLua(state, -1);
    check(roundTrip.label == 'Lua' && roundTrip.enabled == true && roundTrip.values[1] == 8, 'Native wrapper table conversion failed');
    Lua.settop(state, 0);
    check(LuaL.dostring(state, 'function double(x) return x * 2 end') == Lua.OK, 'Could not create a Lua function');
    Lua.getglobal(state, 'double');
    var luaFunction:hxluajit.wrapper.LuaFunction = hxluajit.wrapper.LuaConverter.fromLua(state, -1);
    check(luaFunction.call([21])[0] == 42, 'Native wrapper could not call a Lua function');
    luaFunction.dispose();
    #if FEATURE_PSYCH_LUA
    var input:Dynamic = {label: 'Lua', values: [4, 8], enabled: true};
    check(funkin.modding.psychlua.PsychLuaConvert.toLua(state, input), 'Could not marshal a Lua table');
    var output:Dynamic = funkin.modding.psychlua.PsychLuaConvert.fromLua(state, -1);
    check(output.label == 'Lua' && output.enabled == true, 'Lua table fields did not round trip');
    var values:Array<Dynamic> = output.values;
    check(values.length == 2 && values[0] == 4 && values[1] == 8, 'Lua array values did not round trip');
    check(Lua.gettop(state) == 1, 'Reading a Lua table changed the stack depth');
    Lua.settop(state, 0);
    #end
    Lua.close(state);
    check(Reflect.field(LuaRuntime, 'openLibraries') == null, 'Native Lua state was exposed through reflection');
    Sys.println('LUA_RUNTIME_NATIVE_OK');
  }
}

typedef LuaRuntimeNativeCallbacks = LuaRuntimeNativeCallbackImpl;

@:native('LuaRuntimeNativeCallbacks')
private final class LuaRuntimeNativeCallbackImpl
{
  public static function label():String { return 'LuaJIT'; }

  @:unreflective
  public static function sum(state:cpp.RawPointer<hxluajit.Types.Lua_State>):Int
  {
    Lua.pushnumber(state, Lua.tonumber(state, 1) + Lua.tonumber(state, 2));
    return 1;
  }
}
