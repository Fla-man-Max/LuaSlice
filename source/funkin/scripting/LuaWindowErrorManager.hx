package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
import funkin.util.DateUtil;
import funkin.util.WindowUtil;
import sys.FileSystem;
import sys.io.File;
#end

class LuaWindowErrorManager
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
      WindowUtil.showError(title, body);
    }
    catch (e)
    {
      trace('[LuaWindowErrorManager] Could not show Lua error window: ${e}');
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
    fullContents += 'Suggestions: ${suggestionFor(kind, hookName, message)}\n\n';
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
  static function suggestionFor(kind:String, hookName:Null<String>, message:String):String
  {
    final lowerMessage = message == null ? '' : message.toLowerCase();
    final apiName = hookName == null ? '' : hookName;
    final apiKey = apiName.toLowerCase();

    if (kind == 'api-error' && apiName == 'setProperty') return 'Check the field name and object path. Use setEventField() only for fields that exist on the current event.';
    if (kind == 'api-error' && apiName == 'callMethod') return 'Check the function name and object path. Make sure the method exists before calling it.';

    if (mentionsAny(lowerMessage, apiKey, ['configureluapausemenu', 'setluapausemenuitem', 'setluapauseoptionsbehavior', 'resume', 'restartsong', 'changedifficulty', 'practicemode', 'exittomenu', 'options', 'callback']))
    {
      return 'Pause menu APIs load from scripts/pause during PlayState. Use configureLuaPauseMenu({items={...}}) and set item target to resume, restartSong, changeDifficulty, practiceMode, exitToMenu, options, callback, or a custom .hx/.hxc state class.';
    }

    if (mentionsAny(lowerMessage, apiKey, ['createluaoptionpage', 'addluacheckbox', 'addluanumber', 'addluaenum', 'defineluaoption', 'getluaoption', 'setluaoption']))
    {
      return 'Lua option APIs are for scripts/options or shared scripts loaded before OptionsState. Create a page first, then add checkbox/number/enum items to that page id.';
    }

    if (mentionsAny(lowerMessage, apiKey, ['createluamenu', 'createluaimagemenu', 'addluamainmenuitem', 'setluamenuitems', 'showluamenu', 'hideluamenu', 'addluamainmenu', 'makeluamenusimple', 'makeluaimagemenusimple']))
    {
      return 'Menu APIs are for scripts/menu or PlayState UI scripts. For simple main menu entries use addLuaMainMenu(id, position, target).';
    }

    if (mentionsAny(lowerMessage, apiKey, ['createshader', 'destroyshader', 'setshaderfloat', 'setshaderfloatarray', 'setshaderint', 'setshaderbool', 'applyshader', 'clearshader', 'applycamerashader', 'clearcamerashader', 'makeluashader', 'setluashader', 'removeluashader', 'setluacamerashader', 'removeluacamerashader', 'setluashaderfloatsimple']))
    {
      return 'Shader APIs need a valid shader tag and shader file/source. For simple scripts use makeLuaShader(tag, path), setLuaShader(tag, target), or setLuaCameraShader(tag, camera).';
    }

    if (mentionsAny(lowerMessage, apiKey, ['reloadluascripts'])) return 'reloadLuaScripts() only works in PlayState. It requests the same Lua rescan as F5 and calls onReload() after reload.';
    if (mentionsAny(lowerMessage, apiKey, ['seteventfield', 'geteventfield', 'cancelevent'])) return 'Event APIs only make sense while an event hook is running. Check that the field exists on the current event payload before changing it.';

    if (lowerMessage.indexOf('attempt to call a nil value') >= 0) return 'The function name is missing in this script context. Check the spelling, script folder, script type (.lua/.luag), and whether this API only works in PlayState, Options, Main Menu, or pause.';
    if (kind == 'load-error') return 'Check for Lua syntax errors near the line shown in the message.';
    if (kind == 'run-error' || kind == 'hook-error') return 'Check the Lua function named above and any API calls inside it.';
    return 'None';
  }

  static function mentionsAny(message:String, apiName:String, names:Array<String>):Bool
  {
    for (name in names)
    {
      if (message.indexOf(name) >= 0 || apiName == name) return true;
    }
    return false;
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



