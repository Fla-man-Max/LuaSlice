package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.Iris.IrisCall;
import crowplexus.hscript.Expr;
import funkin.util.ReflectUtil;
import polymod.hscript._internal.PolymodScriptClass;

class PsychLuaHScript extends Iris
{
  public final owner:PsychLuaScript;
  public final origin:Null<String>;
  public var lastRunSucceeded(default, null):Bool = false;
  var depth:Int = 0;
  var destroyRequested:Bool = false;

  public function new(owner:PsychLuaScript, ?origin:String)
  {
    super('', new IrisConfig(origin ?? owner.path + ':haxe', false, false));
    this.owner = owner;
    this.origin = origin;
    interp = new PsychLuaHScriptInterp(message -> owner.host.report('[HScript][$name] $message'));
    interp.showPosOnLog = false;
    preset();
    set('Reflect', ReflectUtil);
    set('Type', ReflectUtil);
    set('game', owner.host.game);
    set('FlxG', flixel.FlxG);
    set('FlxSprite', flixel.FlxSprite);
    set('FlxText', flixel.text.FlxText);
    set('FlxCamera', flixel.FlxCamera);
    set('FlxTween', flixel.tweens.FlxTween);
    set('FlxEase', flixel.tweens.FlxEase);
    set('FlxTimer', flixel.util.FlxTimer);
    set('FlxSound', flixel.sound.FlxSound);
    set('Paths', funkin.Paths);
    set('PlayState', funkin.play.PlayState);
    set('Conductor', funkin.Conductor);
    set('Assets', funkin.Assets);
    set('Preferences', funkin.Preferences);
    set('Constants', funkin.util.Constants);
    set('FunkinSprite', funkin.graphics.FunkinSprite);
    set('FlxObject', flixel.FlxObject);
    set('FlxMath', flixel.math.FlxMath);
    set('FlxPoint', flixel.math.FlxPoint.FlxBasePoint);
    set('StringMap', haxe.ds.StringMap);
    set('IntMap', haxe.ds.IntMap);
    set('Json', haxe.Json);
    set('Lambda', Lambda);
    set('getFlxColor', (value:String) -> flixel.util.FlxColor.fromString(value));
    set('ShaderFilter', openfl.filters.ShaderFilter);
    set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
    set('getVar', (name:String, fallback:Dynamic = null) -> owner.host.variables.exists(name) ? owner.host.variables.get(name) : fallback);
    set('setVar', (name:String, value:Dynamic) -> { owner.host.variables.set(name, value); return value; });
    set('removeVar', (name:String) -> owner.host.variables.remove(name));
    set('Function_Continue', PsychLuaScript.CONTINUE);
    set('Function_Stop', PsychLuaScript.STOP);
    set('Function_StopLua', PsychLuaScript.STOP_LUA);
    set('Function_StopHScript', PsychLuaScript.STOP_HSCRIPT);
    set('Function_StopAll', PsychLuaScript.STOP_ALL);
    set('scriptName', origin ?? owner.path);
    set('modFolder', owner.root);
    set('add', (object:flixel.FlxBasic) -> owner.host.game.add(object));
    set('insert', (position:Int, object:flixel.FlxBasic) -> owner.host.game.insert(position, object));
    set('remove', (object:flixel.FlxBasic, splice:Bool = false) -> owner.host.game.remove(object, splice));
    set('getModSetting', (tag:String, modName:String = null) -> PsychLuaAPI.modSetting(owner.root, tag, modName));
    set('createCallback', (name:String, callback:Dynamic) -> {
      if (!Reflect.isFunction(callback)) throw 'Callback must be a function: $name';
      owner.register(name, callbackWrapper(name, callback));
      PsychLuaAPI.names.set(name, true);
    });
    set('createGlobalCallback', (name:String, callback:Dynamic) -> {
      if (!Reflect.isFunction(callback)) throw 'Callback must be a function: $name';
      var wrapped = callbackWrapper(name, callback);
      for (script in owner.host.scripts) if (!script.closed) script.register(name, wrapped);
      PsychLuaAPI.names.set(name, true);
    });
    set('debugPrint', (message:Dynamic) -> owner.host.report(Std.string(message)));
  }

  function callbackWrapper(name:String, callback:Dynamic):Dynamic
  {
    return Reflect.makeVarArgs(args -> {
      depth++;
      var result:Dynamic = null;
      try
      {
        if (interp == null || destroyRequested) throw 'HScript has been destroyed';
        result = Reflect.callMethod(null, callback, args);
      }
      catch (error:Dynamic) { reportError('callback $name', error); }
      finishInvocation();
      return result;
    });
  }

  function finishInvocation():Void
  {
    depth--;
    if (depth == 0 && destroyRequested) super.destroy();
  }

  override public function destroy():Void
  {
    destroyRequested = true;
    if (depth == 0) super.destroy();
  }

  public function run(code:String, variables:Dynamic):Dynamic
  {
    lastRunSucceeded = false;
    try
    {
      if (interp == null || destroyRequested) throw 'Script has been destroyed';
      if (code == null) throw 'HScript source must not be null';
      set('game', owner.host.game);
      if (variables != null) for (name in Reflect.fields(variables)) set(name, Reflect.field(variables, name));
      scriptCode = code;
      parser.line = 1;
      parse(true);
    }
    catch (error:Dynamic)
    {
      reportError('parse', error, true);
      return null;
    }
    depth++;
    var result:Dynamic = null;
    try
    {
      result = execute();
      lastRunSucceeded = true;
    }
    catch (error:Dynamic)
    {
      reportError('execute', error);
    }
    finishInvocation();
    return result;
  }

  override public function call(fun:String, ?args:Array<Dynamic>):IrisCall
  {
    depth++;
    var result:IrisCall = null;
    try
    {
      if (interp == null || destroyRequested) throw 'Script has been destroyed';
      var callback = get(fun);
      if (!Reflect.isFunction(callback)) throw 'HScript function is missing or not callable: $fun';
      result = {funName: fun, signature: callback, returnValue: Reflect.callMethod(null, callback, args ?? [])};
    }
    catch (error:Dynamic)
    {
      reportError('function $fun', error);
    }
    finishInvocation();
    return result;
  }

  public function addLibrary(path:String, alias:String):Bool
  {
    try
    {
      var value = PsychLuaHScriptInterp.resolveType(path);
      if (value == null) throw 'Optional Haxe type is not present in this build: $path';
      set(alias, value);
      return true;
    }
    catch (error:Dynamic)
    {
      reportError('import $path', error);
      return false;
    }
  }

  function reportError(context:String, error:Dynamic, parsing:Bool = false):Void
  {
    var line = parsing ? parser?.line ?? 0 : interp?.posInfos().lineNumber ?? 0;
    var message = Std.string(error);
    #if hscriptPos
    if (Std.isOfType(error, crowplexus.hscript.Expr.Error))
    {
      var scriptError:crowplexus.hscript.Expr.Error = cast error;
      line = scriptError.line;
      message = crowplexus.hscript.Printer.errorToString(scriptError, false);
    }
    #end
    owner.host.report('[HScript][$name:${line > 0 ? Std.string(line) : "?"}][$context] $message');
  }
}

private class PsychLuaHScriptInterp extends crowplexus.hscript.Interp
{
  static final BLOCKED_PACKAGES:Array<String> = [
    'sys.', 'cpp.', 'hl.', 'eval.', 'neko.', 'python.', 'lua.', 'js.', 'java.', 'cs.', 'php.', 'polymod.', 'hscript.', 'crowplexus.',
    'funkin.util.macro.', 'funkin.mobile.util.', 'funkin.external.android.', 'extension.'
  ];

  var report:String->Void;

  public function new(report:String->Void)
  {
    super();
    this.report = report;
  }

  public static function resolveType(path:String):Dynamic
  {
    if (path == null || path == '') return null;
    if (PolymodScriptClass.importOverrides.exists(path))
    {
      var alias = PolymodScriptClass.importOverrides.get(path);
      if (alias == null) throw 'Import is blacklisted: $path';
      return alias;
    }
    for (prefix in BLOCKED_PACKAGES)
      if (StringTools.startsWith(path, prefix)) throw 'Import is blacklisted: $path';
    if (path == 'Sys') throw 'Import is blacklisted: $path';
    if (path == 'Reflect' || path == 'Type') return ReflectUtil;
    var value:Dynamic = ReflectUtil.resolveClass(path);
    return value == null ? ReflectUtil.resolveEnum(path) : value;
  }

  override public function getOrImportClass(name:String):Dynamic
  {
    return resolveType(name);
  }

  override function get(object:Dynamic, field:String):Dynamic
  {
    if (object == null) throw 'Cannot read "$field" on a null object';
    return ReflectUtil.getProperty(object, field);
  }

  override function set(object:Dynamic, field:String, value:Dynamic):Dynamic
  {
    if (object == null) throw 'Cannot set "$field" on a null object';
    ReflectUtil.setProperty(object, field, value);
    return value;
  }

  override function cnew(name:String, args:Array<Dynamic>):Dynamic
  {
    var type:Dynamic = resolveType(name);
    if (type == null) type = resolve(name);
    return ReflectUtil.createInstance(type, args);
  }

  override function useUsing(name:String):Void
  {
    var type = resolveType(name);
    if (type == null)
    {
      report('Optional using class is not present in this build: $name');
      return;
    }
    if (type != crowplexus.hscript.Tools.getClass(name)) throw 'Using a sandbox alias is not supported: $name';
    super.useUsing(name);
  }

  override public function expr(expression:Expr):Dynamic
  {
    switch (crowplexus.hscript.Tools.expr(expression))
    {
      case EImport(path, alias):
        #if hscriptPos
        curExpr = expression;
        #end
        var value = resolveType(path);
        if (value == null)
        {
          report('Line ${posInfos().lineNumber}: optional import is not present in this build: $path');
          return null;
        }
        var parts = path.split('.');
        imports.set(parts[parts.length - 1], value);
        if (alias != null) imports.set(alias, value);
        return null;
      default:
        return super.expr(expression);
    }
  }
}
#end
