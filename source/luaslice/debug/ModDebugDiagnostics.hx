package luaslice.debug;

typedef ModDebugRecord = {kind:String, source:String, detail:String, at:Float};

class ModDebugDiagnostics
{
  public var paused:Bool = false;
  public var errors(default, null):Int = 0;
  final limit:Int;
  final records:Array<ModDebugRecord> = [];
  var cursor:Int = 0;

  public function new(limit:Int = 256)
  {
    this.limit = limit > 0 ? limit : 1;
  }

  public function record(kind:String, source:String, detail:String, at:Float):Void
  {
    if (kind == 'error') errors++;
    if (paused) return;
    records[cursor] = {kind: kind, source: source, detail: detail, at: at};
    cursor = (cursor + 1) % limit;
  }

  public function snapshot(filter:String = ''):Array<ModDebugRecord>
  {
    var result:Array<ModDebugRecord> = [];
    final start = records.length < limit ? 0 : cursor;
    final query = filter.toLowerCase();
    for (i in 0...records.length)
    {
      final entry = records[(start + i) % records.length];
      if (query != '' && (entry.kind + ' ' + entry.source + ' ' + entry.detail).toLowerCase().indexOf(query) < 0) continue;
      result.push({kind: entry.kind, source: entry.source, detail: entry.detail, at: entry.at});
    }
    return result;
  }

  public function clear():Void
  {
    records.resize(0);
    errors = 0;
    cursor = 0;
  }

  public static function displayName(value:String):String
  {
    var normalized = StringTools.replace(value, '\\', '/');
    return normalized.substr(normalized.lastIndexOf('/') + 1);
  }

  public function export(version:String, platform:String, ?profile:Dynamic):String
  {
    var report = {
      engine: version,
      platform: platform,
      errors: errors,
      records: [for (entry in snapshot())
        {kind: entry.kind, source: displayName(entry.source), at: entry.at}],
      profiler: profile
    };
    return haxe.Json.stringify(report, null, '  ');
  }
}
