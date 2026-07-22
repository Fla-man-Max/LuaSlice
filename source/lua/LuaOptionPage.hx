package;

#if FEATURE_LUA_SCRIPTS
typedef LuaOptionPage =
{
  var id:String;
  var title:String;
  var position:Int;
  var items:Array<LuaOptionItem>;
}
#end
