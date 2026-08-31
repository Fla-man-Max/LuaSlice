package luaslice.script;

#if FEATURE_SSCRIPT_SCRIPTS
import flixel.FlxG;
import funkin.Conductor;
import funkin.Paths;
import funkin.Preferences;
import funkin.play.PlayState;
import funkin.save.Save;
import haxe.Json;
import hscript.SScript;
import sys.io.File;

class SScriptRuntime implements IScriptRuntime
{
  public final path:String;

  var script:Null<SScript>;
  var hookPresence:Map<String, Bool> = [];

  public function new(path:String, owner:Dynamic)
  {
    this.path = path;
    script = new SScript('', true, false);
    script.set('state', owner);
    script.set('game', owner);
    script.set('playState', PlayState.instance);
    script.setClass(FlxG);
    script.setClass(Paths);
    script.setClass(Preferences);
    script.setClass(Conductor);
    script.setClass(Save);
    script.setClass(Json);
    script.doString(File.getContent(path), path);

    if (script.parsingException != null) throw script.parsingException;
  }

  public function callHook(name:String, args:Array<Dynamic>):Void
  {
    if (script == null) return;

    var present = hookPresence.get(name);
    if (present == null)
    {
      present = Type.typeof(script.get(name)) == TFunction;
      hookPresence.set(name, present);
    }
    if (!present) return;

    final result = script.call(name, args);
    if (!result.succeeded && result.exceptions.length > 0)
    {
      trace('[SScript] ${path} ${name}: ${result.exceptions[0].message}');
    }
  }

  public function destroy():Void
  {
    hookPresence.clear();
    script?.destroy();
    script = null;
  }
}
#end
