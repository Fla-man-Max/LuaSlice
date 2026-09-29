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
  var disabledHooks:Map<String, Bool> = [];
  var properties:ScriptPropertyService;
  var tweens:Array<flixel.tweens.FlxTween> = [];

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
    script.setClass(ScriptProfiler);
    properties = new ScriptPropertyService(function(root):Dynamic
    {
      final play = PlayState.instance;
      return switch (root)
      {
        case null | '' | 'state' | 'game': owner;
        case 'playState': play;
        case 'boyfriend' | 'bf': play?.currentStage?.getBoyfriend();
        case 'dad' | 'opponent': play?.currentStage?.getDad();
        case 'gf' | 'girlfriend': play?.currentStage?.getGirlfriend();
        case 'camGame': play?.camGame;
        case 'camHUD': play?.camHUD;
        case 'camCutscene': play?.camCutscene;
        case 'FlxG': FlxG;
        case 'Conductor': Conductor.instance;
        default: ScriptPropertyService.read(owner, root);
      };
    }, message -> trace('[SScript] ${path} property: ${message}'));
    script.set('setProperty', properties.set);
    script.set('getProperty', properties.get);
    script.set('setProperties', properties.setMany);
    script.set('getProperties', function(paths:Array<String>)
    {
      final values:Map<String, Dynamic> = [];
      if (paths != null) for (path in paths) values.set(path, properties.get(path));
      return values;
    });
    script.set('configure', properties.configure);
    script.set('tween', function(target:Dynamic, values:Dynamic, options:Dynamic)
    {
      try
      {
        var created:flixel.tweens.FlxTween = null;
        final duration:Float = options?.duration ?? 1.0;
        created = ScriptTweenService.create(target, values, duration, options?.ease ?? 'linear', function(_)
        {
          tweens.remove(created);
          final complete = options == null ? null : Reflect.field(options, 'onComplete');
          if (complete != null)
          {
            try { Reflect.callMethod(null, complete, []); }
            catch (error:Dynamic) { trace('[SScript] ${path} tween.onComplete: ${error}'); }
          }
        });
        tweens.push(created);
        return created;
      }
      catch (error:Dynamic)
      {
        trace('[SScript] ${path} tween: ${error}');
        return null;
      }
    });
    refreshAliases();
    script.doString(ScriptSource.normalize(File.getContent(path)), path);

    if (script.parsingException != null) throw script.parsingException;
  }

  public function callHook(name:String, args:Array<Dynamic>):Void
  {
    if (script == null || disabledHooks.exists(name)) return;

    var present = hookPresence.get(name);
    if (present == null)
    {
      present = Type.typeof(script.get(name)) == TFunction;
      hookPresence.set(name, present);
    }
    if (!present) return;

    refreshAliases();
    final started = ScriptProfiler.enabled ? haxe.Timer.stamp() : 0;
    final result = script.call(name, args);
    if (ScriptProfiler.enabled) ScriptProfiler.record(path, name, started, !result.succeeded);
    if (!result.succeeded && result.exceptions.length > 0)
    {
      disabledHooks.set(name, true);
      trace('[SScript] ${path} ${name}: ${result.exceptions[0].message}');
    }
  }

  public function destroy():Void
  {
    hookPresence.clear();
    disabledHooks.clear();
    properties?.clear();
    for (tween in tweens) tween.cancel();
    tweens.resize(0);
    script?.destroy();
    script = null;
  }

  function refreshAliases():Void
  {
    if (script == null) return;
    final play = PlayState.instance;
    script.set('playState', play);
    script.set('boyfriend', play?.currentStage?.getBoyfriend());
    script.set('dad', play?.currentStage?.getDad());
    script.set('gf', play?.currentStage?.getGirlfriend());
    script.set('camGame', play?.camGame);
    script.set('camHUD', play?.camHUD);
    script.set('camCutscene', play?.camCutscene);
  }
}
#end
