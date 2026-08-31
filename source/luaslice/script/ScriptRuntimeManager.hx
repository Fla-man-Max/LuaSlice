package luaslice.script;

#if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
import funkin.modding.PolymodHandler;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class ScriptRuntimeManager
{
  var scripts:Array<IScriptRuntime> = [];

  function new() {}

  public static function loadClassScripts(owner:Dynamic):Null<ScriptRuntimeManager>
  {
    if (owner == null) return null;
    final ownerClass = Type.getClass(owner);
    if (ownerClass == null) return null;
    final fullName = Type.getClassName(ownerClass);
    if (fullName == null) return null;
    final parts = fullName.split('.');
    final className = parts[parts.length - 1];

    final paths:Array<String> = [];
    for (root in scriptRoots())
    {
      collectGlobalScripts(root, paths);
      addClassScripts(root, className, paths);
    }
    return load(owner, paths);
  }

  public static function loadPlayStateScripts(owner:Dynamic, songId:String):Null<ScriptRuntimeManager>
  {
    final paths:Array<String> = [];
    for (root in scriptRoots())
    {
      collectGlobalScripts(root, paths);
      addClassScripts(root, 'PlayState', paths);
      addSongScripts(root, songId, paths);
    }
    return load(owner, paths);
  }

  static function load(owner:Dynamic, paths:Array<String>):Null<ScriptRuntimeManager>
  {
    paths.sort((a, b) -> Reflect.compare(a.toLowerCase(), b.toLowerCase()));
    final seen:Map<String, Bool> = [];
    var manager:Null<ScriptRuntimeManager> = null;

    for (path in paths)
    {
      final normalized = Path.normalize(path);
      if (seen.exists(normalized) || !FileSystem.exists(normalized) || FileSystem.isDirectory(normalized)) continue;
      seen.set(normalized, true);

      try
      {
        final runtime:Null<IScriptRuntime> = createRuntime(normalized, owner);
        if (runtime == null) continue;
        manager ??= new ScriptRuntimeManager();
        manager.scripts.push(runtime);
      }
      catch (error:Dynamic)
      {
        trace('[LuaSlice Scripts] Failed to load ${normalized}: ${Std.string(error)}');
      }
    }

    return manager;
  }

  static function createRuntime(path:String, owner:Dynamic):Null<IScriptRuntime>
  {
    final extension = Path.extension(path).toLowerCase();
    return switch (extension)
    {
      #if FEATURE_SSCRIPT_SCRIPTS
      case 'ss' | 'ssg': new SScriptRuntime(path, owner);
      #end
      #if FEATURE_NXSCRIPT_SCRIPTS
      case 'nx' | 'nxg': new NxScriptRuntime(path, owner);
      #end
      default: null;
    };
  }

  static function scriptRoots():Array<String>
  {
    final roots = [PolymodHandler.getModRoot()];
    for (modDir in PolymodHandler.loadedModDirs)
    {
      final root = Path.join([PolymodHandler.getModRoot(), modDir]);
      if (!roots.contains(root)) roots.push(root);
    }
    return roots;
  }

  static function collectGlobalScripts(root:String, output:Array<String>):Void
  {
    addForExtensions(Path.join([root, 'global']), ['ssg', 'nxg'], output);
    addForExtensions(Path.join([root, 'scripts', 'global']), ['ssg', 'nxg'], output);
    collectFolder(Path.join([root, 'scripts']), ['ssg', 'nxg'], output);
  }

  static function addClassScripts(root:String, className:String, output:Array<String>):Void
  {
    for (base in [Path.join([root, className]), Path.join([root, 'scripts', className]), Path.join([root, 'scripts', 'states', className])])
    {
      addForExtensions(base, ['ss', 'nx'], output);
    }
  }

  static function addSongScripts(root:String, songId:String, output:Array<String>):Void
  {
    if (songId == null || songId == '') return;
    for (base in [Path.join([root, songId]), Path.join([root, 'scripts', songId]), Path.join([root, 'scripts', 'songs', songId])])
    {
      addForExtensions(base, ['ss', 'nx'], output);
    }
    collectFolder(Path.join([root, 'scripts', 'gameplay']), ['ss', 'nx'], output);
  }

  static function addForExtensions(base:String, extensions:Array<String>, output:Array<String>):Void
  {
    for (extension in extensions) output.push('${base}.${extension}');
  }

  static function collectFolder(folder:String, extensions:Array<String>, output:Array<String>):Void
  {
    if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;
    for (entry in FileSystem.readDirectory(folder))
    {
      final path = Path.join([folder, entry]);
      if (FileSystem.isDirectory(path)) collectFolder(path, extensions, output);
      else if (extensions.contains(Path.extension(path).toLowerCase())) output.push(path);
    }
  }

  public function callHook(name:String, args:Array<Dynamic>):Void
  {
    for (script in scripts) script.callHook(name, args);
  }

  public function destroy():Void
  {
    for (script in scripts) script.destroy();
    scripts.resize(0);
  }
}
#end
