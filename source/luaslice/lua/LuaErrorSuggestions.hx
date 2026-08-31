package luaslice.lua;

class LuaErrorSuggestions
{
  public static function find(kind:String, hookName:Null<String>, message:String):String
  {
    final lowerMessage = message == null ? '' : message.toLowerCase();
    final apiName = hookName == null ? '' : hookName;
    final apiKey = apiName.toLowerCase();

    if (kind == 'api-error' && apiName == 'setProperty') return 'Check the field name and object path. Use setEventField() only for fields that exist on the current event.';
    if (kind == 'api-error' && apiName == 'callMethod') return 'Check the function name and object path. Make sure the method exists before calling it.';

    if (mentionsAny(lowerMessage, apiKey, ['configureluapausemenu', 'setluapausemenuitem', 'setluapauseoptions', 'setluapauseoptionsbehavior', 'resume', 'restartsong', 'changedifficulty', 'practicemode', 'exittomenu', 'options', 'callback']))
      return 'Pause menu APIs load from scripts/pause during PlayState. Use configureLuaPauseMenu({items={...}}), set item target to resume/restartSong/changeDifficulty/practiceMode/exitToMenu/options/callback, and use setLuaPauseOptions(howExit) for pause-opened Options.';

    if (mentionsAny(lowerMessage, apiKey, ['createluaoptionpage', 'addluacheckbox', 'addluanumber', 'addluaenum', 'defineluaoption', 'getluaoption', 'setluaoption']))
      return 'Lua option APIs are for scripts/options or shared scripts loaded before OptionsState. Create a page first, then add checkbox/number/enum items to that page id.';

    if (mentionsAny(lowerMessage, apiKey, ['createluamenu', 'createluaimagemenu', 'addluamainmenuitem', 'setluamenuitems', 'showluamenu', 'hideluamenu', 'addluamainmenu', 'makeluamenusimple', 'makeluaimagemenusimple']))
      return 'Menu APIs are for scripts/menu or PlayState UI scripts. For simple main menu entries use addLuaMainMenu(id, position, target).';

    if (mentionsAny(lowerMessage, apiKey, ['createshader', 'destroyshader', 'setshaderfloat', 'setshaderfloatarray', 'setshaderint', 'setshaderbool', 'setshadercolor', 'applyshader', 'clearshader', 'applycamerashader', 'clearcamerashader', 'initluashader', 'initluashaderraw', 'makeluashader', 'setluashader', 'setshaderonsprite', 'removeluashader', 'setluacamerashader', 'removeluacamerashader', 'setluashaderfloatsimple']))
      return 'Shader APIs need a valid shader tag and target. Named stage objects can use object:name. DropShadowShader supports color, angle, distance, strength, threshold, antialiasAmt, and adjust-color properties.';

    if (mentionsAny(lowerMessage, apiKey, ['getluasave', 'setluasave']))
      return 'Lua save APIs use persistent FlxSave data. Use setLuaSave(key, value), then getLuaSave(key, fallback). Keep saved values simple: strings, numbers, booleans, or plain tables.';

    if (mentionsAny(lowerMessage, apiKey, ['setproperties', 'getpropertyref', 'setpropertyref', 'property.ref', 'property.setmany']))
      return 'Property helper APIs need a valid object path. Use setProperties("objectPath", {field = value}) or property.ref("object.field") for repeated reads/writes.';

    if (mentionsAny(lowerMessage, apiKey, ['disableluahook', 'enableluahook', 'script.disablehook', 'script.enablehook']))
      return 'Hook control APIs take a hook name like "onUpdate". Disable expensive hooks only after the script no longer needs them.';

    if (mentionsAny(lowerMessage, apiKey, ['onfreeplaycreate', 'onfreeplayupdate', 'onfreeplayclose', 'onstorycreate', 'onstoryupdate', 'onstoryclose', 'onresultscreate', 'onresultsupdate', 'onresultsclose']))
      return 'Freeplay, Story, and Results hooks load from scripts/freeplay, scripts/story, or scripts/results. Use the matching hook name for that screen.';

    if (mentionsAny(lowerMessage, apiKey, ['reloadluascripts'])) return 'reloadLuaScripts() only works in PlayState. It requests the same Lua rescan as F5 and calls onReload() after reload.';
    if (mentionsAny(lowerMessage, apiKey, ['changestage'])) return 'Use changeStage(stageId) in PlayState with a valid base-game or modded stage ID.';
    if (mentionsAny(lowerMessage, apiKey, ['changecharacter'])) return 'Use changeCharacter("player", characterId), changeCharacter("opponent", characterId), or changeCharacter("girlfriend", characterId) with a valid character ID.';
    if (mentionsAny(lowerMessage, apiKey, ['seteventfield', 'geteventfield', 'cancelevent'])) return 'Event APIs only make sense while an event hook is running. Check that the field exists on the current event payload before changing it.';

    if (lowerMessage.indexOf('attempt to call a nil value') >= 0) return 'The function name is missing in this script context. Check the spelling, script folder, script type (.lua/.luag), and whether this API only works in PlayState, Options, Main Menu, or pause.';
    if (kind == 'load-error') return 'Check for Lua syntax errors near the line shown in the message.';
    if (kind == 'run-error' || kind == 'hook-error') return 'Check the Lua function named above and any API calls inside it.';
    return 'None';
  }

  static function mentionsAny(message:String, apiName:String, names:Array<String>):Bool
  {
    for (name in names)
      if (message.indexOf(name) >= 0 || apiName == name) return true;
    return false;
  }
}
