package luaslice.modding;

using Lambda;

@:nullSafety
class ModSelection
{
  /** Normalize legacy folder selections without changing load order or losing invalid installations. */
  public static function toModIds<T:{id:String, dirName:String}>(entries:Array<String>, mods:Array<T>):Array<String>
  {
    var result:Array<String> = [];
    for (entry in entries)
    {
      var mod = mods.find(item -> item.id == entry);
      if (mod == null) mod = mods.find(item -> item.dirName == entry);
      var id = mod == null ? entry : mod.id;
      if (!result.contains(id)) result.push(id);
    }
    return result;
  }

  public static function toModDirs<T:{id:String, dirName:String}>(entries:Array<String>, mods:Array<T>):Array<String>
  {
    var result:Array<String> = [];
    for (entry in entries)
    {
      var mod = mods.find(item -> item.id == entry);
      var dir = mod == null ? entry : mod.dirName;
      if (!result.contains(dir)) result.push(dir);
    }
    return result;
  }

  public static function reconcile(enabled:Array<String>, known:Array<String>, installed:Array<String>, discoverable:Array<String>,
      enableNewMods:Bool):{enabled:Array<String>, known:Array<String>}
  {
    var installedSet:Map<String, Bool> = [];
    for (dir in installed) installedSet.set(dir, true);

    var knownSet:Map<String, Bool> = [];
    for (dir in known) knownSet.set(dir, true);

    var result:Array<String> = [];
    var enabledSet:Map<String, Bool> = [];
    for (dir in enabled)
    {
      if (!installedSet.exists(dir) || enabledSet.exists(dir)) continue;
      result.push(dir);
      enabledSet.set(dir, true);
    }

    for (dir in discoverable)
    {
      if (!installedSet.exists(dir)) continue;
      if (enableNewMods && !knownSet.exists(dir) && !enabledSet.exists(dir))
      {
        result.push(dir);
        enabledSet.set(dir, true);
      }
      knownSet.set(dir, true);
    }

    var resultKnown:Array<String> = [];
    for (dir in installed)
    {
      if ((knownSet.exists(dir) || enabledSet.exists(dir)) && !resultKnown.contains(dir)) resultKnown.push(dir);
    }

    return {enabled: result, known: resultKnown};
  }

  public static function matches(first:Array<String>, second:Array<String>):Bool
  {
    if (first.length != second.length) return false;
    for (i in 0...first.length)
    {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
