package luaslice.modding;

import haxe.Json;
import haxe.crypto.Sha256;

typedef ModVisualWarning =
{
  var dir:String;
  var title:String;
  var fingerprint:String;
}

typedef ModWarningMetadata =
{
  var dir:String;
  var contents:Null<String>;
}

@:nullSafety
class ModWarningPolicy
{
  var acknowledged:Map<String, String> = [];

  public function new() {}

  public function pending(mods:Array<ModWarningMetadata>):Array<ModVisualWarning>
  {
    var active:Map<String, Bool> = [];
    var result:Array<ModVisualWarning> = [];
    for (mod in mods)
    {
      var warning = parse(mod);
      if (warning != null)
      {
        active.set(mod.dir, true);
        if (acknowledged.get(mod.dir) != warning.fingerprint) result.push(warning);
      }
    }
    for (dir in [for (dir in acknowledged.keys()) dir])
      if (!active.exists(dir)) acknowledged.remove(dir);
    return result;
  }

  public function acknowledge(warnings:Array<ModVisualWarning>):Void
  {
    for (warning in warnings) acknowledged.set(warning.dir, warning.fingerprint);
  }

  static function parse(mod:ModWarningMetadata):Null<ModVisualWarning>
  {
    var contents = mod.contents;
    if (contents == null || contents == '') return null;
    try
    {
      var data:Dynamic = Json.parse(contents);
      if (!isObject(data)) return null;
      var metadata:Dynamic = Reflect.field(data, 'metadata');
      if (!isObject(metadata)) return null;
      var value:Dynamic = Reflect.field(metadata, 'photosensitivityWarning');
      var flagged = (Std.isOfType(value, Bool) && value == true)
        || (Std.isOfType(value, String) && StringTools.trim(cast value).toLowerCase() == 'true');
      if (!flagged) return null;
      var title:Dynamic = Reflect.field(data, 'title');
      var label:String = Std.isOfType(title, String) ? StringTools.trim(cast title) : mod.dir;
      if (label == '') label = mod.dir;
      label = StringTools.replace(StringTools.replace(label, '\n', ' '), '\r', ' ').substr(0, 100);
      return {dir: mod.dir, title: label, fingerprint: Sha256.encode(contents)};
    }
    catch (_:Dynamic)
    {
      return null;
    }
  }

  static function isObject(value:Dynamic):Bool
  {
    return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array);
  }
}
