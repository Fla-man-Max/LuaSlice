package luaslice.modding;

@:nullSafety
class ModSelection
{
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
