package funkin.mobile.ui.mainmenu;

#if mobile
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatSubState;

@:nullSafety
class MobileModMenuWIPSubState extends MusicBeatSubState
{
  override function create():Void
  {
    super.create();

    if (leftWatermarkText != null) leftWatermarkText.visible = false;
    if (rightWatermarkText != null) rightWatermarkText.visible = false;

    var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    overlay.scrollFactor.set();
    overlay.alpha = 0;
    add(overlay);

    var message = new FlxText(80, 0, FlxG.width - 160, "The Mod Menu on mobile is W.I.P. I'm sorry.", 48);
    message.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    message.borderSize = 3;
    message.screenCenter();
    message.alpha = 0;
    add(message);

    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, close, 0.1, true);

    FlxTween.tween(overlay, {alpha: 1}, 0.35, {ease: FlxEase.quadOut});
    FlxTween.tween(message, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.1});
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (controls.BACK_P) close();
  }
}
#end
