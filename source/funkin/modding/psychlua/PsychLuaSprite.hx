package funkin.modding.psychlua;

import flixel.FlxSprite;

class PsychLuaSprite extends FlxSprite
{
  public var animOffsets:Map<String, Array<Float>> = [];

  public function addOffset(name:String, x:Float, y:Float):Void
  {
    animOffsets.set(name, [x, y]);
  }

  public function playAnim(name:String, forced:Bool = false, reverse:Bool = false, startFrame:Int = 0):Void
  {
    animation.play(name, forced, reverse, startFrame);
    var point = animOffsets.get(name);
    if (point != null) offset.set(point[0], point[1]);
  }
}
