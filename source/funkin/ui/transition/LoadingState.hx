package funkin.ui.transition;

import funkin.data.notestyle.NoteStyleRegistry;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.util.typeLimit.NextState;
import funkin.graphics.FunkinSprite;
import funkin.graphics.shaders.ScreenWipeShader;
import funkin.play.PlayState;
import funkin.play.PlayStatePlaylist;
import funkin.play.song.Song.SongDifficulty;
import funkin.play.stage.Stage;
import funkin.Preferences;
import haxe.io.Path;
import lime.app.Future;
import lime.app.Promise;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets as LimeAssets;
import openfl.filters.ShaderFilter;
import openfl.utils.Assets as OpenFLAssets;
import funkin.util.assets.ResourceCache;

typedef SongAudioLoad =
{
  var path:String;
  var callback:Void->Void;
}

@:nullSafety
class LoadingState extends MusicBeatSubState
{
  inline static var MIN_TIME = 0.1;

  var asSubState:Bool = false;
  var target:NextState;
  var playParams:Null<PlayStateParams>;
  var stopMusic:Bool = false;
  var callbacks:Null<MultiCallback>;
  var danceLeft:Bool = false;
  var loadBar:FlxSprite;
  var funkay:FlxSprite;
  var resourcePlan:Null<SongResourcePlan>;
  var loadGeneration:Int = 0;
  var cancelled:Bool = false;
  var failed:Bool = false;
  var loadStartedAt:Float = 0;
  var audioQueue:Array<SongAudioLoad> = [];
  var activeAudioLoads:Int = 0;

  function new(target:NextState, stopMusic:Bool, ?playParams:PlayStateParams)
  {
    super();
    this.target = target;
    this.playParams = playParams;
    this.stopMusic = stopMusic;
    this.resourcePlan = playParams == null ? null : SongResourcePlan.build(playParams);

    this.loadBar = new FunkinSprite(0, FlxG.height - 20).makeSolidColor(0, 10, 0xFFff16d2);
    this.funkay = FunkinSprite.create('funkay');
  }

  override function create():Void
  {
    loadStartedAt = haxe.Timer.stamp();
    loadGeneration = ResourceCache.generation;
    var bg:FunkinSprite = new FunkinSprite().makeSolidColor(FlxG.width, FlxG.height, 0xFFcaff4d);
    add(bg);

    funkay.setGraphicSize(0, FlxG.height);
    funkay.updateHitbox();
    add(funkay);
    funkay.scrollFactor.set();
    funkay.screenCenter();

    add(loadBar);

    initSongsManifest().onComplete(function(lib)
    {
      if (cancelled || failed || loadGeneration != ResourceCache.generation) return;
      callbacks = new MultiCallback(onLoad);
      var introComplete = callbacks.add('introComplete');

      if (playParams != null)
      {
        // Load and cache the song's charts.
        if (playParams.targetSong == null)
        {
          throw 'Invalid parameter: Target song should not be null';
        }

        queueSongAudio(resourcePlan?.audioPaths ?? []);
        var visualComplete = callbacks.add('visuals');
        new FlxTimer().start(0, _ ->
        {
          if (cancelled || failed || loadGeneration != ResourceCache.generation) return;
          try
          {
            resourcePlan?.preloadVisuals();
            visualComplete();
          }
          catch (error:Dynamic)
          {
            failLoad(error);
          }
        });
      }

      checkLibrary('shared');
      checkLibrary('videos');
      checkLibrary(stageDirectory);
      checkLibrary('tutorial');

      var fadeTime:Float = 0.5;
      FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
      new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());
    }).onError(failLoad);
  }

  function queueSongAudio(paths:Array<String>):Void
  {
    for (path in paths)
    {
      if (OpenFLAssets.cache.hasSound(path)) continue;
      var callback = callbacks?.add('song:' + path);
      if (callback != null) audioQueue.push({path: path, callback: cast callback});
    }
    pumpSongAudio();
  }

  function pumpSongAudio():Void
  {
    while (!cancelled && !failed && activeAudioLoads < 4 && audioQueue.length > 0)
    {
      final request:Null<SongAudioLoad> = audioQueue.shift();
      if (request == null) return;
      activeAudioLoads++;
      var soundFuture:Future<openfl.media.Sound>;
      try
      {
        soundFuture = Assets.loadSound(request.path);
      }
      catch (error:Dynamic)
      {
        activeAudioLoads--;
        failLoad('Could not load song audio "${request.path}": ${Std.string(error)}');
        return;
      }
      soundFuture.onComplete(function(sound)
      {
        activeAudioLoads--;
        if (cancelled || loadGeneration != ResourceCache.generation)
        {
          if (OpenFLAssets.cache.getSound(request.path) == sound) OpenFLAssets.cache.removeSound(request.path);
          return;
        }
        request.callback();
        pumpSongAudio();
      }).onError(error ->
        {
          activeAudioLoads--;
          failLoad('Could not load song audio "${request.path}": ${Std.string(error)}');
        });
    }
  }

  function checkLibrary(library:String):Void
  {
    trace(Assets.hasLibrary(library));
    if (Assets.getLibrary(library) == null)
    {
      @:privateAccess
      if (!LimeAssets.libraryPaths.exists(library)) throw 'Missing library: ' + library;

      var callback = callbacks?.add('library:' + library);
      Assets.loadLibrary(library).onComplete(function(_)
      {
        if (!cancelled && loadGeneration == ResourceCache.generation && callback != null) callback();
      }).onError(error -> failLoad('Could not load asset library "$library": ${Std.string(error)}'));
    }
  }

  override function beatHit():Bool
  {
    // super.beatHit() returns false if a module cancelled the event.
    if (!super.beatHit()) return false;

    danceLeft = !danceLeft;

    return true;
  }

  var targetShit:Float = 0;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!cancelled && !failed && loadGeneration != ResourceCache.generation)
    {
      failLoad('Resources changed while the song was loading.');
      return;
    }

    funkay.setGraphicSize(Std.int(FlxMath.lerp(FlxG.width * 0.88, funkay.width, 0.9)));
    funkay.updateHitbox();
    // funkay.updateHitbox();

    if (controls.ACCEPT_P)
    {
      funkay.setGraphicSize(Std.int(funkay.width + 60));
      funkay.updateHitbox();
      // funkay.setGraphicSize(0, Std.int(funkay.height + 50));
      // funkay.updateHitbox();
      // funkay.screenCenter();
    }

    if (callbacks != null)
    {
      targetShit = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);

      var lerpWidth:Int = Std.int(FlxMath.lerp(loadBar.width, FlxG.width * targetShit, 0.2));
      // this if-check prevents the setGraphicSize function
      // from setting the width of the loadBar to the height of the loadBar
      // this is a behaviour that is implemented in the setGraphicSize function
      // if the width parameter is equal to 0
      if (lerpWidth > 0)
      {
        loadBar.setGraphicSize(lerpWidth, loadBar.height);
        loadBar.updateHitbox();
      }
      FlxG.watch.addQuick('percentage?', callbacks.numRemaining / callbacks.length);
    }
  }

  function onLoad():Void
  {
    if (cancelled || loadGeneration != ResourceCache.generation) return;
    #if debug
    trace('Song resources loaded in ${Math.round((haxe.Timer.stamp() - loadStartedAt) * 1000)} ms');
    #end
    // Stop the instrumental.
    @:nullSafety(Off)
    if (stopMusic && FlxG.sound.music != null)
    {
      FlxG.sound.music.destroy();
      FlxG.sound.music = null;
    }

    if (asSubState)
    {
      final targetState = target.createInstance();
      if (!Std.isOfType(targetState, FlxSubState))
      {
        failLoad('The requested playtest state is not a substate.');
        return;
      }
      FlxG.state.openSubState(cast targetState);
    }
    else
    {
      FlxG.switchState(target);
    }
  }

  function failLoad(error:Dynamic):Void
  {
    if (cancelled || failed) return;
    failed = true;
    cancelled = true;
    final message:String = Std.string(error);
    trace('Loading failed: $message');
    funkin.util.WindowUtil.showError('Loading Failed', message);
    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  static var stageDirectory:String = "shared";

  /**
   * Starts the transition to a new `PlayState` to start a new song.
   * First switches to the `LoadingState` if assets need to be loaded.
   * @param params The parameters for the next `PlayState`.
   * @param asSubState Whether to open as a substate rather than switching to the `PlayState`.
   * @param shouldStopMusic Whether to stop the current music while loading.
   */
  public static function loadPlayState(params:PlayStateParams, shouldStopMusic = false, asSubState = false, ?onConstruct:PlayState->Void):Void
  {
    var daChart:Null<SongDifficulty> = params.targetSong?.getDifficulty(params.targetDifficulty ?? Constants.DEFAULT_DIFFICULTY,
      params.targetVariation ?? Constants.DEFAULT_VARIATION);

    var daStage:Null<Stage> = funkin.data.stage.StageRegistry.instance.fetchEntry(daChart?.stage ?? Constants.DEFAULT_STAGE);
    stageDirectory = daStage?._data?.directory ?? "shared";
    Paths.setCurrentLevel(stageDirectory);

    if (funkin.ui.FullScreenScaleMode.instance != null) funkin.ui.FullScreenScaleMode.instance.onMeasurePostAwait();

    var playStateCtor:() -> PlayState = function()
    {
      return new PlayState(params);
    };

    if (onConstruct != null)
    {
      playStateCtor = function()
      {
        var result = new PlayState(params);
        onConstruct(result);
        return result;
      };
    }

    #if (PRELOAD_ALL || NO_PRELOAD_ALL)
    if (Preferences.loadingScreens)
    {
      var loadStateCtor = function()
      {
        var result = new LoadingState(playStateCtor, shouldStopMusic, params);
        @:privateAccess
        result.asSubState = asSubState;
        return result;
      }
      if (asSubState)
      {
        FlxG.state.openSubState(cast loadStateCtor());
      }
      else
      {
        #if PRELOAD_ALL
        FlxG.signals.preStateSwitch.addOnce(function()
        {
          funkin.FunkinMemory.clearFreeplay();
          funkin.FunkinMemory.purgeCache(true);
        });
        #end
        FlxG.switchState(loadStateCtor);
      }
      return;
    }
    #end

    // All assets preloaded, switch directly to play state (default on other targets).
    @:nullSafety(Off)
    if (shouldStopMusic && FlxG.sound.music != null)
    {
      FlxG.sound.music.destroy();
      FlxG.sound.music = null;
    }

    var resourcePlan:SongResourcePlan = SongResourcePlan.build(params);
    resourcePlan.preloadAudio();

    var shouldPreloadLevelAssets:Bool = !(params?.minimalMode ?? false);

    if (shouldPreloadLevelAssets)
    {
      #if !NO_PRELOAD_ALL
      preloadLevelAssets();
      #end

      resourcePlan.preloadVisuals();

      // TODO: This sucks lol.
      if (params.targetSong.songName == "2hot")
      {
        var spritesToCache = [
          "wked1_cutscene_1_can",
          "spraypaintExplosionEZ",
          "SpraypaintExplosion",
          "CanImpactParticle",
          "spraycanAtlas/spritemap1"
        ];

        var soundsToCache = [
          "Darnell_Lighter",
          "fuse_burning",
          "Gun_Prep",
          "Kick_Can_FORWARD",
          "Kick_Can_UP",
          "Lightning1",
          "Lightning2",
          "Lightning3",
          "Pico_Bonk",
          "Shoot_1",
          "shot1",
          "shot2",
          "shot3",
          "shot4"
        ];

        for (sprite in spritesToCache)
        {
          trace('Queueing $sprite to preload.');
          // new Future<String>(function() {
          var path = Paths.image(sprite, "weekend1");
          funkin.FunkinMemory.cacheTexture(path);
          // Another dumb hack: FlxAnimate fetches from OpenFL's BitmapData cache directly and skips the FlxGraphic cache.
          // Since FlxGraphic tells OpenFL to not cache it, we have to do it manually.
          if (path.endsWith('spritemap1.png') #if FEATURE_COMPRESSED_TEXTURES || path.endsWith('spritemap1.astc') #end)
          {
            trace('Preloading FlxAnimate asset: ${path}');
            openfl.Assets.getBitmapData(path, true);
          }
          // return '${path} successfuly loaded.';
          // }, true);
        }

        for (sound in soundsToCache)
        {
          trace('Queueing $sound to preload.');
          new Future<String>(function()
          {
            var path = Paths.sound(sound, "weekend1");
            funkin.FunkinMemory.cacheSound(path);
            return '${path} successfuly loaded.';
          }, true);
        }
      }
    }

    if (asSubState)
    {
      FlxG.state.openSubState(cast playStateCtor());
    }
    else
    {
      // funkin.FunkinMemory.clearFreeplay();
      FlxG.signals.preStateSwitch.addOnce(function()
      {
        funkin.FunkinMemory.clearFreeplay();
        funkin.FunkinMemory.purgeCache(true);
      });
      FlxG.switchState(playStateCtor);
    }
  }

  #if NO_PRELOAD_ALL
  static function isSoundLoaded(path:String):Bool
  {
    return OpenFLAssets.cache.hasSound(path);
  }

  static function isLibraryLoaded(library:String):Bool
  {
    return Assets.getLibrary(library) != null;
  }
  #else
  static function preloadLevelAssets():Void
  {
    // TODO: This section is a hack! Redo this later when we have a proper asset caching system.
    // FunkinSprite.preparePurgeCache();
    // funkin.FunkinMemory.purgeSoundCache();

    // List all image assets in the level's library.

    // This is crude and I want to remove it when we have a proper asset caching system.
    // TODO: Get rid of this junk!
    // var library = PlayStatePlaylist.campaignId != null ? openfl.utils.Assets.getLibrary(PlayStatePlaylist.campaignId) : null;

    // if (library == null) return; // We don't need to do anymore precaching.

    // var assets = library.list(lime.utils.AssetType.IMAGE);
    // trace('Got ${assets.length} assets: ${assets}');

    // TODO: assets includes non-images! This is a bug with Polymod
    // for (asset in assets)
    // {
    //   // Exclude items of the wrong type.
    //   var path = '${PlayStatePlaylist.campaignId}:${asset}';
    //   // TODO DUMB HACK DUMB HACK why doesn't filtering by AssetType.IMAGE above work
    //   // I will fix this properly later I swear -eric
    //   if (!path.endsWith('.png')) continue;

    //   new Future<String>(function() {
    //     FunkinSprite.cacheTexture(path);
    //     // Another dumb hack: FlxAnimate fetches from OpenFL's BitmapData cache directly and skips the FlxGraphic cache.
    //     // Since FlxGraphic tells OpenFL to not cache it, we have to do it manually.
    //     if (path.endsWith('spritemap1.png'))
    //     {
    //       trace('Preloading FlxAnimate asset: ${path}');
    //       openfl.Assets.getBitmapData(path, true);
    //     }
    //     return 'Done precaching ${path}';
    //   }, true);

    //   trace('Queued ${path} for precaching');
    //   // FunkinSprite.cacheTexture(path);
    // }

    // FunkinSprite.cacheAllNoteStyleTextures(noteStyle) // This will replace the stuff above!
    // FunkinSprite.cacheAllCharacterTextures(player)
    // FunkinSprite.cacheAllCharacterTextures(girlfriend)
    // FunkinSprite.cacheAllCharacterTextures(opponent)
    // FunkinSprite.cacheAllStageTextures(stage)
    // FunkinSprite.cacheAllSongTextures(stage)

    // FunkinSprite.purgeCache();
  }
  #end

  override function destroy():Void
  {
    cancelled = true;
    super.destroy();

    callbacks = null;
    audioQueue.resize(0);
  }

  static function initSongsManifest():Future<AssetLibrary>
  {
    var id = 'songs';
    var promise = new Promise<AssetLibrary>();

    var library = LimeAssets.getLibrary(id);

    if (library != null)
    {
      return Future.withValue(library);
    }

    var path = id;
    var rootPath = null;

    @:privateAccess
    var libraryPaths = LimeAssets.libraryPaths;
    if (libraryPaths.exists(id))
    {
      path = libraryPaths[id] ?? path;
      rootPath = Path.directory(path);
    }
    else
    {
      if (path.endsWith('.bundle'))
      {
        rootPath = path;
        path += '/library.json';
      }
      else
      {
        rootPath = Path.directory(path);
      }
      @:privateAccess
      path = LimeAssets.__cacheBreak(path);
    }

    AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
    {
      if (manifest == null)
      {
        promise.error('Cannot parse asset manifest for library \'' + id + '\'');
        return;
      }

      var library = AssetLibrary.fromManifest(manifest);

      if (library == null)
      {
        promise.error('Cannot open library \'' + id + '\'');
      }
      else
      {
        @:privateAccess
        LimeAssets.libraries.set(id, library);
        library.onChange.add(LimeAssets.onChange.dispatch);
        promise.completeWith(Future.withValue(library));
      }
    }).onError(function(_)
    {
        promise.error('There is no asset library with an ID of \'' + id + '\'');
    });

    return promise.future;
  }

  public static function transitionToState(state:NextState, stopMusic:Bool = false):Void
  {
    if (Preferences.loadingScreens)
    {
      FlxG.switchState(() -> new LoadingState(state, stopMusic));
    }
    else
    {
      @:nullSafety(Off)
      if (stopMusic && FlxG.sound.music != null)
      {
        FlxG.sound.music.destroy();
        FlxG.sound.music = null;
      }
      FlxG.switchState(state);
    }
  }
}

@:nullSafety
class MultiCallback
{
  public var callback:Void->Void;
  public var logId:Null<String>;
  public var length(default, null) = 0;
  public var numRemaining(default, null) = 0;

  var unfired = new Map<String, Void->Void>();
  var fired = new Array<String>();

  public function new(callback:Void->Void, ?logId:String)
  {
    this.callback = callback;
    this.logId = logId;
  }

  public function add(id = 'untitled'):Void->Void
  {
    id = '$length:$id';
    length++;
    numRemaining++;
    var func:Void->Void = function()
    {
      if (unfired.exists(id))
      {
        unfired.remove(id);
        fired.push(id);
        numRemaining--;

        if (logId != null) log('fired $id, $numRemaining remaining');

        if (numRemaining == 0)
        {
          if (logId != null) log('all callbacks fired');
          callback();
        }
      }
      else
        log('already fired $id');
    }
    unfired[id] = func;
    return func;
  }

  inline function log(msg):Void
  {
    if (logId != null) trace('$logId: $msg');
  }

  public function getFired():Array<String> return fired.copy();

  public function getUnfired():Array<Void->Void> return unfired.array();

  /**
   * Perform an FlxG.switchState with a nice transition
   * @param state
   * @param transitionTex
   * @param time
   */
  public static function coolSwitchState(state:NextState, transitionTex:String = "shaderTransitionStuff/coolDots", time:Float = 2)
  {
    var screenShit:FunkinSprite = FunkinSprite.create('shaderTransitionStuff/coolDots');
    var screenWipeShit:ScreenWipeShader = new ScreenWipeShader();

    screenWipeShit.funnyShit.input = screenShit.pixels;
    FlxTween.tween(screenWipeShit, {daAlphaShit: 1}, time, {
      ease: FlxEase.quadInOut,
      onComplete: function(twn)
      {
        screenShit.destroy();
        FlxG.switchState(state);
      }
    });
    FlxG.camera.filters = [
      new ShaderFilter(screenWipeShit)
    ];
  }
}
