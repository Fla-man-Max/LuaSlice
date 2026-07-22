package funkin.external.android;

#if android
class MobileFileUtil
{
  static final pendingDialogs:Map<Int, MobileFileDialogCallbacks> = new Map<Int, MobileFileDialogCallbacks>();

  public static function openFileDialog(title:Null<String>, onSelect:String->Void, ?onCancel:()->Void):Bool
  {
    final method = JNIUtil.createStaticMethod('funkin/util/MobileFileUtil', 'openFileDialog', '(Ljava/lang/String;)I');
    if (method == null)
    {
      if (onCancel != null) onCancel();
      return false;
    }

    ensureCallback();
    final requestCode:Int = method(title);
    if (requestCode < 0)
    {
      if (onCancel != null) onCancel();
      return false;
    }

    pendingDialogs.set(requestCode, {onSelect: onSelect, onCancel: onCancel});
    return true;
  }

  public static function saveFileDialog(title:Null<String>, defaultFileName:Null<String>, onSelect:String->Void, ?onCancel:()->Void):Bool
  {
    final method = JNIUtil.createStaticMethod('funkin/util/MobileFileUtil', 'saveFileDialog',
      '(Ljava/lang/String;Ljava/lang/String;)I');
    if (method == null)
    {
      if (onCancel != null) onCancel();
      return false;
    }

    ensureCallback();
    final requestCode:Int = method(title, defaultFileName);
    if (requestCode < 0)
    {
      if (onCancel != null) onCancel();
      return false;
    }

    pendingDialogs.set(requestCode, {onSelect: onSelect, onCancel: onCancel});
    return true;
  }

  static function ensureCallback():Void
  {
    if (!CallbackUtil.onFileDialogResult.has(onFileDialogResult)) CallbackUtil.onFileDialogResult.add(onFileDialogResult);
  }

  static function onFileDialogResult(requestCode:Int, resultCode:Int, uri:String):Void
  {
    final callbacks = pendingDialogs.get(requestCode);
    if (callbacks == null) return;

    pendingDialogs.remove(requestCode);
    if (resultCode == -1 && uri != null && uri != '')
    {
      callbacks.onSelect(uri);
    }
    else if (callbacks.onCancel != null)
    {
      callbacks.onCancel();
    }
  }

  public static function copyUriToCache(uri:String):Null<String>
  {
    final method = JNIUtil.createStaticMethod('funkin/util/MobileFileUtil', 'copyUriToCache',
      '(Ljava/lang/String;)Ljava/lang/String;');
    return method == null ? null : method(uri);
  }

  public static function copyFileToUri(path:String, uri:String):Bool
  {
    final method = JNIUtil.createStaticMethod('funkin/util/MobileFileUtil', 'copyFileToUri',
      '(Ljava/lang/String;Ljava/lang/String;)Z');
    return method != null && method(path, uri);
  }

  public static function getDisplayName(uri:String):String
  {
    final method = JNIUtil.createStaticMethod('funkin/util/MobileFileUtil', 'getDisplayName',
      '(Ljava/lang/String;)Ljava/lang/String;');
    final result:Null<String> = method == null ? null : method(uri);
    return result == null || result == '' ? 'selected-file' : result;
  }
}

private typedef MobileFileDialogCallbacks =
{
  var onSelect:String->Void;
  var ?onCancel:()->Void;
}
#end
