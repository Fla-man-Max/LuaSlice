package luaslice.script;

#if FEATURE_NXSCRIPT_SCRIPTS
import flixel.FlxG;
import funkin.Conductor;
import funkin.Paths;
import funkin.Preferences;
import funkin.play.PlayState;
import funkin.save.Save;
import haxe.Json;
import nx.script.Interpreter;
import sys.io.File;

class NxScriptRuntime implements IScriptRuntime
{
  public final path:String;

  var script:Null<Interpreter>;
  var hookPresence:Map<String, Bool> = [];

  public function new(path:String, owner:Dynamic)
  {
    this.path = path;
    script = new Interpreter(false, false);
    script.enableSandbox();
    script.withParent(owner);
    script.set('state', owner);
    script.set('game', owner);
    script.set('playState', PlayState.instance);
    script.set('FlxG', FlxG);
    script.set('Paths', Paths);
    script.set('Preferences', Preferences);
    script.set('Conductor', Conductor);
    script.set('Save', Save);
    script.set('Json', Json);
    script.run(File.getContent(path), path);
  }

  public function callHook(name:String, args:Array<Dynamic>):Void
  {
    if (script == null) return;

    var present = hookPresence.get(name);
    if (present == null)
    {
      present = script.has(name);
      hookPresence.set(name, present);
    }
    if (!present) return;

    try
    {
      script.call(name, args);
    }
    catch (error:Dynamic)
    {
      trace('[NxScript] ${path} ${name}: ${Std.string(error)}');
    }
  }

  public function destroy():Void
  {
    hookPresence.clear();
    if (script != null)
    {
      script.parent = null;
      script.globals.clear();
      script.natives.clear();
      script.gc();
    }
    script = null;
  }
}
#end
