package funkin.ui.charSelect;

import funkin.graphics.FunkinSprite;
import funkin.modding.IScriptedClass.IBPMSyncedScriptedClass;
import funkin.modding.events.ScriptEvent;
import funkin.vis.dsp.SpectralAnalyzer;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.ui.FullScreenScaleMode;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;

@:nullSafety
class CharSelectGF extends FunkinSprite implements IBPMSyncedScriptedClass
{
  var analyzer:Null<SpectralAnalyzer>;
  var analyzerLevelsCache:Array<Bar> = new Array<Bar>();
  var analyzerSound:Null<FlxSound>;
  var analyzerTimer:Float = 0;

  var currentGFPath:String = "";
  var enableVisualizer:Bool = false;

  var danceEvery:Int = 2;

  public function new(x:Float, y:Float)
  {
    super(x, y);
    this.applyStageMatrix = true;

    switchGF(Constants.DEFAULT_CHARACTER);
  }

  public function onStepHit(event:SongTimeScriptEvent):Void
  {
  }

  public function onBeatHit(event:SongTimeScriptEvent):Void
  {
    // TODO: There's a minor visual bug where there's a little stutter.
    // This happens because the animation is getting restarted while it's already playing.
    // I tried make this not interrupt an existing idle,
    // but isAnimationFinished() and isLoopComplete() both don't work! What the hell?
    // danceEvery isn't necessary if that gets fixed.
    if (getCurrentAnimation() == "idle" && (event.beat % danceEvery == 0))
    {
      anim.play("idle", true);
    }
  };

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (enableVisualizer && analyzer == null && analyzerSound != null)
    {
      analyzerRetryTimer -= elapsed;
      if (analyzerRetryTimer <= 0)
      {
        analyzerRetryTimer = 0.25;
        initAnalyzer(analyzerSound);
      }
    }
    analyzerTimer += elapsed;
    if (analyzerTimer >= 1 / 30)
    {
      analyzerTimer %= 1 / 30;
      if (analyzer != null) drawFFT();
    }
  }

  var analyzerRetryTimer:Float = 0;

  public function initAnalyzer(sound:Null<FlxSound>):Void
  {
    analyzer = null;
    analyzerSound = sound;
    final targetSound = analyzerSound;
    if (targetSound == null || !targetSound.exists) return;
    @:privateAccess
    final channel = targetSound._channel;
    if (channel == null) return;
    @:privateAccess
    final source = channel.__audioSource;
    if (source == null) return;

    try
    {
      final nextAnalyzer = new SpectralAnalyzer(source, 7, 0.1);
      #if sys
      nextAnalyzer.fftN = 512;
      #end
      analyzer = nextAnalyzer;
    }
    catch (_:Dynamic)
    {
      analyzer = null;
    }
  }

  function drawFFT():Void
  {
    if (enableVisualizer && analyzer != null)
    {
      if (!hasAudioSource())
      {
        analyzer = null;
        return;
      }
      try
      {
        final activeAnalyzer = analyzer;
        if (activeAnalyzer == null) return;
        analyzerLevelsCache = activeAnalyzer.getLevels(analyzerLevelsCache);
      }
      catch (_:Dynamic)
      {
        analyzer = null;
        return;
      }
      var frame:Null<animate.internal.Frame> = this.timeline.getLayer("VIZ_bars")?.getFrameAtIndex(anim.curAnim.curFrame) ?? null;
      var elements:Array<animate.internal.elements.Element> = frame?.elements ?? [];
      var len:Int = cast Math.min(elements.length, 7);

      for (i in 0...len)
      {
        var animFrame:Int = (FlxG.sound.volume == 0 || FlxG.sound.muted) ? 0 : Math.round(analyzerLevelsCache[i].value * 12);

        #if sys
        // Web version scales with the Flixel volume level.
        // This line brings platform parity but looks worse.
        // animFrame = Math.round(animFrame * FlxG.sound.volume);
        #end

        animFrame = Math.floor(Math.min(12, animFrame));
        animFrame = Math.floor(Math.max(0, animFrame));

        animFrame = Std.int(Math.abs(animFrame - 12)); // shitty dumbass flip, cuz dave got da shit backwards lol!

        var convertedSymbol = elements[i].toSymbolInstance();
        convertedSymbol.firstFrame = animFrame;

        elements[i] = convertedSymbol;
      }
    }
  }

  function hasAudioSource():Bool
  {
    final sound = analyzerSound;
    if (sound == null || !sound.exists) return false;
    @:privateAccess
    final channel = sound._channel;
    if (channel == null) return false;
    @:privateAccess
    return channel.__audioSource != null;
  }

  /**
   * For switching between "GFs" such as gf, nene, etc
   * @param bf Which BF we are selecting, so that we know the accompyaning GF
   */
  public function switchGF(bf:String):Void
  {
    var previousGFPath:String = currentGFPath;

    var bfObj = PlayerRegistry.instance.fetchEntry(bf);
    var gfData = bfObj?.getCharSelectData()?.gf;
    var assetPath:Null<String> = gfData?.assetPath ?? "";

    currentGFPath = assetPath;
    enableVisualizer = gfData?.visualizer ?? false;

    // We don't need to update any anims if we didn't change GF
    if (currentGFPath == "")
    {
      this.visible = false;
      clearFrames();
      return;
    }
    else if (previousGFPath != currentGFPath)
    {
      this.visible = true;

      var path:String = currentGFPath;
      var texture:Null<animate.FlxAnimateFrames> = CharSelectAtlasHandler.loadAtlas(path, {swfMode: true});
      if (texture != null)
      {
        frames = texture;
      }
      else
      {
        this.visible = false;
        clearFrames();
        currentGFPath = "";
        return;
      }

    }

    anim.play("idle", true);

    updateHitbox();
  }

  @:nullSafety(Off)
  function clearFrames():Void
  {
    this.frames = null;
  }

  override public function destroy():Void
  {
    analyzer = null;
    analyzerSound = null;
    analyzerLevelsCache.resize(0);
    super.destroy();
  }

  public function onScriptEvent(event:ScriptEvent):Void
  {
  };

  public function onCreate(event:ScriptEvent):Void
  {
  };

  public function onDestroy(event:ScriptEvent):Void
  {
    analyzer = null;
    analyzerSound = null;
    analyzerLevelsCache = [];
  };

  public function onUpdate(event:UpdateScriptEvent):Void
  {
  };
}
