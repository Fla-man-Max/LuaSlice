package luaslice.script;

class ScriptPropertyService
{
  final root:Null<String>->Dynamic;
  final report:String->Void;
  final pathPartsCache:Map<String, Array<String>> = [];

  public function new(root:Null<String>->Dynamic, report:String->Void)
  {
    this.root = root;
    this.report = report;
  }

  public function clear():Void { pathPartsCache.clear(); }

  public function parts(path:String):Array<String>
  {
    if (path == null || path == '') return [];
    var cached = pathPartsCache.get(path);
    if (cached == null)
    {
      cached = path.split('.');
      pathPartsCache.set(path, cached);
    }
    return cached.copy();
  }

  public static function read(target:Dynamic, field:String):Dynamic
  {
    ScriptProfiler.read();
    if (target == null) return null;
    try { return Reflect.getProperty(target, field); }
    catch (_:Dynamic) { return null; }
  }

  public static function part(target:Dynamic, name:String):Dynamic
  {
    if (target == null) return null;
    final bracket = name.indexOf('[');
    if (bracket >= 0 && StringTools.endsWith(name, ']'))
    {
      final field = name.substr(0, bracket);
      final index = Std.parseInt(name.substring(bracket + 1, name.length - 1));
      final value = field == '' ? target : read(target, field);
      if (index == null || value == null) return null;
      if (Std.isOfType(value, Array)) return (cast value:Array<Dynamic>)[index];
      return read(value, Std.string(index));
    }
    return read(target, name);
  }

  public function get(path:String):Dynamic
  {
    if (path == null || path == '') return null;
    final names = parts(path);
    var value = root(names.shift());
    for (name in names) value = part(value, name);
    return value;
  }

  public function parent(path:String):{target:Dynamic, field:String}
  {
    final names = parts(path);
    if (names.length == 0) return {target: null, field: ''};
    final field = names.pop();
    var target = root(names.shift());
    for (name in names) target = part(target, name);
    return {target: target, field: field};
  }

  public function write(target:Dynamic, field:String, value:Dynamic, notify:Bool = true):Bool
  {
    ScriptProfiler.write();
    if (target == null || field == null || field == '') return false;
    try
    {
      Reflect.setProperty(target, field, value);
      return true;
    }
    catch (error:Dynamic)
    {
      if (notify) report('Cannot set ${field}: ${error}');
      return false;
    }
  }

  public function set(path:String, value:Dynamic):Bool
  {
    final resolved = parent(path);
    if (write(resolved.target, resolved.field, value, false)) return true;
    report('Cannot set property path: ${path}');
    return false;
  }

  public function configure(target:Dynamic, fields:Dynamic):Bool
  {
    if (target == null || fields == null) return false;
    var ok = true;
    if (Std.isOfType(fields, haxe.ds.StringMap))
    {
      final values:haxe.ds.StringMap<Dynamic> = cast fields;
      for (key => value in values) ok = write(target, key, value) && ok;
    }
    else
      for (key in Reflect.fields(fields)) ok = write(target, key, Reflect.field(fields, key)) && ok;
    return ok;
  }

  public function setMany(targetOrPaths:Dynamic, ?fields:Dynamic):Bool
  {
    if (Std.isOfType(targetOrPaths, String)) return configure(get(targetOrPaths), fields);
    if (targetOrPaths == null) return false;
    var ok = true;
    if (Std.isOfType(targetOrPaths, haxe.ds.StringMap))
    {
      final values:haxe.ds.StringMap<Dynamic> = cast targetOrPaths;
      for (path => value in values) ok = set(path, value) && ok;
    }
    else
      for (path in Reflect.fields(targetOrPaths)) ok = set(path, Reflect.field(targetOrPaths, path)) && ok;
    return ok;
  }

  public function getMany(paths:Array<String>):Dynamic
  {
    final values:Dynamic = {};
    if (paths != null) for (path in paths) Reflect.setField(values, path, get(path));
    return values;
  }
}
