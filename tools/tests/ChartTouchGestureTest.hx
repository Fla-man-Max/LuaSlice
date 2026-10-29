import luaslice.ui.ChartEditorTouchGesture;
import luaslice.ui.ChartEditorTouchGesture.ChartTouchAction;

class ChartTouchGestureTest
{
  static function expect(actual:Dynamic, expected:Dynamic, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    var g = new ChartEditorTouchGesture();
    expect(g.step(7, true, 100, 200, 1, 0, true, 1.5), Waiting, 'press cannot edit yet');
    expect(g.step(7, false, 100, 200, 1, 1.4, true, 1.5), Waiting, 'hold threshold');
    expect(g.step(7, false, 100, 200, 1, 0.1, true, 1.5), OpenMenu, 'hold opens menu');
    expect(g.step(7, false, 100, 200, 1, 2, true, 1.5), Blocked, 'only one menu');
    expect(g.step(null, false, 100, 200, 0, 0, true, 1.5), Blocked, 'release cannot click through menu');
    expect(g.step(null, false, 100, 200, 0, 0, true, 1.5), Idle, 'next gesture available');

    g.step(99, true, 20, 30, 1, 0, true, 1.5);
    expect(g.step(null, false, 20, 30, 0, 0.1, true, 1.5), Press, 'short tap replays press');
    expect(g.step(null, false, 20, 30, 0, 0, true, 1.5), Release, 'short tap replays release');
    expect(g.step(null, false, 20, 30, 0, 0, true, 1.5), Idle, 'tap complete');

    g.step(5, true, 20, 30, 1, 0, true, 1.5);
    expect(g.step(5, false, 40, 30, 1, 0.1, true, 1.5), Press, 'movement starts ordinary drag');
    expect(g.step(5, false, 80, 30, 1, 3, true, 1.5), Drag, 'moving cannot long press');
    expect(g.step(null, false, 80, 30, 0, 0, true, 1.5), Release, 'drag ends');

    g.step(5, true, 20, 30, 1, 0, true, 1.5);
    expect(g.step(5, false, 20, 30, 2, 3, true, 1.5), Blocked, 'pinch cancels hold');
    expect(g.step(5, false, 20, 30, 1, 3, true, 1.5), Blocked, 'pinch stays canceled');
    g.step(null, false, 20, 30, 0, 0, true, 1.5);
    expect(g.step(5, true, 20, 30, 1, 0, false, 1.5), Idle, 'UI touches are untouched');
    expect(g.step(5, false, 20, 30, 1, 3, true, 1.5), Idle, 'moving from UI cannot acquire hold');
    g.step(null, false, 20, 30, 0, 0, true, 1.5);
    g.step(5, true, 20, 30, 1, 0, true, 1.5);
    expect(g.step(5, false, 20, 30, 1, 2, false, 1.5), Blocked, 'scrolling cancels pending hold');
    g.reset();
    g.step(5, true, 20, 30, 1, 0, true, 1.5);
    g.reset();
    expect(g.step(null, false, 20, 30, 0, 0, false, 1.5), Idle, 'focus loss cannot synthesize a tap');
    expect(ChartEditorTouchGesture.normalizeDuration(Math.NaN), 1.5, 'invalid saved duration');
    expect(ChartEditorTouchGesture.normalizeDuration(0), 1.0, 'minimum duration');
    expect(ChartEditorTouchGesture.normalizeDuration(5), 2.0, 'maximum duration');
    expect(ChartEditorTouchGesture.normalizeDuration(1.26), 1.3, 'duration increments');
    trace('CHART_TOUCH_GESTURE_OK');
  }
}
