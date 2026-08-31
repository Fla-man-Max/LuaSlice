package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;

typedef LuaMenuData =
{
  var group:FlxTypedGroup<FlxBasic>;
  var items:Array<String>;
  var selected:Int;
  var normalColor:FlxColor;
  var selectedColor:FlxColor;
  var itemSprites:Array<FlxSprite>;
  var mode:String;
}
#end
