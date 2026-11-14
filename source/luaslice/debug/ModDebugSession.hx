package luaslice.debug;

enum abstract ModDebugOption(String)
{
  var Downscroll = "Downscroll";
  var MiddleScroll = "Middlescroll";
  var NoteSplash = "Note splashes";
  var CameraZoom = "Camera zoom";
  var FlashingLights = "Flashing lights";
}

typedef ModDebugRates = {update:Int, draw:Int};

class ModDebugSession
{
  public static var current(default, null):Null<ModDebugSession>;
  public var optionsEnabled:Bool = false;
  public var suppressScriptPopups:Bool = false;
  public var requestedFps(default, null):Null<Int>;
  public final diagnostics = new ModDebugDiagnostics();
  public final scripts = new ModDebugScripts();
  public final brokenScriptObjects = new haxe.ds.ObjectMap<{}, Bool>();

  final originalRates:ModDebugRates;
  final writeRates:(Int, Int)->Void;
  final options:Map<ModDebugOption, Bool> = [];
  final modOptions:Map<String, Map<String, Dynamic>> = [];
  final saves:Map<String, Map<String, Dynamic>> = [];
  var generation:Int = 0;

  public static function begin(readRates:Void->ModDebugRates, writeRates:(Int, Int)->Void):ModDebugSession
  {
    current?.dispose();
    var session = new ModDebugSession(readRates(), writeRates);
    current = session;
    return session;
  }

  function new(rates:ModDebugRates, writeRates:(Int, Int)->Void)
  {
    this.originalRates = rates;
    this.writeRates = writeRates;
  }

  public function nextPreview():Int
  {
    return ++generation;
  }

  public function previewGeneration():Int
  {
    return generation;
  }

  public function ownsPreview(value:Int):Bool
  {
    return current == this && generation == value;
  }

  public function setRequestedFps(value:Int):Bool
  {
    if (current != this || value < 30 || value > 500) return false;
    writeRates(value, value);
    requestedFps = value;
    return true;
  }

  public function setOption(key:ModDebugOption, value:Dynamic):Bool
  {
    if (current != this || !Std.isOfType(value, Bool)) return false;
    options.set(key, value);
    return true;
  }

  public function clearOption(key:ModDebugOption):Void
  {
    options.remove(key);
  }

  public function option(key:ModDebugOption, fallback:Bool):Bool
  {
    return current == this && optionsEnabled && options.exists(key) ? options.get(key) : fallback;
  }

  public function setModOption(owner:String, key:String, value:Dynamic):Void
  {
    if (current != this) return;
    if (!modOptions.exists(owner)) modOptions.set(owner, []);
    modOptions.get(owner).set(key, value);
  }

  public function modOption(owner:String, key:String, fallback:Dynamic):Dynamic
  {
    var values = modOptions.get(owner);
    return current == this && optionsEnabled && values != null && values.exists(key) ? values.get(key) : fallback;
  }

  static function saveKey(backend:String, owner:String, namespace:String):String
  {
    return haxe.Json.stringify([backend, owner, namespace]);
  }

  public function getSave(backend:String, owner:String, namespace:String, key:String, fallback:Dynamic):Dynamic
  {
    var data = saves.get(saveKey(backend, owner, namespace));
    return current == this && data != null && data.exists(key) ? data.get(key) : fallback;
  }

  public function setSave(backend:String, owner:String, namespace:String, key:String, value:Dynamic):Void
  {
    if (current != this) return;
    var slot = saveKey(backend, owner, namespace);
    if (!saves.exists(slot)) saves.set(slot, []);
    saves.get(slot).set(key, value);
  }

  public function eraseSave(backend:String, owner:String, namespace:String):Void
  {
    if (current == this) saves.remove(saveKey(backend, owner, namespace));
  }

  public function reset():Void
  {
    if (current != this) return;
    nextPreview();
    if (requestedFps != null) writeRates(originalRates.update, originalRates.draw);
    requestedFps = null;
    optionsEnabled = false;
    suppressScriptPopups = false;
    options.clear();
    modOptions.clear();
    saves.clear();
    diagnostics.paused = false;
    diagnostics.clear();
    scripts.clear();
    brokenScriptObjects.clear();
  }

  public function dispose():Void
  {
    if (current != this) return;
    reset();
    current = null;
  }
}
