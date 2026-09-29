package luaslice.script;

class ScriptProfiler
{
  public static var enabled(default, null):Bool = false;
  static var hooks:Map<String, {script:String, hook:String, calls:Int, milliseconds:Float, errors:Int}> = [];
  static var bridgeCalls:Int = 0;
  static var propertyReads:Int = 0;
  static var propertyWrites:Int = 0;

  public static function start():Void
  {
    reset();
    enabled = true;
  }

  public static function stop():Void { enabled = false; }

  public static function reset():Void
  {
    hooks.clear();
    bridgeCalls = 0;
    propertyReads = 0;
    propertyWrites = 0;
  }

  public static inline function bridge():Void { if (enabled) bridgeCalls++; }
  public static inline function read():Void { if (enabled) propertyReads++; }
  public static inline function write():Void { if (enabled) propertyWrites++; }

  public static function record(script:String, hook:String, started:Float, failed:Bool):Void
  {
    if (!enabled) return;
    final key = script + ':' + hook;
    var item = hooks.get(key);
    if (item == null)
    {
      item = {script: script, hook: hook, calls: 0, milliseconds: 0, errors: 0};
      hooks.set(key, item);
    }
    item.calls++;
    item.milliseconds += (haxe.Timer.stamp() - started) * 1000;
    if (failed) item.errors++;
  }

  public static function snapshot():Dynamic
  {
    final rows:Array<Dynamic> = [];
    for (item in hooks) rows.push({script: item.script, hook: item.hook, calls: item.calls,
      totalMs: item.milliseconds, averageMs: item.milliseconds / item.calls, errors: item.errors});
    rows.sort((a, b) -> Reflect.compare(b.totalMs, a.totalMs));
    return {enabled: enabled, hooks: rows, bridgeCalls: bridgeCalls, propertyReads: propertyReads, propertyWrites: propertyWrites};
  }
}
