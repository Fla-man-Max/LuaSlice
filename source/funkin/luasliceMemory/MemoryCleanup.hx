package funkin.luasliceMemory;

import flixel.FlxG;
import funkin.FunkinMemory;
import funkin.util.MemoryUtil;
import openfl.Assets;

@:nullSafety
class MemoryCleanup
{
  static final AUTO_COLLECT_THRESHOLD:Float = 128.0 * 1024.0 * 1024.0;
  static final AUTO_COMPACT_THRESHOLD:Float = 256.0 * 1024.0 * 1024.0;
  static final LARGE_TEXTURE_BYTES:Float = 16.0 * 1024.0 * 1024.0;

  static var initialized:Bool = false;
  static var fullCleanupRequested:Bool = false;
  static var gameplayOptimizationQueued:Bool = false;

  public static function initialize():Void
  {
    if (initialized) return;
    initialized = true;
    FlxG.signals.postStateSwitch.add(onStateSwitchComplete);
  }

  public static function requestFullCleanup():Void
  {
    initialize();
    fullCleanupRequested = true;
  }

  public static function completeRequestedCleanup():Void
  {
    #if cpp
    final gcMemory:Float = MemoryUtil.getGCMemory();
    final taskMemory:Float = MemoryUtil.supportsTaskMem() ? MemoryUtil.getTaskMemory() : 0.0;
    final shouldCompact:Bool = fullCleanupRequested || gcMemory >= AUTO_COMPACT_THRESHOLD || taskMemory >= AUTO_COMPACT_THRESHOLD;
    fullCleanupRequested = false;

    if (shouldCompact)
    {
      MemoryUtil.compact();
    }
    else if (gcMemory >= AUTO_COLLECT_THRESHOLD)
    {
      MemoryUtil.collect(true);
    }
    #elseif hl
    if (fullCleanupRequested || MemoryUtil.getGCMemory() >= AUTO_COLLECT_THRESHOLD)
    {
      MemoryUtil.collect(true);
    }
    fullCleanupRequested = false;
    #else
    fullCleanupRequested = false;
    #end
  }

  public static function requestGameplayOptimization():Void
  {
    #if (cpp && (windows || linux || macos))
    if (gameplayOptimizationQueued) return;
    gameplayOptimizationQueued = true;
    FlxG.signals.postUpdate.addOnce(optimizeGameplayMemory);
    #end
  }

  public static function releaseSounds(paths:Array<String>):Void
  {
    for (path in paths)
    {
      if (path == null || path == '') continue;

      @:privateAccess FunkinMemory.currentCachedSounds.remove(path);
      @:privateAccess FunkinMemory.previousCachedSounds.remove(path);
      @:privateAccess if (!FunkinMemory.permanentCachedSounds.exists(path)) Assets.cache.removeSound(path);
    }
  }

  static function optimizeGameplayMemory():Void
  {
    gameplayOptimizationQueued = false;

    #if (cpp && (windows || linux || macos))
    final context = FlxG.stage?.context3D;
    if (context == null) return;

    @:privateAccess final cache = FlxG.bitmap._cache;
    if (cache == null) return;

    for (key in cache.keys())
    {
      final graphic = cache.get(key);
      final bitmap = graphic?.bitmap;
      if (graphic == null || bitmap == null || !bitmap.readable || graphic.assetsKey == null || graphic.unique || graphic.useCount <= 0) continue;
      if (bitmap.width * bitmap.height * 4.0 < LARGE_TEXTURE_BYTES) continue;
      if (key.contains('chart-editor') || key.contains('charSelect') || key.contains('freeplay') || key.contains('fonts')) continue;

      try
      {
        bitmap.getTexture(context);
        bitmap.disposeImage();
        bitmap.getTexture(context);
      }
      catch (e:Dynamic)
      {
        FlxG.log.warn('Could not release the CPU copy of $key: ${Std.string(e)}');
      }
    }

    MemoryUtil.collect(true);
    #end
  }

  static function onStateSwitchComplete():Void
  {
    completeRequestedCleanup();
  }
}