package luaslice.script;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class ScriptTweenService
{
  public static function create(target:Dynamic, values:Dynamic, duration:Float, ease:String, ?complete:FlxTween->Void):FlxTween
  {
    if (target == null || values == null || !Math.isFinite(duration) || duration < 0) throw 'Invalid tween target, values or duration';
    return FlxTween.tween(target, values, duration, {ease: resolveEase(ease), onComplete: complete});
  }

  public static function resolveEase(name:String):EaseFunction
  {
    return switch (name)
    {
      case 'quadIn': FlxEase.quadIn;
      case 'quadOut': FlxEase.quadOut;
      case 'quadInOut': FlxEase.quadInOut;
      case 'cubeIn': FlxEase.cubeIn;
      case 'cubeOut': FlxEase.cubeOut;
      case 'cubeInOut': FlxEase.cubeInOut;
      case 'sineIn': FlxEase.sineIn;
      case 'sineOut': FlxEase.sineOut;
      case 'sineInOut': FlxEase.sineInOut;
      case 'elasticIn': FlxEase.elasticIn;
      case 'elasticOut': FlxEase.elasticOut;
      case 'elasticInOut': FlxEase.elasticInOut;
      case 'bounceIn': FlxEase.bounceIn;
      case 'bounceOut': FlxEase.bounceOut;
      case 'bounceInOut': FlxEase.bounceInOut;
      case 'backIn': FlxEase.backIn;
      case 'backOut': FlxEase.backOut;
      case 'backInOut': FlxEase.backInOut;
      default: FlxEase.linear;
    };
  }
}
