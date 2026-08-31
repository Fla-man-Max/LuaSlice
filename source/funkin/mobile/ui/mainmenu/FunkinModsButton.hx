package funkin.mobile.ui.mainmenu;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.mobile.ui.FunkinButton;
import funkin.util.HapticUtil;

class FunkinModsButton extends FunkinButton
{
  static final BASE_SCALE:Float = 0.27;

  public var onConfirmStart(default, null):FlxSignal = new FlxSignal();
  public var onConfirmEnd(default, null):FlxSignal = new FlxSignal();
  public var enabled:Bool = true;
  public var confirming(get, never):Bool;

  var _confirming:Bool = false;
  var held:Bool = false;

  function get_confirming():Bool
  {
    return _confirming;
  }

  public function new(?x:Float = 0, ?y:Float = 0, ?confirmCallback:Void->Void):Void
  {
    super(x, y);

    frames = Paths.getSparrowAtlas('mainmenu/modsButton');
    animation.addByIndices('idle', 'mods', [0], '', 24, false);
    animation.addByIndices('hold', 'mods', [1], '', 24, false);
    animation.addByIndices('confirm', 'mods', [2], '', 24, false);
    animation.play('idle');

    scale.set(BASE_SCALE, BASE_SCALE);
    updateHitbox();
    alpha = 0.8;
    ignoreDownHandler = true;

    onDown.add(playPressed);
    onUp.add(confirm);
    onOut.add(resetVisuals);
    onConfirmEnd.add(confirmCallback);
  }

  function playPressed():Void
  {
    if (held || confirming || !enabled) return;

    held = true;
    FlxTween.cancelTweensOf(this);
    FlxTween.cancelTweensOf(scale);
    animation.play('hold');
    alpha = 1.0;
    scale.set(BASE_SCALE * 1.1, BASE_SCALE * 1.1);
    FlxTween.tween(scale, {x: BASE_SCALE, y: BASE_SCALE}, 0.3, {ease: FlxEase.backOut});
    HapticUtil.vibrate(0, 0.01, 0.2);
  }

  function confirm():Void
  {
    if (!held || confirming || !enabled) return;

    _confirming = true;
    HapticUtil.vibrate(0, 0.05, 0.5);
    FunkinSound.playOnce(Paths.sound('confirmMenu'));
    onConfirmStart.dispatch();
    held = false;
    FlxTween.cancelTweensOf(scale);
    animation.play('confirm', true);
    scale.set(BASE_SCALE * 1.12, BASE_SCALE * 1.12);
    FlxTween.tween(scale, {x: BASE_SCALE, y: BASE_SCALE}, 0.35, {
      ease: FlxEase.backOut,
      onComplete: _ ->
      {
        animation.play('idle');
        alpha = 0.8;
        _confirming = false;
        onConfirmEnd.dispatch();
      }
    });
  }

  function resetVisuals():Void
  {
    if (confirming) return;

    FlxTween.cancelTweensOf(this);
    FlxTween.cancelTweensOf(scale);
    scale.set(BASE_SCALE, BASE_SCALE);
    animation.play('idle');
    alpha = 0.8;
    held = false;
  }

  public function resetCallbacks():Void
  {
    onUp.removeAll();
    onDown.removeAll();
    onOut.removeAll();

    _confirming = false;
    held = false;
    FlxTween.cancelTweensOf(scale);
    scale.set(BASE_SCALE, BASE_SCALE);
    animation.play('idle');
    alpha = 0.8;

    onDown.add(playPressed);
    onUp.add(confirm);
    onOut.add(resetVisuals);
  }

  override function destroy():Void
  {
    super.destroy();
    onConfirmStart.removeAll();
    onConfirmEnd.removeAll();
  }
}
