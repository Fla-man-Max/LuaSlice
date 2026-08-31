package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
import flixel.system.FlxAssets.FlxShader;

typedef LuaShaderTarget =
{
  var target:Dynamic;
  var shader:FlxShader;
  var tag:String;
  var previousShader:Dynamic;
}
#end
