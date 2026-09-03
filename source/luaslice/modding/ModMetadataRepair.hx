package luaslice.modding;

import haxe.Json;
import haxe.crypto.Sha256;
import haxe.io.Path;
import polymod.fs.PolymodFileSystem.IFileSystem;

typedef ModMetadataScan =
{
  var installed:Array<String>;
  var ready:Array<String>;
  var created:Array<String>;
}

@:nullSafety
class ModMetadataRepair
{
  var prompted:Map<String, Bool> = [];

  public function new() {}

  public function scan(root:String, fileSystem:IFileSystem, ask:String->String->Bool, onError:String->Void):ModMetadataScan
  {
    var installed:Array<String> = [];
    var present:Map<String, Bool> = [];
    var usedIds:Map<String, Bool> = [];
    var ready:Array<String> = [];
    var created:Array<String> = [];

    for (dir in fileSystem.readDirectory(root))
    {
      if (!isDirectChild(dir) || installed.contains(dir)) continue;
      var modPath = Path.join([root, dir]);
      if (!fileSystem.exists(modPath) || !fileSystem.isDirectory(modPath)) continue;
      installed.push(dir);
      present.set(modPath, true);

      var metadataPath = Path.join([modPath, polymod.PolymodConfig.modMetadataFile]);
      if (hasMetadata(fileSystem, metadataPath))
      {
        try
        {
          var content = fileSystem.getFileContent(metadataPath);
          if (content != null)
          {
            var data:Dynamic = Json.parse(content);
            var id:Dynamic = Reflect.field(data, 'id');
            usedIds.set(Std.isOfType(id, String) && id != '' ? cast id : dir, true);
          }
        }
        catch (_:Dynamic) {}
      }
    }
    installed.sort(Reflect.compare);

    var prefix = Path.addTrailingSlash(root);
    for (path in [for (path in prompted.keys()) path])
    {
      if (StringTools.startsWith(path, prefix) && !present.exists(path)) prompted.remove(path);
    }

    for (dir in installed)
    {
      var modPath = Path.join([root, dir]);
      var metadataPath = Path.join([modPath, polymod.PolymodConfig.modMetadataFile]);
      if (!fileSystem.exists(metadataPath) && !prompted.exists(modPath))
      {
        prompted.set(modPath, true);
        if (ask(dir, metadataPath))
        {
          try
          {
            var id = makeId(dir, usedIds);
            if (create(root, dir, fileSystem, template(dir, id)))
            {
              usedIds.set(id, true);
              created.push(dir);
            }
          }
          catch (error:Dynamic)
          {
            onError('Could not create "$metadataPath": ${Std.string(error)}\n\nThis mod will be skipped. Other mods can still load.');
          }
        }
      }

      if (hasMetadata(fileSystem, metadataPath))
      {
        prompted.remove(modPath);
        ready.push(dir);
      }
    }

    return {installed: installed, ready: ready, created: created};
  }

  static function hasMetadata(fileSystem:IFileSystem, path:String):Bool
  {
    return fileSystem.exists(path) && !fileSystem.isDirectory(path);
  }

  static function isDirectChild(dir:String):Bool
  {
    return dir != '' && dir != '.' && dir != '..' && dir.indexOf('/') == -1 && dir.indexOf('\\') == -1 && dir.indexOf(':') == -1;
  }

  static function makeId(dir:String, usedIds:Map<String, Bool>):String
  {
    var id = ~/[^a-z0-9_-]+/g.replace(dir.toLowerCase(), '-');
    id = ~/^-+|-+$/g.replace(id, '');
    if (id == '') id = 'mod';
    if (!usedIds.exists(id)) return id;

    var uniqueId = id + '-' + Sha256.encode(dir).substr(0, 8);
    var suffix = 2;
    while (usedIds.exists(uniqueId)) uniqueId = id + '-' + Sha256.encode(dir).substr(0, 8) + '-' + suffix++;
    return uniqueId;
  }

  static function template(title:String, id:String):String
  {
    var contributors:Array<Dynamic> = [
      {name: 'template', role: 'template', url: 'link'},
      {name: 'template', role: 'template'}
    ];
    return Json.stringify({
      title: title,
      description: 'template',
      homepage: 'link',
      id: id,
      contributors: contributors,
      api_version: '0.8.7',
      mod_version: '1.0.0',
      license: ''
    }, null, '    ') + '\n';
  }

  static function create(root:String, dir:String, fileSystem:IFileSystem, contents:String):Bool
  {
    #if sys
    if (!isDirectChild(dir)) throw 'Invalid mod folder name.';
    var modPath = Path.join([root, dir]);
    var metadataPath = Path.join([modPath, polymod.PolymodConfig.modMetadataFile]);
    if (fileSystem.exists(metadataPath)) return false;
    if (!fileSystem.exists(modPath) || !fileSystem.isDirectory(modPath)) throw 'The mod folder no longer exists.';

    var resolvedRoot = Path.removeTrailingSlashes(Path.normalize(sys.FileSystem.fullPath(root)));
    var resolvedMod = Path.normalize(Path.join([resolvedRoot, dir]));
    if (Path.directory(resolvedMod) != resolvedRoot) throw 'Metadata must stay inside the mods folder.';
    var destination = Path.join([resolvedMod, polymod.PolymodConfig.modMetadataFile]);
    if (sys.FileSystem.exists(destination)) return false;
    if (!sys.FileSystem.exists(resolvedMod)) sys.FileSystem.createDirectory(resolvedMod);
    if (!sys.FileSystem.isDirectory(resolvedMod)) throw 'The mod path is not a folder.';
    if (sys.FileSystem.exists(destination)) return false;
    sys.io.File.saveContent(destination, contents);
    return true;
    #else
    throw 'Creating mod metadata is not supported on this platform.';
    #end
  }
}
