package funkin.mobile.ui;

import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.util.HapticUtil;

class FunkinHotReloadButton extends FunkinButton
{
  public var onConfirmEnd(default, null):FlxSignal = new FlxSignal();

  public var enabled:Bool = true;

  var restingOpacity:Float;
  var held:Bool = false;

  public function new(?x:Float = 0, ?y:Float = 0, ?confirmCallback:Void->Void, ?restingOpacity:Float = 0.6):Void
  {
    super(x, y);

    frames = Paths.getSparrowAtlas("backButton");
    animation.addByIndices('idle', 'back', [0], "", 24, false);
    animation.addByIndices('hold', 'back', [5], "", 24, false);
    animation.addByIndices('confirm', 'back', [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22], "", 24, false);
    animation.play("idle");

    scale.set(0.7, 0.7);
    updateHitbox();

    this.color = FlxColor.fromRGB(0, 255, 255);

    this.restingOpacity = restingOpacity;
    this.alpha = restingOpacity;
    this.ignoreDownHandler = true;

    onUp.add(playConfirmAnim);
    onDown.add(playHoldAnim);
    onOut.add(playOutAnim);

    onConfirmEnd.add(confirmCallback);
  }

  function playHoldAnim():Void
  {
    if (held || !enabled) return;

    held = true;

    FlxTween.cancelTweensOf(this);
    HapticUtil.vibrate(0, 0.01, 0.3);
    animation.play('hold');
    alpha = 1;
  }

  function playConfirmAnim():Void
  {
    if (!enabled) return;

    FlxTween.cancelTweensOf(this);
    HapticUtil.vibrate(0, 0.05, 0.3);
    animation.play('confirm');

    FunkinSound.playOnce(Paths.sound('confirmMenu'));

    animation.onFinish.addOnce(function(name:String)
    {
      if (name != 'confirm') return;
      held = false;
      onConfirmEnd.dispatch();
    });
  }

  function playOutAnim():Void
  {
    if (!enabled) return;

    FlxTween.cancelTweensOf(this);
    animation.play('idle');

    FlxTween.tween(this, {alpha: restingOpacity}, 0.5, {
      ease: FlxEase.expoOut,
      onComplete: function(_):Void
      {
        held = false;
      }
    });
  }

  override function destroy():Void
  {
    super.destroy();
    onConfirmEnd.removeAll();
    if (animation != null && animation.onFinish != null) animation.onFinish.removeAll();
  }
}
