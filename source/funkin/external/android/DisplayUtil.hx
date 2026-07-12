package funkin.external.android;

#if android
class DisplayUtil
{
  static var cachedMaximumRefreshRate:Null<Float>;
  static var setHighRefreshRateMethod:Null<Dynamic>;

  public static function getMaximumRefreshRate():Float
  {
    if (cachedMaximumRefreshRate != null) return cachedMaximumRefreshRate;

    final method:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/DisplayUtil', 'getMaximumRefreshRate', '()F');
    if (method == null) return 0;

    final refreshRate:Float = method();
    if (refreshRate > 0) cachedMaximumRefreshRate = refreshRate;
    return refreshRate;
  }

  public static function setHighRefreshRateEnabled(enabled:Bool):Void
  {
    if (setHighRefreshRateMethod == null)
    {
      setHighRefreshRateMethod = JNIUtil.createStaticMethod('funkin/util/DisplayUtil', 'setHighRefreshRateEnabled', '(Z)V');
    }
    if (setHighRefreshRateMethod != null) setHighRefreshRateMethod(enabled);
  }
}
#end
