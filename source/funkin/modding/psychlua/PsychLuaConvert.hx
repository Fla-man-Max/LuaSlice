package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import hxluajit.Lua;
import hxluajit.Types.Lua_State;
import hxluajit.wrapper.LuaConverter;

class PsychLuaConvert
{
  public static function toLua(state:cpp.RawPointer<Lua_State>, value:Dynamic, depth:Int = 0):Bool
  {
    if (depth > 32) throw 'Lua value nesting exceeds 32 levels (possibly a cycle)';
    if (value == null) Lua.pushnil(state);
    else if (Std.isOfType(value, Bool)) Lua.pushboolean(state, value ? 1 : 0);
    else if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) Lua.pushnumber(state, value);
    else if (Std.isOfType(value, String)) Lua.pushstring(state, Std.string(value));
    else if (Std.isOfType(value, Array))
    {
      var array:Array<Dynamic> = cast value;
      Lua.createtable(state, array.length, 0);
      for (i in 0...array.length) { toLua(state, array[i], depth + 1); Lua.rawseti(state, -2, i + 1); }
    }
    else if (Type.typeof(value) == Type.ValueType.TObject)
    {
      Lua.newtable(state);
      for (field in Reflect.fields(value))
      {
        var item = Reflect.field(value, field);
        if (Reflect.isFunction(item)) continue;
        toLua(state, item, depth + 1);
        Lua.setfield(state, -2, field);
      }
    }
    else Lua.pushnil(state);
    return true;
  }

  public static function fromLua(state:cpp.RawPointer<Lua_State>, index:Int, depth:Int = 0):Dynamic
  {
    if (depth > 32) throw 'Lua value nesting exceeds 32 levels (possibly a cycle)';
    var type = Lua.type(state, index);
    if (type == Lua.TBOOLEAN || type == Lua.TNUMBER || type == Lua.TSTRING) return LuaConverter.fromLua(state, index);
    if (type == Lua.TTABLE)
    {
        var absolute = luaslice.lua.LuaRuntime.absoluteIndex(state, index);
        var object:Dynamic = {};
        var values:Map<Int, Dynamic> = [];
        var arrayOnly = true;
        var count = 0;
        var max = 0;
        Lua.pushnil(state);
        while (Lua.next(state, absolute) != 0)
        {
          var value = fromLua(state, -1, depth + 1);
          if (Lua.type(state, -2) == Lua.TNUMBER)
          {
            var number = Lua.tonumber(state, -2);
            var key = Std.int(number);
            if (key > 0 && number == key)
            {
              values.set(key, value);
              max = Std.int(Math.max(max, key));
              count++;
            }
            else { Reflect.setField(object, Std.string(number), value); arrayOnly = false; }
          }
          else if (Lua.type(state, -2) == Lua.TSTRING)
          {
            Reflect.setField(object, Std.string(Lua.tostring(state, -2)), value);
            arrayOnly = false;
          }
          else throw 'Lua table keys must be strings or numbers';
          Lua.pop(state, 1);
        }
        if (arrayOnly && max == count) return [for (i in 1...(max + 1)) values.get(i)];
        else
        {
          for (key => value in values) Reflect.setField(object, Std.string(key), value);
          return object;
        }
    }
    return null;
  }
}
#end
