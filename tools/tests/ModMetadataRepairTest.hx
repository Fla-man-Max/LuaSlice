import haxe.Json;
import haxe.io.Path;
import luaslice.modding.ModMetadataRepair;
import polymod.fs.SysZipFileSystem;
import sys.FileSystem;
import sys.io.File;

class ModMetadataRepairTest
{
  static var checks = 0;

  static function expect(value:Bool, label:String):Void
  {
    if (!value) throw 'FAILED: $label';
    checks++;
  }

  static function metadata(id:String, title:String):String
  {
    return Json.stringify({
      title: title,
      description: 'existing',
      homepage: '',
      id: id,
      contributors: [{name: 'tester', role: 'tester'}],
      api_version: '0.8.7',
      mod_version: '1.0.0',
      license: ''
    });
  }

  static function createMod(root:String, name:String, ?contents:String):String
  {
    var dir = Path.join([root, name]);
    FileSystem.createDirectory(dir);
    if (contents != null) File.saveContent(Path.join([dir, polymod.PolymodConfig.modMetadataFile]), contents);
    return dir;
  }

  static function main():Void
  {
    var fixture = '.research/mod-metadata-repair/fixture-' + Std.string(Date.now().getTime()) + '-' + Std.random(1000000);
    if (FileSystem.exists(fixture)) throw 'Fixture already exists.';
    var root = Path.join([fixture, 'mods']);
    FileSystem.createDirectory(root);
    createMod(root, 'valid', metadata('sky-mod', 'Valid Mod'));
    createMod(root, 'declined');
    var corruptPath = createMod(root, 'corrupt', '{broken');
    var corruptMetadata = Path.join([corruptPath, polymod.PolymodConfig.modMetadataFile]);
    var repair = new ModMetadataRepair();
    var prompts:Array<String> = [];
    var errors:Array<String> = [];
    var fs = new UnsafeEntryFileSystem(root);

    var first = repair.scan(root, fs, (name, path) -> {
      prompts.push(name + ':' + path);
      return false;
    }, errors.push);
    expect(first.installed.join(',') == 'corrupt,declined,valid', 'Installed folders are sorted and unsafe entries are ignored');
    expect(first.ready.join(',') == 'corrupt,valid', 'Only folders with metadata are ready');
    expect(first.created.length == 0 && errors.length == 0, 'Declining creates nothing and reports no write error');
    expect(prompts.length == 1 && StringTools.startsWith(prompts[0], 'declined:'), 'Missing folder prompts once');
    expect(File.getContent(corruptMetadata) == '{broken', 'Existing malformed metadata is not overwritten');

    repair.scan(root, fs, (name, path) -> {
      prompts.push(name);
      return false;
    }, errors.push);
    expect(prompts.length == 1, 'Declined folder is not repeatedly prompted during the same run');

    var declinedMetadata = Path.join([root, 'declined', polymod.PolymodConfig.modMetadataFile]);
    File.saveContent(declinedMetadata, metadata('declined', 'Declined'));
    var restored = repair.scan(root, fs, (name, path) -> false, errors.push);
    expect(restored.ready.contains('declined'), 'Metadata added outside the game restores the mod');
    expect(restored.created.length == 0 && File.getContent(declinedMetadata).indexOf('Declined') != -1, 'External metadata remains untouched');

    createMod(root, 'Sky Mod');
    createMod(root, 'Generated Mod');
    var generatedPrompts:Array<String> = [];
    var generated = repair.scan(root, fs, (name, path) -> {
      generatedPrompts.push(name);
      return true;
    }, errors.push);
    expect(generated.created.join(',') == 'Generated Mod,Sky Mod', 'Accepted folders get starter metadata');
    expect(generated.ready.contains('Generated Mod') && generated.ready.contains('Sky Mod'), 'Generated folders are immediately ready');
    expect(generatedPrompts.join(',') == 'Generated Mod,Sky Mod', 'Each missing folder gets its own prompt');

    var generatedJson:Dynamic = Json.parse(File.getContent(Path.join([root, 'Generated Mod', polymod.PolymodConfig.modMetadataFile])));
    var collisionJson:Dynamic = Json.parse(File.getContent(Path.join([root, 'Sky Mod', polymod.PolymodConfig.modMetadataFile])));
    expect(Reflect.field(generatedJson, 'title') == 'Generated Mod' && Reflect.field(generatedJson, 'id') == 'generated-mod',
      'Folder name supplies the starter title and ID');
    expect(Reflect.field(generatedJson, 'api_version') == '0.8.7' && Reflect.field(generatedJson, 'mod_version') == '1.0.0',
      'Starter versions match the supplied template');
    var contributors:Array<Dynamic> = cast Reflect.field(generatedJson, 'contributors');
    expect(contributors.length == 2 && Reflect.field(contributors[0], 'url') == 'link' && !Reflect.hasField(contributors[1], 'url'),
      'Starter contributor fields match the supplied template');
    expect(StringTools.startsWith(Reflect.field(collisionJson, 'id'), 'sky-mod-') && Reflect.field(collisionJson, 'id') != 'sky-mod',
      'Generated IDs do not collide with installed metadata');
    var polymodErrors:Array<String> = [];
    polymod.Polymod.onError = error -> polymodErrors.push(error.code + ':' + error.message);
    var parsed = fs.getMetadataByDir('Generated Mod');
    expect(parsed != null && parsed.id == 'generated-mod' && parsed.title == 'Generated Mod', 'Polymod parses the generated metadata');
    expect(parsed != null && parsed.apiVersion.toString() == '0.8.7' && parsed.contributors.length == 2,
      'Polymod accepts the generated API version and contributors');

    createMod(root, 'race');
    var racePath = Path.join([root, 'race', polymod.PolymodConfig.modMetadataFile]);
    var raceContents = metadata('race-external', 'Race External');
    var race = repair.scan(root, fs, (name, path) -> {
      if (name == 'race') File.saveContent(path, raceContents);
      return true;
    }, errors.push);
    expect(race.ready.contains('race') && !race.created.contains('race'), 'Metadata added while the dialog is open is accepted without replacement');
    expect(File.getContent(racePath) == raceContents, 'Concurrent external metadata is not overwritten');
    expect(errors.length == 0, 'All valid writes completed without errors');
    Sys.println('ModMetadataRepairTest passed ' + checks + ' checks. Fixture: ' + fixture);
  }
}

private class UnsafeEntryFileSystem extends SysZipFileSystem
{
  public function new(root:String)
  {
    super({modRoot: root, autoScan: true});
  }

  public override function readDirectory(path:String):Array<String>
  {
    var result = super.readDirectory(path);
    if (Path.normalize(path) == Path.normalize(modRoot))
    {
      result.push('../escape');
      result.push('valid');
    }
    return result;
  }
}
