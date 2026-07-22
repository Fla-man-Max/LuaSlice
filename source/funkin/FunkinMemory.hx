package funkin;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import funkin.luasliceMemory.MemoryCleanup;
import funkin.play.notes.notestyle.NoteStyle;
import openfl.Assets;
import openfl.media.Sound;
import lime.app.Future;
import lime.app.Promise;

/**
 * Handles caching of textures and sounds for the game.
 * I did this hello, this can be improved later on and I have ideas on how, but for now this functions well enough. -Zack
 */
@:nullSafety
class FunkinMemory
{
  static var permanentCachedTextures:Map<String, FlxGraphic> = [];
  static var currentCachedTextures:Map<String, FlxGraphic> = [];
  static var previousCachedTextures:Map<String, FlxGraphic> = [];

  static var permanentCachedSounds:Map<String, Sound> = [];
  static var currentCachedSounds:Map<String, Sound> = [];
  static var previousCachedSounds:Map<String, Sound> = [];
  static var stateCacheOpen:Bool = false;

  /**
   * Caches textures that are always required.
   */
  public static inline function initialCache():Void
  {
    MemoryCleanup.initialize();

    permanentCacheTexture(Paths.image("menuDesat"));
    permanentCacheTexture(Paths.image("fonts/bold", null));
    permanentCacheTexture(Paths.image("fonts/default", null));

    permanentCacheSound(Paths.sound("cancelMenu"));
    permanentCacheSound(Paths.sound("confirmMenu"));
    permanentCacheSound(Paths.sound("screenshot"));
    permanentCacheSound(Paths.sound("scrollMenu"));
    permanentCacheSound(Paths.sound("soundtray/Voldown"));
    permanentCacheSound(Paths.sound("soundtray/VolMAX"));
    permanentCacheSound(Paths.sound("soundtray/Volup"));
    permanentCacheSound(Paths.music("freakyMenu/freakyMenu"));
  }

  /**
   * Clears the current texture and sound caches.
   * @param callGarbageCollector Whether to call the system's garbage collector after purging.
   */
  public static inline function purgeCache(callGarbageCollector:Bool = false):Void
  {
    if (stateCacheOpen)
    {
      finishStateCache(callGarbageCollector);
      return;
    }

    beginStateCache();
    finishStateCache(callGarbageCollector);
  }

  public static function beginStateCache():Void
  {
    if (stateCacheOpen) return;
    preparePurgeTextureCache();
    preparePurgeSoundCache();
    stateCacheOpen = true;
  }

  public static function finishStateCache(callGarbageCollector:Bool = false):Void
  {
    if (stateCacheOpen)
    {
      purgeTextureCache();
      purgeSoundCache();
      stateCacheOpen = false;
    }

    #if (cpp || neko || hl)
    if (callGarbageCollector) funkin.util.MemoryUtil.collect(true);
    #end
  }

  ///// TEXTURES /////

  /**
   * Ensures a texture with the given key is cached.
   * @param key The key of the texture to cache.
   */
  public static function cacheTexture(key:String):Void
  {
    if (currentCachedTextures.exists(key)) return;

    if (previousCachedTextures.exists(key))
    {
      // Move the texture from the previous cache to the current cache.
      var graphic:Null<FlxGraphic> = previousCachedTextures.get(key);
      previousCachedTextures.remove(key);
      if (graphic != null) currentCachedTextures.set(key, graphic);
      return;
    }

    var graphic:Null<FlxGraphic> = FlxGraphic.fromAssetKey(key, false, null, true);
    if (graphic == null)
    {
      FlxG.log.warn('Failed to cache graphic: $key');
      return;
    }

    log('Cached asset $key');
    graphic.persist = true;
    currentCachedTextures.set(key, graphic);
    forceRender(graphic);
  }

  /**
   * Permanently caches a texture with the given key.
   * @param key The key of the texture to cache.
   */
  static function permanentCacheTexture(key:String):Void
  {
    if (permanentCachedTextures.exists(key)) return;

    var graphic:Null<FlxGraphic> = FlxGraphic.fromAssetKey(key, false, null, true);
    if (graphic == null)
    {
      FlxG.log.warn('Failed to cache graphic: $key');
      return;
    }

    log('Cached graphic $key');
    graphic.persist = true;
    permanentCachedTextures.set(key, graphic);
    forceRender(graphic);
    currentCachedTextures = permanentCachedTextures.copy();
  }

  public static function getCachedGraphic(path:String):Null<FlxGraphic>
  {
    if (permanentCachedTextures.exists(path)) return permanentCachedTextures.get(path);
    if (currentCachedTextures.exists(path)) return currentCachedTextures.get(path);
    if (previousCachedTextures.exists(path)) return previousCachedTextures.get(path); // just in case

    return null;
  }

  /**
   * Prepares the cache for purging unused textures.
   */
  public inline static function preparePurgeTextureCache():Void
  {
    previousCachedTextures = currentCachedTextures.copy();

    for (graphicKey in previousCachedTextures.keys())
    {
      if (permanentCachedTextures.exists(graphicKey))
      {
        previousCachedTextures.remove(graphicKey);
      }
    }

    currentCachedTextures = permanentCachedTextures.copy();
  }

  /**
   * Purges unused textures from the cache.
   */
  public static function purgeTextureCache():Void
  {
    for (graphicKey in previousCachedTextures.keys())
    {
      if (permanentCachedTextures.exists(graphicKey))
      {
        previousCachedTextures.remove(graphicKey);
        continue;
      }

      var graphic:Null<FlxGraphic> = previousCachedTextures.get(graphicKey);
      previousCachedTextures.remove(graphicKey);
      if (graphic != null && !graphicKey.contains("fonts")) graphic.persist = false;
    }

    flixel.FlxG.bitmap.clearUnused();
  }

  /**
   * Forces the GPU to load and upload a FlxGraphic.
   * @param graphic The graphic to force render.
   */
  private static function forceRender(graphic:FlxGraphic):Void
  {
    if (graphic == null) return;

    try
    {
      var bmp:Null<FlxGraphic> = FlxG.bitmap.get(graphic.key);
      if (bmp != null && bmp.bitmap != null) var _:Int = bmp.bitmap.width; // Trigger

      var sprite = new flixel.FlxSprite();
      sprite.loadGraphic(graphic);
      sprite.draw(); // Draw sprite and load it into game's memory.
      sprite.destroy();

      final context = FlxG.stage?.context3D;
      if (context != null && graphic.bitmap != null) graphic.bitmap.getTexture(context);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to force-render cached graphic ${graphic.key}: $e');
    }
  }

  /**
   * Determine whether the texture with the given key is cached.
   * @param key The key of the texture to check.
   * @return Whether the texture is cached.
   */
  public static function isTextureCached(key:String):Bool
  {
    return FlxG.bitmap.get(key) != null
      && (permanentCachedTextures.exists(key) || currentCachedTextures.exists(key) || previousCachedTextures.exists(key));
  }

  ///// NOTE STYLE //////

  /**
   *  Caches all assets for the given note style.
   * @param style The note style to cache.
   */
  public static function cacheNoteStyle(style:NoteStyle):Void
  {
    // TODO: Texture paths should fall back to the default values.
    cacheTexture(Paths.image(style.getNoteAssetPath() ?? "note"));
    cacheTexture(style.getHoldNoteAssetPath() ?? "noteHold");
    cacheTexture(Paths.image(style.getStrumlineAssetPath() ?? "strumline"));
    if (!Preferences.isLowQualityMax())
    {
      cacheTexture(Paths.image(style.getSplashAssetPath() ?? "noteSplash"));
      cacheTexture(Paths.image(style.getHoldCoverDirectionAssetPath(LEFT) ?? "LEFT"));
      cacheTexture(Paths.image(style.getHoldCoverDirectionAssetPath(RIGHT) ?? "RIGHT"));
      cacheTexture(Paths.image(style.getHoldCoverDirectionAssetPath(UP) ?? "UP"));
      cacheTexture(Paths.image(style.getHoldCoverDirectionAssetPath(DOWN) ?? "DOWN"));
    }

    // cacheTexture(Paths.image(style.buildCountdownSpritePath(THREE) ?? "THREE"));
    cacheTexture(Paths.image(style.buildCountdownSpritePath(TWO) ?? "TWO"));
    cacheTexture(Paths.image(style.buildCountdownSpritePath(ONE) ?? "ONE"));
    cacheTexture(Paths.image(style.buildCountdownSpritePath(GO) ?? "GO"));

    cacheSound(style.getCountdownSoundPath(THREE) ?? "THREE");
    cacheSound(style.getCountdownSoundPath(TWO) ?? "TWO");
    cacheSound(style.getCountdownSoundPath(ONE) ?? "ONE");
    cacheSound(style.getCountdownSoundPath(GO) ?? "GO");

    cacheTexture(Paths.image(style.buildJudgementSpritePath("sick") ?? 'sick'));
    cacheTexture(Paths.image(style.buildJudgementSpritePath("good") ?? 'good'));
    cacheTexture(Paths.image(style.buildJudgementSpritePath("bad") ?? 'bad'));
    cacheTexture(Paths.image(style.buildJudgementSpritePath("shit") ?? 'shit'));

    if (!Preferences.isLowQualityMax())
    {
      cacheTexture(Paths.image(style.buildComboNumSpritePath(0) ?? '0'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(1) ?? '1'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(2) ?? '2'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(3) ?? '3'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(4) ?? '4'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(5) ?? '5'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(6) ?? '6'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(7) ?? '7'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(8) ?? '8'));
      cacheTexture(Paths.image(style.buildComboNumSpritePath(9) ?? '9'));
    }

    cacheSound(Paths.sound("missnote1", "shared"));
    cacheSound(Paths.sound("missnote2", "shared"));
    cacheSound(Paths.sound("missnote3", "shared"));
  }

  ///// SOUND //////

  /**
   * Caches a sound with the given key.
   * @param key The key of the sound to cache.
   */
  public static function cacheSound(key:String):Void
  {
    if (currentCachedSounds.exists(key)) return;

    if (previousCachedSounds.exists(key))
    {
      // Move the texture from the previous cache to the current cache.
      var sound:Null<Sound> = previousCachedSounds.get(key);
      previousCachedSounds.remove(key);
      if (sound != null) currentCachedSounds.set(key, sound);
      return;
    }

    var sound:Null<Sound> = null;
    try
    {
      sound = Assets.getSound(key, true);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to cache sound $key: ${Std.string(e)}');
      return;
    }
    if (sound == null) return;
    else
      currentCachedSounds.set(key, sound);
  }

  /**
   * Permanently caches a sound with the given key.
   * @param key The key of the sound to cache.
   */
  public static function permanentCacheSound(key:String):Void
  {
    if (permanentCachedSounds.exists(key)) return;

    var sound:Null<Sound> = null;
    try
    {
      sound = Assets.getSound(key, true);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to cache permanent sound $key: ${Std.string(e)}');
      return;
    }
    if (sound == null) return;
    else
      permanentCachedSounds.set(key, sound);

    if (sound != null) currentCachedSounds.set(key, sound);
  }

  /**
   * Prepares the cache for purging unused sounds.
   */
  public static function preparePurgeSoundCache():Void
  {
    previousCachedSounds = currentCachedSounds.copy();

    for (key in previousCachedSounds.keys())
    {
      if (permanentCachedSounds.exists(key))
      {
        previousCachedSounds.remove(key);
      }
    }

    currentCachedSounds = permanentCachedSounds.copy();
  }

  /**
   * Purges unused sounds from the cache.
   */
  public static inline function purgeSoundCache():Void
  {
    for (key in previousCachedSounds.keys())
    {
      if (permanentCachedSounds.exists(key))
      {
        previousCachedSounds.remove(key);
        continue;
      }

      var sound:Null<Sound> = previousCachedSounds.get(key);
      if (sound != null)
      {
        Assets.cache.removeSound(key);
        previousCachedSounds.remove(key);
      }
    }
    var key = Paths.music("freakyMenu/freakyMenu");
    var sound:Null<Sound> = null;
    try
    {
      sound = Assets.getSound(key, true);
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('Failed to restore menu music cache $key: ${Std.string(e)}');
    }
    if (sound != null)
    {
      permanentCachedSounds.set(key, sound);
      currentCachedSounds.set(key, sound);
    }
  }

  ///// MISC /////

  /**
   * Clears all Freeplay assets from memory.
   */
  public static inline function clearFreeplay():Void
  {
    var keysToRemove:Array<String> = [];

    @:privateAccess
    for (key in FlxG.bitmap._cache.keys())
    {
      if (!key.contains("freeplay")) continue;
      if (permanentCachedTextures.exists(key) || key.contains("fonts")) continue;

      keysToRemove.push(key);
    }

    @:privateAccess
    for (key in keysToRemove)
    {
      log('Cleaning asset $key');
      var obj:Null<FlxGraphic> = FlxG.bitmap.get(key);
      if (obj != null) obj.persist = false;
      currentCachedTextures.remove(key);
      previousCachedTextures.remove(key);
    }
  }

  /**
   * Clears all sticker assets from memory.
   */
  public static inline function clearStickers():Void
  {
    var keysToRemove:Array<String> = [];

    @:privateAccess
    for (key in FlxG.bitmap._cache.keys())
    {
      if (!key.contains("stickers")) continue;
      if (permanentCachedTextures.exists(key) || key.contains("fonts")) continue;

      keysToRemove.push(key);
    }

    @:privateAccess
    for (key in keysToRemove)
    {
      log('Cleaning asset $key');
      var obj:Null<FlxGraphic> = FlxG.bitmap.get(key);
      if (obj != null) obj.persist = false;
      currentCachedTextures.remove(key);
      previousCachedTextures.remove(key);
    }
  }

  /**
   * Sends a trace with fancy ANSI colors.
   * @param message The message to log.
   */
  private static function log(message:String):Void
  {
    trace(' MEMORY '.bg_bright_lilac().bold() + ' ${message}');
  }
}
