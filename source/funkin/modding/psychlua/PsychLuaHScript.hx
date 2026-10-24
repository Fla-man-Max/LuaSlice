package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;

class PsychLuaHScript extends Iris
{
  public final origin:Null<String>;

  public function new(owner:PsychLuaScript, ?origin:String)
  {
    super('', new IrisConfig((origin ?? owner.path + ':haxe'), false, true));
    this.origin = origin;
    var host = owner.host;
    set('game', host.game);
    set('FlxG', flixel.FlxG);
    set('FlxSprite', flixel.FlxSprite);
    set('FlxText', flixel.text.FlxText);
    set('FlxCamera', flixel.FlxCamera);
    set('FlxTween', flixel.tweens.FlxTween);
    set('FlxEase', flixel.tweens.FlxEase);
    set('FlxTimer', flixel.util.FlxTimer);
    set('FlxSound', flixel.sound.FlxSound);
    set('FunkinSprite', funkin.graphics.FunkinSprite);
    set('Paths', funkin.Paths);
    set('PlayState', funkin.play.PlayState);
    set('Conductor', funkin.Conductor);
    set('Preferences', funkin.Preferences);
    set('ShaderFilter', openfl.filters.ShaderFilter);
    set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
    set('Function_Continue', PsychLuaScript.CONTINUE);
    set('Function_Stop', PsychLuaScript.STOP);
    set('Function_StopLua', PsychLuaScript.STOP_LUA);
    set('Function_StopHScript', PsychLuaScript.STOP_HSCRIPT);
    set('Function_StopAll', PsychLuaScript.STOP_ALL);
    set('scriptName', origin ?? owner.path);
    set('modFolder', owner.root);
    set('add', (object:flixel.FlxBasic) -> host.game.add(object));
    set('insert', (position:Int, object:flixel.FlxBasic) -> host.game.insert(position, object));
    set('remove', (object:flixel.FlxBasic, splice:Bool = false) -> host.game.remove(object, splice));
    set('getVar', (name:String) -> host.variables.get(name));
    set('setVar', (name:String, value:Dynamic) -> { host.variables.set(name, value); return value; });
    set('removeVar', (name:String) -> host.variables.remove(name));
    set('getModSetting', (tag:String, ?modName:String) -> PsychLuaAPI.modSetting(owner.root, tag, modName));
    set('createCallback', (name:String, callback:Dynamic) -> {
      if (!Reflect.isFunction(callback)) throw 'Callback must be a function: $name';
      if (owner.closed) throw 'The Lua script that loaded this HScript is closed';
      owner.register(name, callback);
      PsychLuaAPI.names.set(name, true);
    });
    set('createGlobalCallback', (name:String, callback:Dynamic) -> {
      if (!Reflect.isFunction(callback)) throw 'Callback must be a function: $name';
      for (script in host.scripts) if (!script.closed) script.register(name, callback);
      PsychLuaAPI.names.set(name, true);
    });
    set('debugPrint', (message:Dynamic) -> host.report(Std.string(message)));
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
