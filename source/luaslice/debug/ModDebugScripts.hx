package luaslice.debug;

typedef ModDebugScript = {
  backend:String,
  owner:String,
  path:String,
  eligible:Bool,
  status:String,
  disabled:Bool,
  forced:Bool
};

class ModDebugScripts
{
  public var forceApproved:Bool = false;
  final scripts:Map<String, ModDebugScript> = [];

  public function new() {}

  static function key(backend:String, owner:String, path:String):String
  {
    return haxe.Json.stringify([backend, owner, StringTools.replace(path, '\\', '/')]);
  }

  public function discover(backend:String, owner:String, path:String, eligible:Bool):Void
  {
    var id = key(backend, owner, path);
    var row = scripts.get(id);
    if (row != null)
    {
      if (eligible) row.eligible = true;
      return;
    }
    scripts.set(id, {backend: backend, owner: owner, path: path, eligible: eligible, status: 'Discovered', disabled: false, forced: false});
  }

  public function note(backend:String, owner:String, path:String, status:String):Void
  {
    discover(backend, owner, path, false);
    scripts.get(key(backend, owner, path)).status = status;
  }

  public function setDisabled(backend:String, owner:String, path:String, value:Bool):Void
  {
    var row = scripts.get(key(backend, owner, path));
    if (row != null) row.disabled = value;
  }

  public function setForced(backend:String, owner:String, path:String, value:Bool):Bool
  {
    var row = scripts.get(key(backend, owner, path));
    if (row == null || (value && (!forceApproved || !row.eligible || row.disabled))) return false;
    row.forced = value;
    return true;
  }

  public function isEnabled(backend:String, owner:String, path:String):Bool
  {
    return scripts.get(key(backend, owner, path))?.disabled != true;
  }

  public function isForced(backend:String, owner:String, path:String):Bool
  {
    var row = scripts.get(key(backend, owner, path));
    return forceApproved && row != null && row.eligible && row.forced && !row.disabled;
  }

  public function snapshot():Array<ModDebugScript>
  {
    return [for (row in scripts)
      {backend: row.backend, owner: row.owner, path: row.path, eligible: row.eligible,
        status: row.status, disabled: row.disabled, forced: row.forced}];
  }

  public function clear():Void
  {
    scripts.clear();
    forceApproved = false;
  }
}
