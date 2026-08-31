package luaslice.script;

interface IScriptRuntime
{
  public final path:String;

  public function callHook(name:String, args:Array<Dynamic>):Void;

  public function destroy():Void;
}
