package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
import funkin.util.DateUtil;
import funkin.util.WindowUtil;
import sys.FileSystem;
import sys.io.File;
#end

class LuaErrorManager
{
  #if FEATURE_LUA_SCRIPTS
  public static final LOG_FOLDER:String = 'logs/lua';

  static final MAX_POPUPS_PER_SESSION:Int = 3;
  static var popupCount:Int = 0;
  static var shownKeys:Map<String, Bool> = [];
  static var reportPaths:Map<String, String> = [];

  public static function report(kind:String, scriptPath:String, hookName:Null<String>, message:String, ?fromFiles:Array<String>):String
  {
    final key = makeKey(kind, scriptPath, hookName, message, fromFiles);
    if (reportPaths.exists(key)) return reportPaths.get(key);

    var reportPath = writeReport(kind, scriptPath, hookName, buildReport(kind, scriptPath, hookName, message, fromFiles));
    reportPaths.set(key, reportPath);
    LuaLogger.error(kind, scriptPath, hookName, message, reportPath);
    showPopup(kind, scriptPath, hookName, message, reportPath, fromFiles);
    return reportPath;
  }

  public static function warn(kind:String, scriptPath:String, hookName:Null<String>, message:String, ?fromFiles:Array<String>):Void
  {
    report(kind, scriptPath, hookName, message, fromFiles);
  }

  static function writeReport(kind:String, scriptPath:String, hookName:Null<String>, reportBody:String):String
  {
    FileSystem.createDirectory('logs');
    FileSystem.createDirectory(LOG_FOLDER);

    final timestamp = DateUtil.generateTimestamp();
    final safeScript = sanitizeReportName(scriptPath);
    final safeHook = hookName == null ? 'load' : sanitizeReportName(hookName);
    final reportPath = '${LOG_FOLDER}/${kind}-${safeScript}-${safeHook}-${timestamp}.txt';
    File.saveContent(reportPath, reportBody);
    return reportPath;
  }

  static function showPopup(kind:String, scriptPath:String, hookName:Null<String>, message:String, reportPath:String, ?fromFiles:Array<String>):Void
  {
    final key = makeKey(kind, scriptPath, hookName, message, fromFiles);
    if (shownKeys.exists(key)) return;
    shownKeys.set(key, true);

    final lineNumber = extractLineNumber(message);
    popupCount++;
    final tooMany = popupCount > MAX_POPUPS_PER_SESSION;
    final title = tooMany ? 'Lua Script Errors' : 'Lua Script Error';
    var body = 'LuaSlice caught a Lua error and will try to keep the game running.\n\n';
    body += 'Error kind: ${kind}\n';
    body += 'Lua script: ${scriptPath}\n';
    if (hookName != null) body += 'Lua hook/API: ${hookName}\n';
    if (lineNumber != null) body += 'Line: ${lineNumber}\n';
    body += 'From File/s: ${formatFiles(fromFiles, scriptPath)}\n';
    body += 'Report: ${reportPath}\n\n';
    body += message;
    final suggestion = LuaErrorSuggestions.find(kind, hookName, message);
    if (suggestion != 'None') body += '\n\nSuggestion: ' + suggestion;
    final performanceWarning = performanceWarningFor(kind, hookName, message, fromFiles, scriptPath);
    if (performanceWarning != null) body += '\n\nWarning: ' + performanceWarning;

    if (tooMany)
    {
      body = 'LuaSlice caught multiple Lua errors.\n\n'
        + 'Script(s): ${formatFiles(fromFiles, scriptPath)}\n'
        + 'More popups are blocked to protect FPS and memory.\n\n'
        + 'Please fix the script file(s) above. If errors keep happening every frame, close the game until the script is fixed.\n\n'
        + 'Reports are saved in: ${LOG_FOLDER}';
    }

    try
    {
      WindowUtil.showError(title, Math.random() < 0.005 ? 'Skill issue.' : body);
    }
    catch (e)
    {
      trace('[LuaErrorManager] Could not show Lua error window: ${e}');
    }
  }

  static function buildReport(kind:String, scriptPath:String, hookName:Null<String>, message:String, ?fromFiles:Array<String>):String
  {
    final lineNumber = extractLineNumber(message);
    final lineText = lineNumber == null ? 'Unknown' : Std.string(lineNumber);
    var fullContents:String = '=====================\n';
    fullContents += '\nLuaSlice Lua Error:\n\n';
    fullContents += 'Error kind: ${kind}\n';
    fullContents += 'Lua script: ${scriptPath}\n';
    if (hookName != null) fullContents += 'Lua hook/API: ${hookName}\n';
    fullContents += 'Line: ${lineText}\n';
    fullContents += 'From File/s: ${formatFiles(fromFiles, scriptPath)}\n';
    fullContents += 'Suggestions: ${LuaErrorSuggestions.find(kind, hookName, message)}\n\n';
    fullContents += '${message}\n\n';
    fullContents += '=====================\n';
    return fullContents;
  }

  static function extractLineNumber(message:String):Null<Int>
  {
    if (message == null || message == '') return null;

    var stringLine = ~/\]:(\d+):/;
    if (stringLine.match(message)) return Std.parseInt(stringLine.matched(1));

    var luaFileLine = ~/\.lua[g]?:(\d+):/;
    if (luaFileLine.match(message)) return Std.parseInt(luaFileLine.matched(1));

    return null;
  }

  static function makeKey(kind:String, scriptPath:String, hookName:Null<String>, message:String, ?fromFiles:Array<String>):String
  {
    return '${kind}:${scriptPath}:${hookName}:${message}:${formatFiles(fromFiles, scriptPath)}';
  }

  static function formatFiles(files:Null<Array<String>>, fallback:String):String
  {
    if (files == null || files.length == 0) return fallback;
    return files.join(', ');
  }


  static function performanceWarningFor(kind:String, hookName:Null<String>, message:String, files:Null<Array<String>>, fallback:String):Null<String>
  {
    if ((kind == 'hook-error' || kind == 'hook-haxe-error') && isPerFrameHook(hookName)) return 'Please fix ${formatFiles(files, fallback)}. This hook can run every frame, so repeated errors can drop FPS and grow memory.';
    return null;
  }

  static function isPerFrameHook(hookName:Null<String>):Bool
  {
    return hookName == 'onUpdate' || hookName == 'onStepHit' || hookName == 'onBeatHit' || hookName == 'onSectionHit' || hookName == 'onNoteIncoming';
  }
  static function sanitizeReportName(value:String):String
  {
    var result = value;
    for (char in ['\\', '/', ':', '*', '?', '"', '<', '>', '|', ' '])
    {
      result = StringTools.replace(result, char, '_');
    }
    return result == '' ? 'unknown' : result;
  }
  #end
}

