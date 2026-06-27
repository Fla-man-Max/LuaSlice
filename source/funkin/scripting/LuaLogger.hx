package funkin.scripting;

#if (FEATURE_LOGGER && cpp && windows)
@:cppInclude("windows.h")
@:cppInclude("stdio.h")
#end
class LuaLogger
{
  #if FEATURE_LUA_SCRIPTS
  static var initialized:Bool = false;

  public static function init():Void
  {
    #if FEATURE_LOGGER
    if (initialized) return;
    initialized = true;

    #if (cpp && windows)
    try
    {
      untyped __cpp__('AllocConsole(); freopen("CONOUT$", "w", stdout); freopen("CONOUT$", "w", stderr);');
    }
    catch (_)
    {
    }
    #end

    log('info', 'LuaSlice logger started');
    #end
  }

  public static function scripts(scripts:Array<String>):Void
  {
    #if FEATURE_LOGGER
    init();
    log('scripts', '${scripts.length} loaded');
    for (script in scripts) log('scripts', script);
    #end
  }

  public static function error(kind:String, scriptPath:String, hookName:Null<String>, message:String, reportPath:String):Void
  {
    #if FEATURE_LOGGER
    init();
    var hook = hookName == null ? 'load' : hookName;
    log('error', '${kind} | ${scriptPath} | ${hook}');
    log('error', message);
    log('error', 'report: ${reportPath}');
    #end
  }

  public static function vars(name:String, value:Dynamic):Void
  {
    #if FEATURE_LOGGER
    init();
    log('vars', '${name} = ${Std.string(value)}');
    #end
  }

  static function log(kind:String, message:String):Void
  {
    #if FEATURE_LOGGER
    trace('[LuaLogger:${kind}] ${message}');
    #end
  }
  #end
}
