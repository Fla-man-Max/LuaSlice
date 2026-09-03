import luaslice.modding.ModSelection;

class ModSelectionTest
{
  static var checks:Int = 0;

  static function main():Void
  {
    expect("Fresh mobile installs are enabled", [], [], ["sky", "neon"], ["sky", "neon"], true,
      ["sky", "neon"], ["sky", "neon"]);

    expect("New installs append without changing enabled order", ["neon", "sky"], ["sky", "neon"],
      ["sky", "alpha", "neon", "beta"], ["sky", "alpha", "neon", "beta"], true,
      ["neon", "sky", "alpha", "beta"], ["sky", "alpha", "neon", "beta"]);

    var disabled = expect("Known disabled mods stay disabled", ["sky"], ["sky", "neon"],
      ["sky", "neon", "alpha"], ["sky", "neon", "alpha"], true, ["sky", "alpha"], ["sky", "neon", "alpha"]);
    expect("Restart preserves intentional disables", disabled.enabled, disabled.known,
      ["sky", "neon", "alpha"], ["sky", "neon", "alpha"], true, ["sky", "alpha"], ["sky", "neon", "alpha"]);

    var removed = expect("Removed enabled mods are forgotten", ["neon", "sky"], ["sky", "neon"],
      ["neon"], ["neon"], true, ["neon"], ["neon"]);
    expect("Reinstalled mobile mod is recognized as new", removed.enabled, removed.known,
      ["neon", "sky"], ["neon", "sky"], true, ["neon", "sky"], ["neon", "sky"]);

    expect("Duplicate and stale saved entries are removed", ["sky", "sky", "neon", "sky", "gone"],
      ["sky", "sky", "neon", "gone"], ["neon", "sky", "neon"], ["neon", "sky", "sky"], true,
      ["sky", "neon"], ["neon", "sky"]);

    var desktop = expect("Desktop mods remain opt-in", [], [], ["sky", "neon"], ["sky", "neon"], false,
      [], ["sky", "neon"]);
    expect("Desktop manual selection survives restart", ["neon"], desktop.known,
      ["sky", "neon", "alpha"], ["sky", "neon", "alpha"], false, ["neon"], ["sky", "neon", "alpha"]);
    expect("Desktop also forgets removed mods", ["sky", "neon"], desktop.known,
      ["neon"], ["neon"], false, ["neon"], ["neon"]);

    expect("Enabled installed mod with invalid metadata is retained", ["broken"], [], ["broken"], [], true,
      ["broken"], ["broken"]);
    expect("Disabled known mod with invalid metadata stays disabled", [], ["broken"], ["broken"], [], true,
      [], ["broken"]);

    var incomplete = expect("Incomplete install is not auto-enabled or marked known", [], [], ["pending"], [], true,
      [], []);
    expect("Completed metadata enables an incomplete install later", incomplete.enabled, incomplete.known,
      ["pending"], ["pending"], true, ["pending"], ["pending"]);

    var archive = expect("ZIP virtual directory stem can be auto-enabled", [], [], ["sky-pack"], ["sky-pack"], true,
      ["sky-pack"], ["sky-pack"]);
    expect("Saved ZIP virtual stem is preserved", archive.enabled, archive.known, ["sky-pack"], ["sky-pack"], true,
      ["sky-pack"], ["sky-pack"]);
    expect("Removed ZIP stem is pruned", archive.enabled, archive.known, [], [], true, [], []);

    expect("Discovery cannot enable a nonexistent directory", [], [], ["sky"], ["gone", "sky"], true,
      ["sky"], ["sky"]);
    expect("Empty installation remains empty", [], [], [], [], true, [], []);

    var inputEnabled = ["sky", "missing", "sky"];
    var inputKnown = ["sky", "missing"];
    var inputInstalled = ["sky", "new"];
    var inputDiscoverable = ["sky", "new"];
    var selection = ModSelection.reconcile(inputEnabled, inputKnown, inputInstalled, inputDiscoverable, true);
    assertArray("Enabled input is not mutated", inputEnabled, ["sky", "missing", "sky"]);
    assertArray("Known input is not mutated", inputKnown, ["sky", "missing"]);
    assertArray("Installed input is not mutated", inputInstalled, ["sky", "new"]);
    assertArray("Discoverable input is not mutated", inputDiscoverable, ["sky", "new"]);
    selection.enabled.push("other");
    selection.known.push("other");
    assertArray("Returned enabled list is independent", inputEnabled, ["sky", "missing", "sky"]);
    assertArray("Returned known list is independent", inputKnown, ["sky", "missing"]);

    assertTrue("Empty arrays match", ModSelection.matches([], []));
    assertTrue("Identical ordered arrays match", ModSelection.matches(["sky", "neon"], ["sky", "neon"]));
    assertTrue("Different order does not match", !ModSelection.matches(["sky", "neon"], ["neon", "sky"]));
    assertTrue("Different length does not match", !ModSelection.matches(["sky"], ["sky", "neon"]));
    assertTrue("Different entries do not match", !ModSelection.matches(["sky"], ["neon"]));

    Sys.println('ModSelectionTest passed $checks checks.');
  }

  static function expect(name:String, enabled:Array<String>, known:Array<String>, installed:Array<String>, discoverable:Array<String>,
      enableNewMods:Bool, expectedEnabled:Array<String>, expectedKnown:Array<String>):{enabled:Array<String>, known:Array<String>}
  {
    var result = ModSelection.reconcile(enabled, known, installed, discoverable, enableNewMods);
    assertArray(name + " (enabled)", result.enabled, expectedEnabled);
    assertArray(name + " (known)", result.known, expectedKnown);
    return result;
  }

  static function assertArray(name:String, actual:Array<String>, expected:Array<String>):Void
  {
    checks++;
    if (!ModSelection.matches(actual, expected))
    {
      throw '$name: expected ${haxe.Json.stringify(expected)}, got ${haxe.Json.stringify(actual)}';
    }
  }

  static function assertTrue(name:String, condition:Bool):Void
  {
    checks++;
    if (!condition) throw name;
  }
}
