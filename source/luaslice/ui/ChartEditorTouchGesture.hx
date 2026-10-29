package luaslice.ui;

enum abstract ChartTouchAction(Int)
{
  var Idle;
  var Waiting;
  var Press;
  var Drag;
  var Release;
  var OpenMenu;
  var Blocked;
}

class ChartEditorTouchGesture
{
  var finger:Null<Int>;
  var phase:ChartTouchAction = Idle;
  var startX:Float = 0;
  var startY:Float = 0;
  var held:Float = 0;
  var tapRelease:Bool = false;

  public function new() {}

  public static function normalizeDuration(value:Float):Float
  {
    if (!Math.isFinite(value)) return 1.5;
    return Math.round(Math.max(1.0, Math.min(2.0, value)) * 10) / 10;
  }

  public function reset():Void
  {
    finger = null;
    phase = Idle;
    tapRelease = false;
    held = 0;
  }

  public function step(id:Null<Int>, justPressed:Bool, x:Float, y:Float, count:Int, elapsed:Float, eligible:Bool,
      duration:Float):ChartTouchAction
  {
    if (tapRelease)
    {
      reset();
      return Release;
    }

    if (phase == Blocked)
    {
      if (count == 0) reset();
      return Blocked;
    }

    if (count > 1 || (finger != null && id != null && finger != id))
    {
      var wasDragging = phase == Drag;
      phase = Blocked;
      return wasDragging ? Release : Blocked;
    }

    if (phase == Idle)
    {
      if (!justPressed || id == null || !eligible) return Idle;
      finger = id;
      startX = x;
      startY = y;
      held = 0;
      phase = Waiting;
      return Waiting;
    }

    if (count == 0 || id == null)
    {
      if (phase == Waiting)
      {
        tapRelease = true;
        return Press;
      }
      reset();
      return Release;
    }

    if (phase == Drag) return Drag;

    if (!eligible)
    {
      phase = Blocked;
      return Blocked;
    }

    var dx = x - startX;
    var dy = y - startY;
    if (dx * dx + dy * dy > 144)
    {
      phase = Drag;
      return Press;
    }

    held += Math.max(0, elapsed);
    if (held + 0.000001 >= normalizeDuration(duration))
    {
      phase = Blocked;
      return OpenMenu;
    }
    return Waiting;
  }
}
