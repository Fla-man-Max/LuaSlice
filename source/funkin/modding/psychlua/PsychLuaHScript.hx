package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;

class PsychLuaHScript extends Iris
{
  public function new(owner:PsychLuaScript)
  {
    super('', new IrisConfig(owner.path + ':haxe', false, true));
    set('game', owner.host.game);
    set('FlxG', flixel.FlxG);
    set('FlxSprite', flixel.FlxSprite);
    set('FlxText', flixel.text.FlxText);
    set('FlxCamera', flixel.FlxCamera);
    set('FlxTween', flixel.tweens.FlxTween);
    set('FlxEase', flixel.tweens.FlxEase);
    set('FlxTimer', flixel.util.FlxTimer);
    set('Paths', funkin.Paths);
    set('PlayState', funkin.play.PlayState);
    set('Conductor', funkin.Conductor);
    set('ShaderFilter', openfl.filters.ShaderFilter);
    set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
    set('getVar', (name:String) -> owner.host.variables.get(name));
    set('setVar', (name:String, value:Dynamic) -> { owner.host.variables.set(name, value); return value; });
    set('removeVar', (name:String) -> owner.host.variables.remove(name));
    set('createCallback', (name:String, callback:Dynamic) -> {
      if (!Reflect.isFunction(callback)) throw 'Callback must be a function: $name';
      owner.register(name, callback);
      PsychLuaAPI.names.set(name, true);
    });
    set('debugPrint', (message:Dynamic) -> owner.host.report(Std.string(message)));
  }

  public function run(code:String, variables:Dynamic):Dynamic
  {
    if (variables != null) for (name in Reflect.fields(variables)) set(name, Reflect.field(variables, name));
    scriptCode = code;
    parse(true);
    return execute();
  }
}
#end
