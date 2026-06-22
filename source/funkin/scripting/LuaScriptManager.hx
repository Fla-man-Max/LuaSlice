package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.Conductor;
import funkin.Highscore;
import funkin.Paths;
import funkin.Preferences;
import funkin.save.Save;
import funkin.graphics.FunkinSprite;
import funkin.modding.events.ScriptEvent;
import funkin.play.cutscene.VideoCutscene;
import funkin.play.PauseSubState;
import funkin.play.PlayState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.options.OptionsState;
import haxe.Json;
import hxlua.Lua;
import hxlua.LuaL;
import hxlua.Types.Lua_State;
import sys.FileSystem;
import sys.io.File;
#end

class LuaScriptManager
{
  #if FEATURE_LUA_SCRIPTS
  static var activeManager:Null<LuaScriptManager>;
  static final LUA_SCRIPT_FOLDERS:Array<String> = [
    'modules',
    'module',
    'ui',
    'UI',
    'gameplay',
    'opponent',
    'player',
    'songs',
    'stages',
    'characters',
    'events',
    'notekinds',
    'players',
    'shaders',
    'dialogue',
    'levels',
    'pause',
    'options',
    'menu',
    'lua',
    'luag'
  ];
  static final LUA_HOOK_NAMES:Array<String> = [
    'onCreate',
    'onReload',
    'onUpdate',
    'onStepHit',
    'onBeatHit',
    'onSectionHit',
    'onDestroy',
    'onEvent',
    'onCreateEvent',
    'onStateCreate',
    'onDestroyEvent',
    'onAdded',
    'onUpdateEvent',
    'onCountdownStart',
    'onCountdownStep',
    'onCountdownEnd',
    'onSongStart',
    'onSongEnd',
    'onPause',
    'onResume',
    'onGameOver',
    'onNoteIncoming',
    'onNoteHit',
    'onNoteMiss',
    'onNoteHoldDrop',
    'onGhostMiss',
    'onNoteGhostMiss',
    'onSongEvent',
    'onSongLoaded',
    'onSongRetry',
    'onKeyDown',
    'onKeyUp',
    'onStateChangeBegin',
    'onStateChangeEnd',
    'onSubStateOpenBegin',
    'onSubStateOpenEnd',
    'onSubStateCloseBegin',
    'onSubStateCloseEnd',
    'onFocusGained',
    'onFocusLost',
    'onDialogueStart',
    'onDialogueLine',
    'onDialogueCompleteLine',
    'onDialogueSkip',
    'onDialogueEnd',
    'onTweenCompleted',
    'onTimerCompleted',
    'onLuaMenuChange',
    'onLuaMenuAccept',
    'onLuaMenuCancel',
    'onLuaMainMenuAccept',
    'onPauseMenuCreate',
    'onLuaPauseMenuAccept',
    'onLuaOptionChanged'
  ];

  var state:cpp.RawPointer<Lua_State>;
  var loadedScripts:Array<String> = [];
  var scriptGlobalModes:Map<String, Bool> = [];
  var scriptEnvRefs:Map<String, Int> = [];
  var globalScriptHookRefs:Map<String, Map<String, Int>> = [];
  var sprites:Map<String, FunkinSprite> = [];
  var texts:Map<String, FlxText> = [];
  var objects:Map<String, Dynamic> = [];
  var sounds:Map<String, FlxSound> = [];
  var tweens:Map<String, FlxTween> = [];
  var timers:Map<String, FlxTimer> = [];
  var optionManager:LuaOptionManager;
  var menusManager:LuaMenusManager;
  var shaderManager:LuaShaderManager;
  var disabledHooks:Map<String, Bool> = [];
  var currentEvent:Null<ScriptEvent> = null;
  var currentLuaFiles:Array<String> = [];
  var mainMenuState:Null<MainMenuState> = null;
  var pauseMenuState:Null<PauseSubState> = null;
  var pauseMenuConfig:Dynamic = null;
  var pauseMenuConfiguredThisPass:Bool = false;

  public function new()
  {
    state = LuaL.newstate();
    LuaL.openlibs(state);
    activeManager = this;
    optionManager = new LuaOptionManager(this);
    menusManager = new LuaMenusManager(this);
    shaderManager = new LuaShaderManager();
    configurePackagePath();
    registerAPI();
  }

  public function loadScript(path:String):Bool
  {
    if (!FileSystem.exists(path))
    {
      reportLuaWarning('missing-script', path, null, 'Script does not exist: ${path}');
      return false;
    }

    updateGlobals();

    final isGlobalScript = isGlobalScript(path);
    final previousGlobalHooks = isGlobalScript ? snapshotGlobalHooks() : null;
    final envRef = isGlobalScript ? LuaL.NOREF : createScriptEnvironment();

    try
    {
      if (LuaL.loadfile(state, path) != Lua.OK)
      {
        final error = readError();
        trace('[LuaScriptManager] Failed to load ${path}: ${error}');
        LuaWindowErrorManager.report('load-error', path, null, error);
        if (previousGlobalHooks != null) releaseHookRefs(previousGlobalHooks);
        if (envRef != LuaL.NOREF) LuaL.unref(state, Lua.REGISTRYINDEX, envRef);
        return false;
      }

      if (!isGlobalScript)
      {
        Lua.rawgeti(state, Lua.REGISTRYINDEX, envRef);
        Lua.setupvalue(state, -2, 1);
      }

      if (Lua.pcall(state, 0, 0, 0) != Lua.OK)
      {
        final error = readError();
        trace('[LuaScriptManager] Failed to run ${path}: ${error}');
        LuaWindowErrorManager.report('run-error', path, null, error);
        if (previousGlobalHooks != null) releaseHookRefs(previousGlobalHooks);
        if (envRef != LuaL.NOREF) LuaL.unref(state, Lua.REGISTRYINDEX, envRef);
        return false;
      }
    }
    catch (e)
    {
      final error = Std.string(e);
      trace('[LuaScriptManager] Failed to load/run ${path}: ${error}');
      LuaWindowErrorManager.report('haxe-load-error', path, null, error);
      if (previousGlobalHooks != null) releaseHookRefs(previousGlobalHooks);
      if (envRef != LuaL.NOREF) LuaL.unref(state, Lua.REGISTRYINDEX, envRef);
      return false;
    }

    if (isGlobalScript && previousGlobalHooks != null)
    {
      releaseGlobalScriptHooks(path);
      captureChangedGlobalHooks(path, previousGlobalHooks);
      releaseHookRefs(previousGlobalHooks);
    }

    if (!loadedScripts.contains(path)) loadedScripts.push(path);
    scriptGlobalModes.set(path, isGlobalScript);
    if (envRef != LuaL.NOREF) scriptEnvRefs.set(path, envRef);
    trace('[LuaScriptManager] Loaded ${path} (${isGlobalScript ? 'global' : 'isolated'})');
    return true;
  }

  public function reloadScripts():Bool
  {
    if (state == null || loadedScripts.length == 0) return false;

    var scriptsToReload = loadedScripts.copy();
    callHook('onDestroy', []);
    clearRuntimeObjects();
    disabledHooks.clear();

    Lua.close(state);
    state = LuaL.newstate();
    LuaL.openlibs(state);
    activeManager = this;
    configurePackagePath();
    registerAPI();

    loadedScripts = [];
    scriptGlobalModes.clear();
    scriptEnvRefs.clear();
    globalScriptHookRefs.clear();
    var loadedAny = false;
    var seen:Map<String, Bool> = [];
    for (scriptPath in scriptsToReload)
    {
      if (seen.exists(scriptPath)) continue;
      seen.set(scriptPath, true);
      if (loadScript(scriptPath)) loadedAny = true;
    }

    if (loadedAny)
    {
      callHook('onCreate', []);
      callHook('onReload', []);
      trace('[LuaScriptManager] Hot-reloaded ${loadedScripts.length} Lua script(s).');
    }

    return loadedAny;
  }

  public function getLoadedScriptCount():Int
  {
    return loadedScripts.length;
  }

  public function callHook(name:String, args:Array<Dynamic>):Void
  {
    activeManager = this;
    updateGlobals();
    if (name == 'onUpdate') menusManager.update(args.length > 0 ? Std.parseFloat(Std.string(args[0])) : 0);
    try
    {
      callGlobalHook(name, args);
    }
    catch (e)
    {
      final hookKey = 'global:${name}';
      final error = Std.string(e);
      trace('[LuaScriptManager] Haxe error in global ${name}, disabling this Lua hook: ${error}');
      disabledHooks.set(hookKey, true);
      LuaWindowErrorManager.report('hook-haxe-error', 'global', name, error);
    }

    for (scriptPath in loadedScripts)
    {
      if (scriptGlobalModes.get(scriptPath) == true) continue;
      try
      {
        callScriptHook(scriptPath, name, args);
      }
      catch (e)
      {
        final hookKey = '${scriptPath}:${name}';
        final error = Std.string(e);
        trace('[LuaScriptManager] Haxe error in ${scriptPath} ${name}, disabling this Lua hook: ${error}');
        disabledHooks.set(hookKey, true);
        LuaWindowErrorManager.report('hook-haxe-error', scriptPath, name, error);
      }
    }
  }

  function callGlobalHook(name:String, args:Array<Dynamic>):Void
  {
    var capturedHookCount = 0;
    for (scriptPath in loadedScripts)
    {
      if (scriptGlobalModes.get(scriptPath) != true) continue;
      final scriptHooks = globalScriptHookRefs.get(scriptPath);
      if (scriptHooks == null || !scriptHooks.exists(name)) continue;
      capturedHookCount++;
      callGlobalScriptHook(scriptPath, name, args);
    }

    if (capturedHookCount > 0) return;

    final hookKey = 'global:${name}';
    if (disabledHooks.exists(hookKey)) return;

    Lua.getglobal(state, name);

    if (Lua.type(state, -1) != Lua.TFUNCTION)
    {
      Lua.settop(state, -2);
      return;
    }

    for (arg in args)
    {
      pushValue(arg);
    }

    var previousLuaFiles = currentLuaFiles;
    currentLuaFiles = ['global'];
    var callResult = Lua.pcall(state, args.length, 0, 0);
    currentLuaFiles = previousLuaFiles;

    if (callResult != Lua.OK)
    {
      final error = readError();
      trace('[LuaScriptManager] Error in global ${name}, disabling this Lua hook: ${error}');
      disabledHooks.set(hookKey, true);
      LuaWindowErrorManager.report('hook-error', 'global', name, error, ['global']);
    }
  }

  function callGlobalScriptHook(scriptPath:String, name:String, args:Array<Dynamic>):Void
  {
    final hookKey = '${scriptPath}:${name}';
    if (disabledHooks.exists(hookKey)) return;

    final scriptHooks = globalScriptHookRefs.get(scriptPath);
    if (scriptHooks == null) return;

    final hookRef = scriptHooks.get(name);
    if (hookRef == null) return;

    Lua.rawgeti(state, Lua.REGISTRYINDEX, hookRef);

    if (Lua.type(state, -1) != Lua.TFUNCTION)
    {
      Lua.pop(state, 1);
      return;
    }

    for (arg in args)
    {
      pushValue(arg);
    }

    var previousLuaFiles = currentLuaFiles;
    currentLuaFiles = [scriptPath];
    var callResult = Lua.pcall(state, args.length, 0, 0);
    currentLuaFiles = previousLuaFiles;

    if (callResult != Lua.OK)
    {
      final error = readError();
      trace('[LuaScriptManager] Error in ${scriptPath} ${name}, disabling this Lua hook: ${error}');
      disabledHooks.set(hookKey, true);
      LuaWindowErrorManager.report('hook-error', scriptPath, name, error, [scriptPath]);
    }
  }

  function callScriptHook(scriptPath:String, name:String, args:Array<Dynamic>):Void
  {
    final hookKey = '${scriptPath}:${name}';
    if (disabledHooks.exists(hookKey)) return;

    final envRef = scriptEnvRefs.get(scriptPath);
    if (envRef == null) return;

    Lua.rawgeti(state, Lua.REGISTRYINDEX, envRef);
    Lua.getfield(state, -1, name);

    if (Lua.type(state, -1) != Lua.TFUNCTION)
    {
      Lua.pop(state, 2);
      return;
    }

    Lua.remove(state, -2);

    for (arg in args)
    {
      pushValue(arg);
    }

    var previousLuaFiles = currentLuaFiles;
    currentLuaFiles = [scriptPath];
    var callResult = Lua.pcall(state, args.length, 0, 0);
    currentLuaFiles = previousLuaFiles;

    if (callResult != Lua.OK)
    {
      final error = readError();
      trace('[LuaScriptManager] Error in ${scriptPath} ${name}, disabling this Lua hook: ${error}');
      disabledHooks.set(hookKey, true);
      LuaWindowErrorManager.report('hook-error', scriptPath, name, error, [scriptPath]);
    }
  }

  public function callEvent(event:ScriptEvent):Void
  {
    var previousEvent = currentEvent;
    currentEvent = event;

    var type = Std.string(event.type);
    var payload = eventToPayload(event);
    callHook('onEvent', [type, payload]);

    switch (type)
    {
      case 'CREATE':
        callHook('onCreateEvent', [payload]);
      case 'STATE_CREATE':
        callHook('onStateCreate', [payload]);
      case 'DESTROY':
        callHook('onDestroyEvent', [payload]);
      case 'ADDED':
        callHook('onAdded', [payload]);
      case 'UPDATE':
        callHook('onUpdateEvent', [payload]);
      case 'COUNTDOWN_START':
        callHook('onCountdownStart', []);
      case 'COUNTDOWN_STEP':
        callHook('onCountdownStep', [safeField(payload, 'step'), payload]);
      case 'COUNTDOWN_END':
        callHook('onCountdownEnd', []);
      case 'SONG_START':
        callHook('onSongStart', []);
      case 'SONG_END':
        callHook('onSongEnd', []);
      case 'PAUSE':
        callHook('onPause', [payload]);
      case 'RESUME':
        callHook('onResume', [payload]);
      case 'GAME_OVER':
        callHook('onGameOver', []);
      case 'SONG_BEAT_HIT':
        callHook('onBeatHit', [safeField(payload, 'beat'), payload]);
      case 'SONG_STEP_HIT':
        callHook('onStepHit', [safeField(payload, 'step'), payload]);
      case 'NOTE_INCOMING':
        callHook('onNoteIncoming', [payload]);
      case 'NOTE_HIT':
        callHook('onNoteHit', [payload]);
      case 'NOTE_MISS':
        callHook('onNoteMiss', [payload]);
      case 'NOTE_HOLD_DROP':
        callHook('onNoteHoldDrop', [payload]);
      case 'NOTE_GHOST_MISS':
        callHook('onGhostMiss', [payload]);
        callHook('onNoteGhostMiss', [payload]);
      case 'SONG_EVENT':
        callHook('onSongEvent', [payload]);
      case 'SONG_LOADED':
        callHook('onSongLoaded', [payload]);
      case 'SONG_RETRY':
        callHook('onSongRetry', [payload]);
      case 'KEY_DOWN':
        callHook('onKeyDown', [payload]);
      case 'KEY_UP':
        callHook('onKeyUp', [payload]);
      case 'STATE_CHANGE_BEGIN':
        callHook('onStateChangeBegin', [payload]);
      case 'STATE_CHANGE_END':
        callHook('onStateChangeEnd', [payload]);
      case 'SUBSTATE_OPEN_BEGIN':
        callHook('onSubStateOpenBegin', [payload]);
      case 'SUBSTATE_OPEN_END':
        callHook('onSubStateOpenEnd', [payload]);
      case 'SUBSTATE_CLOSE_BEGIN':
        callHook('onSubStateCloseBegin', [payload]);
      case 'SUBSTATE_CLOSE_END':
        callHook('onSubStateCloseEnd', [payload]);
      case 'FOCUS_GAINED':
        callHook('onFocusGained', []);
      case 'FOCUS_LOST':
        callHook('onFocusLost', []);
      case 'DIALOGUE_START':
        callHook('onDialogueStart', [payload]);
      case 'DIALOGUE_LINE':
        callHook('onDialogueLine', [payload]);
      case 'DIALOGUE_COMPLETE_LINE':
        callHook('onDialogueCompleteLine', [payload]);
      case 'DIALOGUE_SKIP':
        callHook('onDialogueSkip', [payload]);
      case 'DIALOGUE_END':
        callHook('onDialogueEnd', [payload]);
      default:
    }

    currentEvent = previousEvent;
  }

  public function destroy():Void
  {
    if (state == null) return;

    clearRuntimeObjects();
    Lua.close(state);
    state = null;
    loadedScripts = [];
    scriptGlobalModes.clear();
    scriptEnvRefs.clear();
    globalScriptHookRefs.clear();
    if (activeManager == this) activeManager = null;
  }

  public static function loadOptionsScriptsForState(optionsState:OptionsState):Null<LuaScriptManager>
  {
    var scriptPaths:Array<String> = [];
    collectOptionLuaScripts('mods/scripts/options', scriptPaths, '.luag');
    collectOptionLuaScripts('mods/scripts/options', scriptPaths, '.lua');

    if (FileSystem.exists('mods') && FileSystem.isDirectory('mods'))
    {
      for (modName in FileSystem.readDirectory('mods'))
      {
        var modPath = 'mods/${modName}';
        if (!FileSystem.isDirectory(modPath) || modName == 'scripts') continue;
        collectOptionLuaScripts('${modPath}/scripts/options', scriptPaths, '.luag');
        collectOptionLuaScripts('${modPath}/scripts/options', scriptPaths, '.lua');
      }
    }

    var manager:Null<LuaScriptManager> = null;
    var loaded:Map<String, Bool> = [];
    for (scriptPath in scriptPaths)
    {
      if (!FileSystem.exists(scriptPath) || loaded.exists(scriptPath)) continue;
      if (manager == null) manager = new LuaScriptManager();
      manager.loadScript(scriptPath);
      loaded.set(scriptPath, true);
    }

    if (manager != null)
    {
      manager.callHook('onCreate', []);
      manager.optionManager.attachToOptionsState(optionsState);
    }

    return manager;
  }

  public static function loadMainMenuScriptsForState(mainMenuState:MainMenuState):Null<LuaScriptManager>
  {
    var scriptPaths:Array<String> = [];
    collectScriptFolder('mods/scripts/menu', scriptPaths, '.luag');
    collectScriptFolder('mods/scripts/menu', scriptPaths, '.lua');

    if (FileSystem.exists('mods') && FileSystem.isDirectory('mods'))
    {
      for (modName in FileSystem.readDirectory('mods'))
      {
        var modPath = 'mods/${modName}';
        if (!FileSystem.isDirectory(modPath) || modName == 'scripts') continue;
        collectScriptFolder('${modPath}/scripts/menu', scriptPaths, '.luag');
        collectScriptFolder('${modPath}/scripts/menu', scriptPaths, '.lua');
      }
    }

    var manager:Null<LuaScriptManager> = null;
    var loaded:Map<String, Bool> = [];
    for (scriptPath in scriptPaths)
    {
      if (!FileSystem.exists(scriptPath) || loaded.exists(scriptPath)) continue;
      if (manager == null)
      {
        manager = new LuaScriptManager();
        manager.mainMenuState = mainMenuState;
      }
      manager.loadScript(scriptPath);
      loaded.set(scriptPath, true);
    }

    if (manager != null) manager.callHook('onCreate', []);
    return manager;
  }

  public function beginPauseMenu(pauseMenuState:PauseSubState):Void
  {
    this.pauseMenuState = pauseMenuState;
    pauseMenuConfiguredThisPass = false;
  }

  public function endPauseMenu():Void
  {
    this.pauseMenuState = null;
    pauseMenuConfiguredThisPass = false;
  }

  public function configureLuaPauseMenu(config:Dynamic):Bool
  {
    if (config == null) return false;
    ensureLuaPauseMenuConfig();

    if (Reflect.hasField(config, 'mode')) Reflect.setField(pauseMenuConfig, 'mode', Reflect.field(config, 'mode'));
    if (Reflect.hasField(config, 'options')) Reflect.setField(pauseMenuConfig, 'options', Reflect.field(config, 'options'));

    var incomingItems:Dynamic = Reflect.field(config, 'items');
    if (Std.isOfType(incomingItems, Array))
    {
      for (item in cast(incomingItems, Array<Dynamic>)) upsertLuaPauseMenuItem(item);
    }

    applyLuaPauseMenuConfig();
    return true;
  }

  public function setLuaPauseMenuItem(matchOrId:String, label:String, position:Int, target:String, hidden:Bool):Bool
  {
    if (matchOrId == '') return false;
    ensureLuaPauseMenuConfig();
    var items:Dynamic = Reflect.field(pauseMenuConfig, 'items');
    if (!Std.isOfType(items, Array))
    {
      items = [];
      Reflect.setField(pauseMenuConfig, 'items', items);
    }

    var item:Dynamic = {};
    Reflect.setField(item, 'match', matchOrId);
    Reflect.setField(item, 'id', matchOrId);
    if (label != '') Reflect.setField(item, 'label', label);
    Reflect.setField(item, 'position', position);
    if (target != '') Reflect.setField(item, 'target', target);
    Reflect.setField(item, 'hidden', hidden);
    cast(items, Array<Dynamic>).push(item);
    applyLuaPauseMenuConfig();
    return true;
  }

  function upsertLuaPauseMenuItem(item:Dynamic):Void
  {
    if (item == null) return;
    ensureLuaPauseMenuConfig();

    var items:Dynamic = Reflect.field(pauseMenuConfig, 'items');
    if (!Std.isOfType(items, Array))
    {
      items = [];
      Reflect.setField(pauseMenuConfig, 'items', items);
    }

    var key = pauseMenuItemKey(item);
    var itemArray:Array<Dynamic> = cast items;
    if (key != '')
    {
      for (i in 0...itemArray.length)
      {
        if (pauseMenuItemKey(itemArray[i]) == key)
        {
          itemArray[i] = item;
          return;
        }
      }
    }

    itemArray.push(item);
  }

  function pauseMenuItemKey(item:Dynamic):String
  {
    if (item == null) return '';
    if (Reflect.hasField(item, 'match')) return Std.string(Reflect.field(item, 'match')).toLowerCase();
    if (Reflect.hasField(item, 'id')) return Std.string(Reflect.field(item, 'id')).toLowerCase();
    return '';
  }
  function ensureLuaPauseMenuConfig():Void
  {
    if (pauseMenuConfig == null) pauseMenuConfig = {mode: 'standard', items: []};
    if (!Reflect.hasField(pauseMenuConfig, 'items')) Reflect.setField(pauseMenuConfig, 'items', []);
  }
  public function applyLuaPauseMenuConfig():Bool
  {
    if (pauseMenuState == null || pauseMenuConfig == null || pauseMenuConfiguredThisPass) return false;
    pauseMenuConfiguredThisPass = pauseMenuState.configureLuaPauseMenu(pauseMenuConfig, function(id:String)
    {
      callHook('onLuaPauseMenuAccept', [id]);
    });
    return pauseMenuConfiguredThisPass;
  }

  static function collectOptionLuaScripts(folder:String, scriptPaths:Array<String>, extension:String):Void
  {
    collectScriptFolder(folder, scriptPaths, extension);
  }

  static function collectScriptFolder(folder:String, scriptPaths:Array<String>, extension:String):Void
  {
    if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;

    for (entry in FileSystem.readDirectory(folder))
    {
      var path = '${folder}/${entry}';
      if (FileSystem.isDirectory(path))
      {
        collectScriptFolder(path, scriptPaths, extension);
        continue;
      }
      if (StringTools.endsWith(path.toLowerCase(), extension)) scriptPaths.push(path);
    }
  }

  function isGlobalScript(path:String):Bool
  {
    return StringTools.endsWith(path.toLowerCase(), '.luag');
  }

  function createScriptEnvironment():Int
  {
    Lua.newtable(state);
    Lua.newtable(state);
    Lua.pushglobaltable(state);
    Lua.setfield(state, -2, '__index');
    Lua.setmetatable(state, -2);
    return LuaL.ref(state, Lua.REGISTRYINDEX);
  }

  function snapshotGlobalHooks():Map<String, Int>
  {
    var hooks:Map<String, Int> = [];

    for (hookName in LUA_HOOK_NAMES)
    {
      Lua.getglobal(state, hookName);
      if (Lua.type(state, -1) == Lua.TFUNCTION)
      {
        hooks.set(hookName, LuaL.ref(state, Lua.REGISTRYINDEX));
      }
      else
      {
        Lua.pop(state, 1);
      }
    }

    return hooks;
  }

  function captureChangedGlobalHooks(scriptPath:String, previousHooks:Map<String, Int>):Void
  {
    var scriptHooks:Map<String, Int> = [];

    for (hookName in LUA_HOOK_NAMES)
    {
      Lua.getglobal(state, hookName);
      if (Lua.type(state, -1) != Lua.TFUNCTION)
      {
        Lua.pop(state, 1);
        continue;
      }

      var changed = true;
      final previousRef = previousHooks.get(hookName);
      if (previousRef != null)
      {
        Lua.rawgeti(state, Lua.REGISTRYINDEX, previousRef);
        changed = Lua.rawequal(state, -1, -2) == 0;
        Lua.pop(state, 1);
      }

      if (changed)
      {
        scriptHooks.set(hookName, LuaL.ref(state, Lua.REGISTRYINDEX));
      }
      else
      {
        Lua.pop(state, 1);
      }
    }

    if (scriptHooks.keys().hasNext()) globalScriptHookRefs.set(scriptPath, scriptHooks);
  }

  function releaseGlobalScriptHooks(scriptPath:String):Void
  {
    final scriptHooks = globalScriptHookRefs.get(scriptPath);
    if (scriptHooks == null) return;

    releaseHookRefs(scriptHooks);
    globalScriptHookRefs.remove(scriptPath);
  }

  function releaseHookRefs(hooks:Map<String, Int>):Void
  {
    for (hookRef in hooks)
    {
      LuaL.unref(state, Lua.REGISTRYINDEX, hookRef);
    }
  }

  function reportLuaWarning(kind:String, scriptPath:String, hookName:Null<String>, message:String):Void
  {
    trace('[LuaScriptManager] ${message}');
    LuaWindowErrorManager.warn(kind, scriptPath, hookName, message, currentLuaFiles.length == 0 ? [scriptPath] : currentLuaFiles.copy());
  }

  function clearRuntimeObjects():Void
  {
    for (tween in tweens) tween.cancel();
    tweens.clear();

    for (timer in timers) timer.cancel();
    timers.clear();

    for (sound in sounds) sound.destroy();
    sounds.clear();

    var playState = PlayState.instance;
    var hostState = playState != null ? playState : FlxG.state;

    for (sprite in sprites)
    {
      hostState?.remove(sprite, true);
      sprite.destroy();
    }
    sprites.clear();

    for (text in texts)
    {
      hostState?.remove(text, true);
      text.destroy();
    }
    texts.clear();

    for (object in objects)
    {
      if (Std.isOfType(object, FlxBasic)) hostState?.remove(cast object, true);
      var destroy = safeField(object, 'destroy');
      if (destroy != null) safeCallMethod(object, destroy, []);
    }
    objects.clear();

    menusManager.clear();
    shaderManager.clear();
  }

  function configurePackagePath():Void
  {
    var paths:Array<String> = [
      'mods/?.lua',
      'mods/?.luag',
      'mods/?/init.lua',
      'mods/?/init.luag',
      'mods/scripts/?.lua',
      'mods/scripts/?.luag',
      'mods/scripts/?/init.lua',
      'mods/scripts/?/init.luag'
    ];
    addPackagePaths(paths, 'mods/scripts');

    if (FileSystem.exists('mods') && FileSystem.isDirectory('mods'))
    {
      for (modName in FileSystem.readDirectory('mods'))
      {
        var modPath = 'mods/${modName}';
        if (!FileSystem.isDirectory(modPath)) continue;
        paths.push('${modPath}/?.lua');
        paths.push('${modPath}/?.luag');
        paths.push('${modPath}/?/init.lua');
        paths.push('${modPath}/?/init.luag');
        paths.push('${modPath}/script/?.lua');
        paths.push('${modPath}/script/?.luag');
        paths.push('${modPath}/script/?/init.lua');
        paths.push('${modPath}/script/?/init.luag');
        paths.push('${modPath}/scripts/?.lua');
        paths.push('${modPath}/scripts/?.luag');
        paths.push('${modPath}/scripts/?/init.lua');
        paths.push('${modPath}/scripts/?/init.luag');
        addPackagePaths(paths, '${modPath}/script');
        addPackagePaths(paths, '${modPath}/scripts');
      }
    }

    Lua.getglobal(state, 'package');
    if (Lua.type(state, -1) != Lua.TTABLE)
    {
      Lua.pop(state, 1);
      return;
    }

    Lua.getfield(state, -1, 'path');
    var existingPath = Lua.type(state, -1) == Lua.TSTRING ? Std.string(Lua.tostring(state, -1)) : '';
    Lua.pop(state, 1);
    Lua.pushstring(state, existingPath + ';' + paths.join(';'));
    Lua.setfield(state, -2, 'path');
    Lua.pop(state, 1);
  }

  function addPackagePaths(paths:Array<String>, folder:String):Void
  {
    for (category in LUA_SCRIPT_FOLDERS)
    {
      if (category != 'luag')
      {
        paths.push('${folder}/${category}/?.lua');
        paths.push('${folder}/${category}/?/init.lua');
      }

      if (category != 'lua')
      {
        paths.push('${folder}/${category}/?.luag');
        paths.push('${folder}/${category}/?/init.luag');
      }
    }
  }

  function updateGlobals():Void
  {
    var playState = PlayState.instance;

    setGlobal('luaSupportVersion', '1.0');
    setGlobal('luaScriptCount', loadedScripts.length);
    setGlobal('luaGlobalScriptCount', countLoadedScripts(true));
    setGlobal('luaIsolatedScriptCount', countLoadedScripts(false));
    setGlobal('songName', playState?.currentSong?.songName ?? '');
    setGlobal('songId', playState?.currentSong?.id ?? '');
    setGlobal('difficultyName', playState?.currentDifficulty ?? '');
    setGlobal('variationName', playState?.currentVariation ?? '');
    setGlobal('stageId', playState?.currentStageId ?? '');
    setGlobal('curBeat', Std.int(Conductor.instance.currentBeat));
    setGlobal('curStep', Std.int(Conductor.instance.currentStep));
    setGlobal('songPosition', Conductor.instance.songPosition);
    setGlobal('health', playState?.health ?? 0);
    setGlobal('score', playState?.songScore ?? 0);
    setGlobal('combo', Highscore.tallies.combo);
    setGlobal('botPlay', playState?.isBotPlayMode ?? false);
    setGlobal('practice', playState?.isPracticeMode ?? false);
  }

  function setGlobal(name:String, value:Dynamic):Void
  {
    pushValue(value);
    Lua.setglobal(state, name);
  }

  function countLoadedScripts(global:Bool):Int
  {
    var count = 0;
    for (scriptPath in loadedScripts)
    {
      if ((scriptGlobalModes.get(scriptPath) == true) == global) count++;
    }
    return count;
  }

  function registerAPI():Void
  {
    Lua.register(state, 'debugPrint', cpp.Callable.fromStaticFunction(lua_debugPrint));
    Lua.register(state, 'luaTrace', cpp.Callable.fromStaticFunction(lua_debugPrint));
    Lua.register(state, 'reloadLuaScripts', cpp.Callable.fromStaticFunction(lua_reloadLuaScripts));
    Lua.register(state, 'getCurrentEvent', cpp.Callable.fromStaticFunction(lua_getCurrentEvent));
    Lua.register(state, 'getEventField', cpp.Callable.fromStaticFunction(lua_getEventField));
    Lua.register(state, 'setEventField', cpp.Callable.fromStaticFunction(lua_setEventField));
    Lua.register(state, 'cancelEvent', cpp.Callable.fromStaticFunction(lua_cancelEvent));
    Lua.register(state, 'stopEventPropagation', cpp.Callable.fromStaticFunction(lua_stopEventPropagation));
    Lua.register(state, 'getProperty', cpp.Callable.fromStaticFunction(lua_getProperty));
    Lua.register(state, 'setProperty', cpp.Callable.fromStaticFunction(lua_setProperty));
    Lua.register(state, 'getObjectProperty', cpp.Callable.fromStaticFunction(lua_getProperty));
    Lua.register(state, 'setObjectProperty', cpp.Callable.fromStaticFunction(lua_setProperty));
    Lua.register(state, 'callMethod', cpp.Callable.fromStaticFunction(lua_callMethod));
    Lua.register(state, 'classExists', cpp.Callable.fromStaticFunction(lua_classExists));
    Lua.register(state, 'getStaticProperty', cpp.Callable.fromStaticFunction(lua_getStaticProperty));
    Lua.register(state, 'setStaticProperty', cpp.Callable.fromStaticFunction(lua_setStaticProperty));
    Lua.register(state, 'callStatic', cpp.Callable.fromStaticFunction(lua_callStatic));
    Lua.register(state, 'createInstance', cpp.Callable.fromStaticFunction(lua_createInstance));
    Lua.register(state, 'storeObject', cpp.Callable.fromStaticFunction(lua_storeObject));
    Lua.register(state, 'forgetObject', cpp.Callable.fromStaticFunction(lua_forgetObject));
    Lua.register(state, 'addObjectToState', cpp.Callable.fromStaticFunction(lua_addObjectToState));
    Lua.register(state, 'removeObjectFromState', cpp.Callable.fromStaticFunction(lua_removeObjectFromState));
    Lua.register(state, 'destroyObject', cpp.Callable.fromStaticFunction(lua_destroyObject));
    Lua.register(state, 'getArrayLength', cpp.Callable.fromStaticFunction(lua_getArrayLength));
    Lua.register(state, 'getArrayItem', cpp.Callable.fromStaticFunction(lua_getArrayItem));
    Lua.register(state, 'setArrayItem', cpp.Callable.fromStaticFunction(lua_setArrayItem));
    Lua.register(state, 'jsonParse', cpp.Callable.fromStaticFunction(lua_jsonParse));
    Lua.register(state, 'jsonStringify', cpp.Callable.fromStaticFunction(lua_jsonStringify));
    Lua.register(state, 'fileExists', cpp.Callable.fromStaticFunction(lua_fileExists));
    Lua.register(state, 'directoryExists', cpp.Callable.fromStaticFunction(lua_directoryExists));
    Lua.register(state, 'readTextFile', cpp.Callable.fromStaticFunction(lua_readTextFile));
    Lua.register(state, 'writeTextFile', cpp.Callable.fromStaticFunction(lua_writeTextFile));
    Lua.register(state, 'randomFloat', cpp.Callable.fromStaticFunction(lua_randomFloat));
    Lua.register(state, 'randomInt', cpp.Callable.fromStaticFunction(lua_randomInt));
    Lua.register(state, 'keyPressed', cpp.Callable.fromStaticFunction(lua_keyPressed));
    Lua.register(state, 'keyJustPressed', cpp.Callable.fromStaticFunction(lua_keyJustPressed));
    Lua.register(state, 'keyJustReleased', cpp.Callable.fromStaticFunction(lua_keyJustReleased));
    Lua.register(state, 'mouseX', cpp.Callable.fromStaticFunction(lua_mouseX));
    Lua.register(state, 'mouseY', cpp.Callable.fromStaticFunction(lua_mouseY));
    Lua.register(state, 'mousePressed', cpp.Callable.fromStaticFunction(lua_mousePressed));
    Lua.register(state, 'mouseJustPressed', cpp.Callable.fromStaticFunction(lua_mouseJustPressed));
    Lua.register(state, 'mouseJustReleased', cpp.Callable.fromStaticFunction(lua_mouseJustReleased));

    Lua.register(state, 'getSongPosition', cpp.Callable.fromStaticFunction(lua_getSongPosition));
    Lua.register(state, 'getBeat', cpp.Callable.fromStaticFunction(lua_getBeat));
    Lua.register(state, 'getStep', cpp.Callable.fromStaticFunction(lua_getStep));
    Lua.register(state, 'getSongName', cpp.Callable.fromStaticFunction(lua_getSongName));
    Lua.register(state, 'getDifficulty', cpp.Callable.fromStaticFunction(lua_getDifficulty));
    Lua.register(state, 'getVariation', cpp.Callable.fromStaticFunction(lua_getVariation));
    Lua.register(state, 'getStageId', cpp.Callable.fromStaticFunction(lua_getStageId));
    Lua.register(state, 'getPlaybackRate', cpp.Callable.fromStaticFunction(lua_getPlaybackRate));
    Lua.register(state, 'setPlaybackRate', cpp.Callable.fromStaticFunction(lua_setPlaybackRate));
    Lua.register(state, 'getScrollSpeed', cpp.Callable.fromStaticFunction(lua_getScrollSpeed));
    Lua.register(state, 'setScrollSpeed', cpp.Callable.fromStaticFunction(lua_setScrollSpeed));
    Lua.register(state, 'getChartNotes', cpp.Callable.fromStaticFunction(lua_getChartNotes));
    Lua.register(state, 'getChartEvents', cpp.Callable.fromStaticFunction(lua_getChartEvents));
    Lua.register(state, 'setStrumlinePosition', cpp.Callable.fromStaticFunction(lua_setStrumlinePosition));
    Lua.register(state, 'setStrumlineAlpha', cpp.Callable.fromStaticFunction(lua_setStrumlineAlpha));
    Lua.register(state, 'setStrumlineVisible', cpp.Callable.fromStaticFunction(lua_setStrumlineVisible));
    Lua.register(state, 'setStrumlineNotePosition', cpp.Callable.fromStaticFunction(lua_setStrumlineNotePosition));
    Lua.register(state, 'playStrumlineAnimation', cpp.Callable.fromStaticFunction(lua_playStrumlineAnimation));
    Lua.register(state, 'setBotplay', cpp.Callable.fromStaticFunction(lua_setBotplay));
    Lua.register(state, 'setPracticeMode', cpp.Callable.fromStaticFunction(lua_setPracticeMode));
    Lua.register(state, 'getPreference', cpp.Callable.fromStaticFunction(lua_getPreference));
    Lua.register(state, 'setPreference', cpp.Callable.fromStaticFunction(lua_setPreference));
    Lua.register(state, 'defineLuaOption', cpp.Callable.fromStaticFunction(lua_defineLuaOption));
    Lua.register(state, 'getLuaOption', cpp.Callable.fromStaticFunction(lua_getLuaOption));
    Lua.register(state, 'setLuaOption', cpp.Callable.fromStaticFunction(lua_setLuaOption));
    Lua.register(state, 'hasLuaOption', cpp.Callable.fromStaticFunction(lua_hasLuaOption));
    Lua.register(state, 'removeLuaOption', cpp.Callable.fromStaticFunction(lua_removeLuaOption));
    Lua.register(state, 'getLuaOptions', cpp.Callable.fromStaticFunction(lua_getLuaOptions));
    Lua.register(state, 'createLuaOptionPage', cpp.Callable.fromStaticFunction(lua_createLuaOptionPage));
    Lua.register(state, 'addLuaCheckbox', cpp.Callable.fromStaticFunction(lua_addLuaCheckbox));
    Lua.register(state, 'addLuaNumber', cpp.Callable.fromStaticFunction(lua_addLuaNumber));
    Lua.register(state, 'addLuaEnum', cpp.Callable.fromStaticFunction(lua_addLuaEnum));
    Lua.register(state, 'flushSave', cpp.Callable.fromStaticFunction(lua_flushSave));
    Lua.register(state, 'getScreenWidth', cpp.Callable.fromStaticFunction(lua_getScreenWidth));
    Lua.register(state, 'getScreenHeight', cpp.Callable.fromStaticFunction(lua_getScreenHeight));
    Lua.register(state, 'setFullscreen', cpp.Callable.fromStaticFunction(lua_setFullscreen));
    Lua.register(state, 'getHealth', cpp.Callable.fromStaticFunction(lua_getHealth));
    Lua.register(state, 'setHealth', cpp.Callable.fromStaticFunction(lua_setHealth));
    Lua.register(state, 'addHealth', cpp.Callable.fromStaticFunction(lua_addHealth));
    Lua.register(state, 'getScore', cpp.Callable.fromStaticFunction(lua_getScore));
    Lua.register(state, 'setScore', cpp.Callable.fromStaticFunction(lua_setScore));
    Lua.register(state, 'addScore', cpp.Callable.fromStaticFunction(lua_addScore));
    Lua.register(state, 'getCombo', cpp.Callable.fromStaticFunction(lua_getCombo));
    Lua.register(state, 'setCombo', cpp.Callable.fromStaticFunction(lua_setCombo));
    Lua.register(state, 'getAccuracy', cpp.Callable.fromStaticFunction(lua_getAccuracy));
    Lua.register(state, 'getTallies', cpp.Callable.fromStaticFunction(lua_getTallies));
    Lua.register(state, 'setVocalsVolume', cpp.Callable.fromStaticFunction(lua_setVocalsVolume));
    Lua.register(state, 'startCountdown', cpp.Callable.fromStaticFunction(lua_startCountdown));
    Lua.register(state, 'startConversation', cpp.Callable.fromStaticFunction(lua_startConversation));
    Lua.register(state, 'playVideo', cpp.Callable.fromStaticFunction(lua_playVideo));
    Lua.register(state, 'pauseVideo', cpp.Callable.fromStaticFunction(lua_pauseVideo));
    Lua.register(state, 'resumeVideo', cpp.Callable.fromStaticFunction(lua_resumeVideo));
    Lua.register(state, 'finishVideo', cpp.Callable.fromStaticFunction(lua_finishVideo));
    Lua.register(state, 'isVideoPlaying', cpp.Callable.fromStaticFunction(lua_isVideoPlaying));
    Lua.register(state, 'endSong', cpp.Callable.fromStaticFunction(lua_endSong));
    Lua.register(state, 'restartSong', cpp.Callable.fromStaticFunction(lua_restartSong));

    Lua.register(state, 'addSprite', cpp.Callable.fromStaticFunction(lua_addSprite));
    Lua.register(state, 'loadGraphic', cpp.Callable.fromStaticFunction(lua_loadGraphic));
    Lua.register(state, 'loadSparrow', cpp.Callable.fromStaticFunction(lua_loadSparrow));
    Lua.register(state, 'makeSolidSprite', cpp.Callable.fromStaticFunction(lua_makeSolidSprite));
    Lua.register(state, 'removeSprite', cpp.Callable.fromStaticFunction(lua_removeSprite));
    Lua.register(state, 'setSpriteCamera', cpp.Callable.fromStaticFunction(lua_setSpriteCamera));
    Lua.register(state, 'addText', cpp.Callable.fromStaticFunction(lua_addText));
    Lua.register(state, 'setText', cpp.Callable.fromStaticFunction(lua_setText));
    Lua.register(state, 'setTextFormat', cpp.Callable.fromStaticFunction(lua_setTextFormat));
    Lua.register(state, 'removeText', cpp.Callable.fromStaticFunction(lua_removeText));
    Lua.register(state, 'setObjectCamera', cpp.Callable.fromStaticFunction(lua_setObjectCamera));
    Lua.register(state, 'setObjectPosition', cpp.Callable.fromStaticFunction(lua_setObjectPosition));
    Lua.register(state, 'getObjectX', cpp.Callable.fromStaticFunction(lua_getObjectX));
    Lua.register(state, 'getObjectY', cpp.Callable.fromStaticFunction(lua_getObjectY));
    Lua.register(state, 'getObjectWidth', cpp.Callable.fromStaticFunction(lua_getObjectWidth));
    Lua.register(state, 'getObjectHeight', cpp.Callable.fromStaticFunction(lua_getObjectHeight));
    Lua.register(state, 'getObjectAlpha', cpp.Callable.fromStaticFunction(lua_getObjectAlpha));
    Lua.register(state, 'getObjectVisible', cpp.Callable.fromStaticFunction(lua_getObjectVisible));
    Lua.register(state, 'getObjectAngle', cpp.Callable.fromStaticFunction(lua_getObjectAngle));
    Lua.register(state, 'setObjectScale', cpp.Callable.fromStaticFunction(lua_setObjectScale));
    Lua.register(state, 'setObjectSize', cpp.Callable.fromStaticFunction(lua_setObjectSize));
    Lua.register(state, 'setObjectAlpha', cpp.Callable.fromStaticFunction(lua_setObjectAlpha));
    Lua.register(state, 'setObjectVisible', cpp.Callable.fromStaticFunction(lua_setObjectVisible));
    Lua.register(state, 'setObjectAngle', cpp.Callable.fromStaticFunction(lua_setObjectAngle));
    Lua.register(state, 'setObjectColor', cpp.Callable.fromStaticFunction(lua_setObjectColor));
    Lua.register(state, 'setObjectVelocity', cpp.Callable.fromStaticFunction(lua_setObjectVelocity));
    Lua.register(state, 'setObjectAcceleration', cpp.Callable.fromStaticFunction(lua_setObjectAcceleration));
    Lua.register(state, 'setObjectScrollFactor', cpp.Callable.fromStaticFunction(lua_setObjectScrollFactor));
    Lua.register(state, 'setObjectZIndex', cpp.Callable.fromStaticFunction(lua_setObjectZIndex));
    Lua.register(state, 'screenCenter', cpp.Callable.fromStaticFunction(lua_screenCenter));
    Lua.register(state, 'objectExists', cpp.Callable.fromStaticFunction(lua_objectExists));
    Lua.register(state, 'killObject', cpp.Callable.fromStaticFunction(lua_killObject));
    Lua.register(state, 'reviveObject', cpp.Callable.fromStaticFunction(lua_reviveObject));
    Lua.register(state, 'addAnimByPrefix', cpp.Callable.fromStaticFunction(lua_addAnimByPrefix));
    Lua.register(state, 'playAnim', cpp.Callable.fromStaticFunction(lua_playAnim));
    Lua.register(state, 'hasAnim', cpp.Callable.fromStaticFunction(lua_hasAnim));
    Lua.register(state, 'createLuaMenu', cpp.Callable.fromStaticFunction(lua_createLuaMenu));
    Lua.register(state, 'createLuaImageMenu', cpp.Callable.fromStaticFunction(lua_createLuaImageMenu));
    Lua.register(state, 'addLuaMainMenuItem', cpp.Callable.fromStaticFunction(lua_addLuaMainMenuItem));
    Lua.register(state, 'configureLuaPauseMenu', cpp.Callable.fromStaticFunction(lua_configureLuaPauseMenu));
    Lua.register(state, 'setLuaPauseOptionsBehavior', cpp.Callable.fromStaticFunction(lua_setLuaPauseOptionsBehavior));
    Lua.register(state, 'setLuaPauseMenuItem', cpp.Callable.fromStaticFunction(lua_setLuaPauseMenuItem));
    Lua.register(state, 'setLuaMenuItems', cpp.Callable.fromStaticFunction(lua_setLuaMenuItems));
    Lua.register(state, 'setLuaMenuPosition', cpp.Callable.fromStaticFunction(lua_setLuaMenuPosition));
    Lua.register(state, 'showLuaMenu', cpp.Callable.fromStaticFunction(lua_showLuaMenu));
    Lua.register(state, 'hideLuaMenu', cpp.Callable.fromStaticFunction(lua_hideLuaMenu));
    Lua.register(state, 'removeLuaMenu', cpp.Callable.fromStaticFunction(lua_removeLuaMenu));
    Lua.register(state, 'getLuaMenuSelected', cpp.Callable.fromStaticFunction(lua_getLuaMenuSelected));
    Lua.register(state, 'createShader', cpp.Callable.fromStaticFunction(lua_createShader));
    Lua.register(state, 'destroyShader', cpp.Callable.fromStaticFunction(lua_destroyShader));
    Lua.register(state, 'setShaderFloat', cpp.Callable.fromStaticFunction(lua_setShaderFloat));
    Lua.register(state, 'setShaderFloatArray', cpp.Callable.fromStaticFunction(lua_setShaderFloatArray));
    Lua.register(state, 'setShaderInt', cpp.Callable.fromStaticFunction(lua_setShaderInt));
    Lua.register(state, 'setShaderBool', cpp.Callable.fromStaticFunction(lua_setShaderBool));
    Lua.register(state, 'applyShader', cpp.Callable.fromStaticFunction(lua_applyShader));
    Lua.register(state, 'clearShader', cpp.Callable.fromStaticFunction(lua_clearShader));
    Lua.register(state, 'applyCameraShader', cpp.Callable.fromStaticFunction(lua_applyCameraShader));
    Lua.register(state, 'clearCameraShader', cpp.Callable.fromStaticFunction(lua_clearCameraShader));

    Lua.register(state, 'tween', cpp.Callable.fromStaticFunction(lua_tween));
    Lua.register(state, 'cancelTween', cpp.Callable.fromStaticFunction(lua_cancelTween));
    Lua.register(state, 'runTimer', cpp.Callable.fromStaticFunction(lua_runTimer));
    Lua.register(state, 'cancelTimer', cpp.Callable.fromStaticFunction(lua_cancelTimer));

    Lua.register(state, 'playSound', cpp.Callable.fromStaticFunction(lua_playSound));
    Lua.register(state, 'stopSound', cpp.Callable.fromStaticFunction(lua_stopSound));
    Lua.register(state, 'pauseSound', cpp.Callable.fromStaticFunction(lua_pauseSound));
    Lua.register(state, 'resumeSound', cpp.Callable.fromStaticFunction(lua_resumeSound));
    Lua.register(state, 'setSoundVolume', cpp.Callable.fromStaticFunction(lua_setSoundVolume));
    Lua.register(state, 'soundExists', cpp.Callable.fromStaticFunction(lua_soundExists));
    Lua.register(state, 'playMusic', cpp.Callable.fromStaticFunction(lua_playMusic));
    Lua.register(state, 'stopMusic', cpp.Callable.fromStaticFunction(lua_stopMusic));
    Lua.register(state, 'pauseMusic', cpp.Callable.fromStaticFunction(lua_pauseMusic));
    Lua.register(state, 'resumeMusic', cpp.Callable.fromStaticFunction(lua_resumeMusic));
    Lua.register(state, 'setMusicVolume', cpp.Callable.fromStaticFunction(lua_setMusicVolume));
    Lua.register(state, 'cameraFlash', cpp.Callable.fromStaticFunction(lua_cameraFlash));
    Lua.register(state, 'cameraFade', cpp.Callable.fromStaticFunction(lua_cameraFade));
    Lua.register(state, 'cameraShake', cpp.Callable.fromStaticFunction(lua_cameraShake));
    Lua.register(state, 'setCameraZoom', cpp.Callable.fromStaticFunction(lua_setCameraZoom));
    Lua.register(state, 'setCameraAlpha', cpp.Callable.fromStaticFunction(lua_setCameraAlpha));
    Lua.register(state, 'setCameraBgColor', cpp.Callable.fromStaticFunction(lua_setCameraBgColor));
    Lua.register(state, 'setCameraVisible', cpp.Callable.fromStaticFunction(lua_setCameraVisible));
    Lua.register(state, 'setCameraPosition', cpp.Callable.fromStaticFunction(lua_setCameraPosition));
    Lua.register(state, 'setCameraFollow', cpp.Callable.fromStaticFunction(lua_setCameraFollow));
    Lua.register(state, 'setCameraBop', cpp.Callable.fromStaticFunction(lua_setCameraBop));
    Lua.register(state, 'setHealthBarColors', cpp.Callable.fromStaticFunction(lua_setHealthBarColors));
    Lua.register(state, 'resetCamera', cpp.Callable.fromStaticFunction(lua_resetCamera));
    Lua.register(state, 'tweenCameraZoom', cpp.Callable.fromStaticFunction(lua_tweenCameraZoom));
    Lua.register(state, 'tweenCameraToPosition', cpp.Callable.fromStaticFunction(lua_tweenCameraToPosition));
    Lua.register(state, 'cancelCameraTweens', cpp.Callable.fromStaticFunction(lua_cancelCameraTweens));
    Lua.register(state, 'tweenScrollSpeed', cpp.Callable.fromStaticFunction(lua_tweenScrollSpeed));
    Lua.register(state, 'cancelScrollSpeedTweens', cpp.Callable.fromStaticFunction(lua_cancelScrollSpeedTweens));

    Lua.register(state, 'pathImage', cpp.Callable.fromStaticFunction(lua_pathImage));
    Lua.register(state, 'pathSound', cpp.Callable.fromStaticFunction(lua_pathSound));
    Lua.register(state, 'pathMusic', cpp.Callable.fromStaticFunction(lua_pathMusic));
    Lua.register(state, 'pathFont', cpp.Callable.fromStaticFunction(lua_pathFont));
    Lua.register(state, 'pathFile', cpp.Callable.fromStaticFunction(lua_pathFile));
    Lua.register(state, 'pathJson', cpp.Callable.fromStaticFunction(lua_pathJson));

    registerPsychStyleAliases();
    installSimpleAPI();
  }

  function installSimpleAPI():Void
  {
    if (LuaL.dostring(state, LuaApiPrelude.source()) != Lua.OK)
    {
      final error = readError();
      trace('[LuaScriptManager] Failed to install LuaSlice helper API: ${error}');
      LuaWindowErrorManager.report('api-prelude-error', 'lua-api', 'LuaSlice', error);
    }
  }
  function registerPsychStyleAliases():Void
  {
    Lua.register(state, 'makeLuaSprite', cpp.Callable.fromStaticFunction(lua_addSprite));
    Lua.register(state, 'makeAnimatedLuaSprite', cpp.Callable.fromStaticFunction(lua_addAnimatedSpriteAlias));
    Lua.register(state, 'makeGraphic', cpp.Callable.fromStaticFunction(lua_makeGraphicAlias));
    Lua.register(state, 'addLuaSprite', cpp.Callable.fromStaticFunction(lua_noopTrue));
    Lua.register(state, 'removeLuaSprite', cpp.Callable.fromStaticFunction(lua_removeSprite));
    Lua.register(state, 'makeLuaText', cpp.Callable.fromStaticFunction(lua_makeLuaTextAlias));
    Lua.register(state, 'setTextString', cpp.Callable.fromStaticFunction(lua_setText));
    Lua.register(state, 'removeLuaText', cpp.Callable.fromStaticFunction(lua_removeText));
    Lua.register(state, 'doTween', cpp.Callable.fromStaticFunction(lua_tween));
    Lua.register(state, 'doTweenX', cpp.Callable.fromStaticFunction(lua_tweenObjectX));
    Lua.register(state, 'doTweenY', cpp.Callable.fromStaticFunction(lua_tweenObjectY));
    Lua.register(state, 'doTweenAlpha', cpp.Callable.fromStaticFunction(lua_tweenObjectAlpha));
    Lua.register(state, 'doTweenAngle', cpp.Callable.fromStaticFunction(lua_tweenObjectAngle));
    Lua.register(state, 'runTimer', cpp.Callable.fromStaticFunction(lua_runTimer));
    Lua.register(state, 'cancelTimer', cpp.Callable.fromStaticFunction(lua_cancelTimer));
  }

  function pushValue(value:Dynamic):Void
  {
    if (value == null)
    {
      Lua.pushnil(state);
    }
    else if (Std.isOfType(value, Bool))
    {
      Lua.pushboolean(state, value ? 1 : 0);
    }
    else if (Std.isOfType(value, Int))
    {
      Lua.pushinteger(state, cast(value, Int));
    }
    else if (Std.isOfType(value, Float))
    {
      Lua.pushnumber(state, cast(value, Float));
    }
    else if (Std.isOfType(value, Array))
    {
      pushArray(cast value);
    }
    else if (Reflect.isObject(value) && !Std.isOfType(value, String))
    {
      pushTable(value);
    }
    else
    {
      Lua.pushstring(state, Std.string(value));
    }
  }

  function pushArray(values:Array<Dynamic>):Void
  {
    Lua.createtable(state, values.length, 0);

    for (i in 0...values.length)
    {
      pushValue(values[i]);
      Lua.rawseti(state, -2, i + 1);
    }
  }

  function pushTable(value:Dynamic):Void
  {
    Lua.createtable(state, 0, 0);

    var fields:Array<String> = [];
    try
    {
      fields = Reflect.fields(value);
    }
    catch (e)
    {
      return;
    }

    for (field in fields)
    {
      pushValue(safeField(value, field));
      Lua.setfield(state, -2, field);
    }
  }

  function pushReturn(value:Dynamic):Int
  {
    pushValue(value);
    return 1;
  }

  function readError():String
  {
    var message:String = Std.string(Lua.tostring(state, -1));
    Lua.settop(state, -2);
    return message;
  }

  function eventToPayload(event:ScriptEvent):Dynamic
  {
    var payload:Dynamic = {
      type: Std.string(event.type),
      cancelable: event.cancelable,
      eventCanceled: event.eventCanceled
    };

    var fields:Array<String> = [];
    try
    {
      fields = Reflect.fields(event);
    }
    catch (e)
    {
      return payload;
    }

    for (field in fields)
    {
      var value = safeField(event, field);
      if (field == 'note' && value != null)
      {
        Reflect.setField(payload, 'note', {
          strumTime: safeGetProperty(value, 'strumTime'),
          direction: stringifyNullable(safeGetProperty(value, 'direction')),
          noteData: stringifyNullable(safeGetProperty(value, 'noteData')),
          kind: stringifyNullable(safeGetProperty(value, 'kind'))
        });
      }
      else if (field == 'eventData' && value != null)
      {
        Reflect.setField(payload, 'eventData', {
          eventKind: Std.string(safeGetProperty(value, 'eventKind')),
          value: Std.string(safeGetProperty(value, 'value')),
          time: safeGetProperty(value, 'time')
        });
      }
      else if (!Std.isOfType(value, FlxSprite))
      {
        Reflect.setField(payload, field, value);
      }
    }

    return payload;
  }

  static function stringifyNullable(value:Dynamic):Null<String>
  {
    return value == null ? null : Std.string(value);
  }
  static function current():Null<LuaScriptManager>
  {
    return activeManager;
  }

  static function lua_debugPrint(L:cpp.RawPointer<Lua_State>):Int
  {
    var message = readString(L, 1, '');
    trace('[Lua] ${message}');
    return 0;
  }

  static function lua_reloadLuaScripts(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var playState = PlayState.instance;
    if (playState == null) return manager.pushReturn(false);

    playState.requestLuaReload();
    return manager.pushReturn(true);
  }

  static function lua_noopTrue(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(true) ?? 0;
  }

  static function lua_getCurrentEvent(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    if (manager.currentEvent == null) return manager.pushReturn(null);
    return manager.pushReturn(manager.eventToPayload(manager.currentEvent));
  }

  static function lua_getEventField(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    if (manager.currentEvent == null) return manager.pushReturn(null);
    return manager.pushReturn(manager.resolveEventPath(readString(L, 1, '')).value);
  }

  static function lua_setEventField(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null || manager.currentEvent == null) return 0;

    var resolved = manager.resolveEventParent(readString(L, 1, ''));
    if (resolved.target == null || resolved.field == '') return manager.pushReturn(false);

    return manager.pushReturn(manager.safeSetProperty(resolved.target, resolved.field, manager.readValue(L, 2), false));
  }

  static function lua_cancelEvent(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null || manager.currentEvent == null) return 0;

    manager.currentEvent.cancelEvent();
    return manager.pushReturn(manager.currentEvent.eventCanceled);
  }

  static function lua_stopEventPropagation(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null || manager.currentEvent == null) return 0;

    manager.currentEvent.stopPropagation();
    return manager.pushReturn(true);
  }

  static function lua_getProperty(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.resolvePath(readString(L, 1, '')).value);
  }

  static function lua_setProperty(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var path = readString(L, 1, '');
    var value = manager.readValue(L, 2);
    var resolved = manager.resolveParent(path);

    if (resolved.target == null || resolved.field == '')
    {
      manager.reportLuaWarning('api-error', 'lua-api', 'setProperty', 'setProperty failed. Invalid path: ${path}');
      return manager.pushReturn(false);
    }

    return manager.pushReturn(manager.safeSetProperty(resolved.target, resolved.field, value));
  }

  static function lua_callMethod(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var path = readString(L, 1, '');
    var args:Array<Dynamic> = [];
    var top = Lua.gettop(L);
    for (i in 2...(top + 1)) args.push(manager.readValue(L, i));

    var resolved = manager.resolveParent(path);
    if (resolved.target == null || resolved.field == '')
    {
      manager.reportLuaWarning('api-error', 'lua-api', 'callMethod', 'callMethod failed. Invalid path: ${path}');
      return 0;
    }

    var method = manager.safeField(resolved.target, resolved.field);
    if (method == null)
    {
      manager.reportLuaWarning('api-error', 'lua-api', 'callMethod', 'callMethod failed. Missing function: ${path}');
      return 0;
    }

    var called = manager.safeCallMethod(resolved.target, method, args);
    return manager.pushReturn(called.value);
  }

  static function lua_classExists(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(Type.resolveClass(readString(L, 1, '')) != null) ?? 0;
  }

  static function lua_getStaticProperty(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var targetClass = Type.resolveClass(readString(L, 1, ''));
    if (targetClass == null) return manager.pushReturn(null);

    return manager.pushReturn(manager.safeGetProperty(targetClass, readString(L, 2, '')));
  }

  static function lua_setStaticProperty(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var targetClass = Type.resolveClass(readString(L, 1, ''));
    if (targetClass == null) return manager.pushReturn(false);

    return manager.pushReturn(manager.safeSetProperty(targetClass, readString(L, 2, ''), manager.readValue(L, 3)));
  }

  static function lua_callStatic(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var targetClass = Type.resolveClass(readString(L, 1, ''));
    if (targetClass == null) return manager.pushReturn(null);

    var method = manager.safeField(targetClass, readString(L, 2, ''));
    if (method == null) return manager.pushReturn(null);

    return manager.pushReturn(manager.safeCallMethod(targetClass, method, manager.readArgs(L, 3)).value);
  }

  static function lua_createInstance(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var targetClass = Type.resolveClass(readString(L, 2, ''));
    if (tag == '' || targetClass == null) return manager.pushReturn(false);

    try
    {
      manager.objects.set(tag, Type.createInstance(targetClass, manager.readArgs(L, 3)));
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] createInstance failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_storeObject(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var value = manager.resolvePath(readString(L, 2, '')).value;
    if (tag == '' || value == null) return manager.pushReturn(false);

    manager.objects.set(tag, value);
    return manager.pushReturn(true);
  }

  static function lua_forgetObject(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.objects.remove(readString(L, 1, '')));
  }

  static function lua_addObjectToState(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var object = manager.objects.get(readString(L, 1, ''));
    if (object == null || !Std.isOfType(object, FlxBasic)) return manager.pushReturn(false);

    playState.add(cast object);
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_removeObjectFromState(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var object = manager.objects.get(readString(L, 1, ''));
    if (object == null || !Std.isOfType(object, FlxBasic)) return manager.pushReturn(false);

    playState.remove(cast object, true);
    return manager.pushReturn(true);
  }

  static function lua_destroyObject(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var object = manager.objects.get(tag);
    if (object == null) return manager.pushReturn(false);

    var playState = PlayState.instance;
    if (playState != null && Std.isOfType(object, FlxBasic)) playState.remove(cast object, true);
    var destroy = manager.safeField(object, 'destroy');
    if (destroy != null) manager.safeCallMethod(object, destroy, []);
    manager.objects.remove(tag);
    return manager.pushReturn(true);
  }

  static function lua_getArrayLength(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var value = manager.resolvePath(readString(L, 1, '')).value;
    if (value == null) return manager.pushReturn(0);
    if (Std.isOfType(value, Array)) return manager.pushReturn(cast(value, Array<Dynamic>).length);
    var length = manager.safeGetProperty(value, 'length');
    return manager.pushReturn(length ?? 0);
  }

  static function lua_getArrayItem(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var value = manager.resolvePath(readString(L, 1, '')).value;
    var index = readInt(L, 2, 0);
    if (value == null) return manager.pushReturn(null);
    if (Std.isOfType(value, Array)) return manager.pushReturn(cast(value, Array<Dynamic>)[index]);
    return manager.pushReturn(manager.safeGetProperty(value, Std.string(index)));
  }

  static function lua_setArrayItem(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var value = manager.resolvePath(readString(L, 1, '')).value;
    var index = readInt(L, 2, 0);
    var item = manager.readValue(L, 3);
    if (value == null) return manager.pushReturn(false);
    if (Std.isOfType(value, Array))
    {
      cast(value, Array<Dynamic>)[index] = item;
      return manager.pushReturn(true);
    }
    return manager.pushReturn(manager.safeSetProperty(value, Std.string(index), item));
  }

  static function lua_jsonParse(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    try
    {
      return manager.pushReturn(Json.parse(readString(L, 1, '{}')));
    }
    catch (e)
    {
      trace('[LuaScriptManager] jsonParse failed: ${e}');
      Lua.pushnil(L);
      return 1;
    }
  }

  static function lua_jsonStringify(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    try
    {
      return manager.pushReturn(Json.stringify(manager.readValue(L, 1), null, readString(L, 2, '')));
    }
    catch (e)
    {
      trace('[LuaScriptManager] jsonStringify failed: ${e}');
      return manager.pushReturn(null);
    }
  }

  static function lua_fileExists(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(FileSystem.exists(readString(L, 1, '')));
    }
    catch (e)
    {
      return manager.pushReturn(false);
    }
  }

  static function lua_directoryExists(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var path = readString(L, 1, '');
    try
    {
      return manager.pushReturn(FileSystem.exists(path) && FileSystem.isDirectory(path));
    }
    catch (e)
    {
      return manager.pushReturn(false);
    }
  }

  static function lua_readTextFile(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var path = readString(L, 1, '');
    if (!FileSystem.exists(path)) return manager.pushReturn(null);

    try
    {
      return manager.pushReturn(File.getContent(path));
    }
    catch (e)
    {
      trace('[LuaScriptManager] readTextFile failed: ${e}');
      return manager.pushReturn(null);
    }
  }

  static function lua_writeTextFile(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    try
    {
      File.saveContent(readString(L, 1, ''), readString(L, 2, ''));
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] writeTextFile failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_randomFloat(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.random.float(readFloat(L, 1, 0), readFloat(L, 2, 1))) ?? 0;
  }

  static function lua_randomInt(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.random.int(readInt(L, 1, 0), readInt(L, 2, 100))) ?? 0;
  }

  static function lua_keyPressed(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.keys.checkStatus(readKey(L, 1), FlxInputState.PRESSED)) ?? 0;
  }

  static function lua_keyJustPressed(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.keys.checkStatus(readKey(L, 1), FlxInputState.JUST_PRESSED)) ?? 0;
  }

  static function lua_keyJustReleased(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.keys.checkStatus(readKey(L, 1), FlxInputState.JUST_RELEASED)) ?? 0;
  }

  static function lua_mouseX(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.mouse.x) ?? 0;
  }

  static function lua_mouseY(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.mouse.y) ?? 0;
  }

  static function lua_mousePressed(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.mouse.pressed) ?? 0;
  }

  static function lua_mouseJustPressed(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.mouse.justPressed) ?? 0;
  }

  static function lua_mouseJustReleased(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.mouse.justReleased) ?? 0;
  }

  static function lua_getSongPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(Conductor.instance.songPosition) ?? 0;
  }

  static function lua_getBeat(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(Conductor.instance.currentBeat) ?? 0;
  }

  static function lua_getStep(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(Conductor.instance.currentStep) ?? 0;
  }

  static function lua_getSongName(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentSong?.songName ?? '') ?? 0;
  }

  static function lua_getDifficulty(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentDifficulty ?? '') ?? 0;
  }

  static function lua_getVariation(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentVariation ?? '') ?? 0;
  }

  static function lua_getStageId(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentStageId ?? '') ?? 0;
  }

  static function lua_getPlaybackRate(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.playbackRate ?? 1.0) ?? 0;
  }

  static function lua_setPlaybackRate(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.playbackRate = readFloat(L, 1, playState.playbackRate);
    return 0;
  }

  static function lua_getScrollSpeed(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState == null) return current()?.pushReturn(0.0) ?? 0;

    return switch (readString(L, 1, 'player'))
    {
      case 'opponent' | 'dad': current()?.pushReturn(playState.opponentStrumline?.scrollSpeed ?? 0.0) ?? 0;
      default: current()?.pushReturn(playState.playerStrumline?.scrollSpeed ?? 0.0) ?? 0;
    }
  }

  static function lua_setScrollSpeed(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState == null) return 0;

    var speed = readFloat(L, 1, 1);
    var target = readString(L, 2, 'both');
    if ((target == 'player' || target == 'both') && playState.playerStrumline != null) playState.playerStrumline.scrollSpeed = speed;
    if ((target == 'opponent' || target == 'dad' || target == 'both') && playState.opponentStrumline != null) playState.opponentStrumline.scrollSpeed = speed;
    return 0;
  }

  static function lua_getChartNotes(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentChart?.notes ?? []) ?? 0;
  }

  static function lua_getChartEvents(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.currentChart?.getEvents() ?? []) ?? 0;
  }

  static function lua_setStrumlinePosition(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var strumline = manager.resolveStrumline(readString(L, 1, 'player'));
    if (strumline == null) return manager.pushReturn(false);

    strumline.setPosition(readFloat(L, 2, strumline.x), readFloat(L, 3, strumline.y));
    strumline.refresh();
    return manager.pushReturn(true);
  }

  static function lua_setStrumlineAlpha(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var strumline = manager.resolveStrumline(readString(L, 1, 'player'));
    if (strumline == null) return manager.pushReturn(false);

    strumline.alpha = readFloat(L, 2, strumline.alpha);
    return manager.pushReturn(true);
  }

  static function lua_setStrumlineVisible(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var strumline = manager.resolveStrumline(readString(L, 1, 'player'));
    if (strumline == null) return manager.pushReturn(false);

    strumline.visible = readBool(L, 2, strumline.visible);
    return manager.pushReturn(true);
  }

  static function lua_setStrumlineNotePosition(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var strumline = manager.resolveStrumline(readString(L, 1, 'player'));
    if (strumline == null) return manager.pushReturn(false);

    var note = strumline.getByIndex(readInt(L, 2, 0));
    if (note == null) return manager.pushReturn(false);

    note.setPosition(readFloat(L, 3, note.x), readFloat(L, 4, note.y));
    return manager.pushReturn(true);
  }

  static function lua_playStrumlineAnimation(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var strumline = manager.resolveStrumline(readString(L, 1, 'player'));
    if (strumline == null) return manager.pushReturn(false);

    var direction:funkin.play.notes.NoteDirection = readInt(L, 2, 0);
    switch (readString(L, 3, 'static'))
    {
      case 'press': strumline.playPress(direction);
      case 'confirm': strumline.playConfirm(direction);
      case 'holdConfirm': strumline.holdConfirm(direction);
      case 'splash': strumline.playNoteSplash(direction);
      default: strumline.playStatic(direction);
    }
    return manager.pushReturn(true);
  }

  static function lua_setBotplay(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.isBotPlayMode = readBool(L, 1, playState.isBotPlayMode);
    return 0;
  }

  static function lua_setPracticeMode(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.isPracticeMode = readBool(L, 1, playState.isPracticeMode);
    return 0;
  }

  static function lua_getPreference(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    try
    {
      return manager.pushReturn(Reflect.getProperty(Preferences, readString(L, 1, '')));
    }
    catch (e)
    {
      trace('[LuaScriptManager] getPreference failed: ${e}');
      return manager.pushReturn(null);
    }
  }

  static function lua_setPreference(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    try
    {
      Reflect.setProperty(Preferences, readString(L, 1, ''), manager.readValue(L, 2));
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] setPreference failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_defineLuaOption(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.defineOption(readString(L, 1, ''), manager.readValue(L, 2)));
  }

  static function lua_getLuaOption(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.getOption(readString(L, 1, ''), manager.readValue(L, 2)));
  }

  static function lua_setLuaOption(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.setOption(readString(L, 1, ''), manager.readValue(L, 2), readBool(L, 3, true)));
  }

  static function lua_hasLuaOption(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.hasOption(readString(L, 1, '')));
  }

  static function lua_removeLuaOption(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.removeOption(readString(L, 1, ''), readBool(L, 2, true)));
  }

  static function lua_getLuaOptions(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.getOptions());
  }

  static function lua_createLuaOptionPage(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.createPage(readString(L, 1, ''), readString(L, 2, ''), readInt(L, 3, -1)));
  }

  static function lua_addLuaCheckbox(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.addCheckbox(readString(L, 1, ''), readString(L, 2, ''), readString(L, 3, ''),
      readString(L, 4, ''), readBool(L, 5, false)));
  }

  static function lua_addLuaNumber(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.addNumber(readString(L, 1, ''), readString(L, 2, ''), readString(L, 3, ''),
      readString(L, 4, ''), readFloat(L, 5, 0), readFloat(L, 6, 0), readFloat(L, 7, 1), readFloat(L, 8, 0.1), readInt(L, 9, 1)));
  }

  static function lua_addLuaEnum(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.optionManager.addEnum(readString(L, 1, ''), readString(L, 2, ''), readString(L, 3, ''),
      readString(L, 4, ''), manager.readValue(L, 5), readString(L, 6, '')));
  }

  static function lua_flushSave(L:cpp.RawPointer<Lua_State>):Int
  {
    Save.system.flush();
    return 0;
  }

  static function lua_getScreenWidth(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.width) ?? 0;
  }

  static function lua_getScreenHeight(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(FlxG.height) ?? 0;
  }

  static function lua_setFullscreen(L:cpp.RawPointer<Lua_State>):Int
  {
    FlxG.fullscreen = readBool(L, 1, FlxG.fullscreen);
    return 0;
  }

  static function lua_getHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.health ?? 0.0) ?? 0;
  }

  static function lua_setHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.health = readFloat(L, 1, playState.health);
    return 0;
  }

  static function lua_addHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.health += readFloat(L, 1, 0);
    return 0;
  }

  static function lua_getScore(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(PlayState.instance?.songScore ?? 0) ?? 0;
  }

  static function lua_setScore(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.songScore = readFloat(L, 1, playState.songScore);
    return 0;
  }

  static function lua_addScore(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.songScore += readFloat(L, 1, 0);
    return 0;
  }

  static function lua_getCombo(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(Highscore.tallies.combo) ?? 0;
  }

  static function lua_setCombo(L:cpp.RawPointer<Lua_State>):Int
  {
    Highscore.tallies.combo = readInt(L, 1, Highscore.tallies.combo);
    if (Highscore.tallies.combo > Highscore.tallies.maxCombo) Highscore.tallies.maxCombo = Highscore.tallies.combo;
    return 0;
  }

  static function lua_getAccuracy(L:cpp.RawPointer<Lua_State>):Int
  {
    if (Highscore.tallies.totalNotes <= 0) return current()?.pushReturn(0) ?? 0;
    return current()?.pushReturn((Highscore.tallies.totalNotesHit / Highscore.tallies.totalNotes) * 100) ?? 0;
  }

  static function lua_getTallies(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn({
      sick: Highscore.tallies.sick,
      good: Highscore.tallies.good,
      bad: Highscore.tallies.bad,
      shit: Highscore.tallies.shit,
      missed: Highscore.tallies.missed,
      combo: Highscore.tallies.combo,
      maxCombo: Highscore.tallies.maxCombo,
      totalNotesHit: Highscore.tallies.totalNotesHit,
      totalNotes: Highscore.tallies.totalNotes,
      score: PlayState.instance?.songScore ?? 0
    }) ?? 0;
  }

  static function lua_setVocalsVolume(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState == null) return 0;
    var playerVolume = readFloat(L, 1, playState.playerVocalsVolume);
    var opponentVolume = readFloat(L, 2, playState.opponentVocalsVolume);
    playState.playerVocalsVolume = playerVolume;
    playState.opponentVocalsVolume = opponentVolume;
    if (playState.vocals != null)
    {
      playState.vocals.playerVolume = playerVolume;
      playState.vocals.opponentVolume = opponentVolume;
    }
    return 0;
  }

  static function lua_startCountdown(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.startCountdown();
    return 0;
  }

  static function lua_startConversation(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState == null) return current()?.pushReturn(false) ?? 0;

    playState.startConversation(readString(L, 1, ''));
    return current()?.pushReturn(playState.currentConversation != null) ?? 0;
  }

  static function lua_playVideo(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
    #if FEATURE_VIDEO_PLAYBACK
      VideoCutscene.play(Paths.file(readString(L, 1, '')));
    #else
      VideoCutscene.play(readString(L, 1, ''));
    #end
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] playVideo failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_pauseVideo(L:cpp.RawPointer<Lua_State>):Int
  {
    VideoCutscene.pauseVideo();
    return 0;
  }

  static function lua_resumeVideo(L:cpp.RawPointer<Lua_State>):Int
  {
    VideoCutscene.resumeVideo();
    return 0;
  }

  static function lua_finishVideo(L:cpp.RawPointer<Lua_State>):Int
  {
    VideoCutscene.finishVideo(readFloat(L, 1, 0.5));
    return 0;
  }

  static function lua_isVideoPlaying(L:cpp.RawPointer<Lua_State>):Int
  {
    return current()?.pushReturn(VideoCutscene.isPlaying()) ?? 0;
  }

  static function lua_endSong(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.endSong(readBool(L, 1, false));
    return 0;
  }

  static function lua_restartSong(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null) playState.needsReset = true;
    return 0;
  }

  static function lua_addSprite(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    var asset = readString(L, 2, '');
    var x = readFloat(L, 3, 0);
    var y = readFloat(L, 4, 0);
    var camera = readString(L, 5, 'game');
    var zIndex = readInt(L, 6, 0);
    var animated = readBool(L, 7, false);

    if (tag == '' || asset == '') return manager.pushReturn(false);

    manager.removeSprite(tag);

    var sprite:Null<FunkinSprite> = null;
    try
    {
      sprite = animated ? FunkinSprite.createSparrow(x, y, asset) : FunkinSprite.create(x, y, asset);
    }
    catch (e)
    {
      trace('[LuaScriptManager] addSprite failed: ${e}');
      return manager.pushReturn(false);
    }
    if (sprite == null) return manager.pushReturn(false);
    sprite.zIndex = zIndex;
    manager.applyCamera(sprite, camera);
    manager.sprites.set(tag, sprite);
    playState.add(sprite);
    playState.refresh();

    return manager.pushReturn(true);
  }

  static function lua_addAnimatedSpriteAlias(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    var asset = readString(L, 2, '');
    if (tag == '' || asset == '') return manager.pushReturn(false);

    manager.removeSprite(tag);

    var sprite:Null<FunkinSprite> = null;
    try
    {
      sprite = FunkinSprite.createSparrow(readFloat(L, 3, 0), readFloat(L, 4, 0), asset);
    }
    catch (e)
    {
      trace('[LuaScriptManager] addAnimatedSprite failed: ${e}');
      return manager.pushReturn(false);
    }
    if (sprite == null) return manager.pushReturn(false);
    sprite.zIndex = readInt(L, 6, 0);
    manager.applyCamera(sprite, readString(L, 5, 'game'));
    manager.sprites.set(tag, sprite);
    playState.add(sprite);
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_loadGraphic(L:cpp.RawPointer<Lua_State>):Int
  {
    return createSpriteFromLua(L, false);
  }

  static function lua_loadSparrow(L:cpp.RawPointer<Lua_State>):Int
  {
    return createSpriteFromLua(L, true);
  }

  static function createSpriteFromLua(L:cpp.RawPointer<Lua_State>, animated:Bool):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    var asset = readString(L, 2, '');
    if (tag == '' || asset == '') return manager.pushReturn(false);

    manager.removeSprite(tag);
    var sprite:Null<FunkinSprite> = null;
    try
    {
      sprite = animated ? FunkinSprite.createSparrow(readFloat(L, 3, 0), readFloat(L, 4, 0), asset) : FunkinSprite.create(readFloat(L, 3, 0),
        readFloat(L, 4, 0), asset);
    }
    catch (e)
    {
      trace('[LuaScriptManager] createSprite failed: ${e}');
      return manager.pushReturn(false);
    }
    if (sprite == null) return manager.pushReturn(false);
    sprite.zIndex = readInt(L, 6, 0);
    manager.applyCamera(sprite, readString(L, 5, 'game'));
    manager.sprites.set(tag, sprite);
    playState.add(sprite);
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_makeSolidSprite(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    var x = readFloat(L, 2, 0);
    var y = readFloat(L, 3, 0);
    var width = readInt(L, 4, 100);
    var height = readInt(L, 5, 100);
    var color = readColor(L, 6, FlxColor.WHITE);
    var camera = readString(L, 7, 'game');
    var zIndex = readInt(L, 8, 0);

    if (tag == '') return manager.pushReturn(false);

    manager.removeSprite(tag);

    var sprite = new FunkinSprite(x, y);
    try
    {
      sprite.makeSolidColor(width, height, color);
    }
    catch (e)
    {
      trace('[LuaScriptManager] makeSolidSprite failed: ${e}');
      return manager.pushReturn(false);
    }
    sprite.zIndex = zIndex;
    manager.applyCamera(sprite, camera);
    manager.sprites.set(tag, sprite);
    playState.add(sprite);
    playState.refresh();

    return manager.pushReturn(true);
  }

  static function lua_makeGraphicAlias(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    if (tag == '') return manager.pushReturn(false);

    var sprite = manager.sprites.get(tag);
    if (sprite == null)
    {
      sprite = new FunkinSprite(0, 0);
      manager.sprites.set(tag, sprite);
      playState.add(sprite);
    }

    try
    {
      sprite.makeSolidColor(readInt(L, 2, 100), readInt(L, 3, 100), readColor(L, 4, FlxColor.WHITE));
    }
    catch (e)
    {
      trace('[LuaScriptManager] makeGraphic failed: ${e}');
      return manager.pushReturn(false);
    }
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_removeSprite(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.removeSprite(readString(L, 1, '')));
  }

  static function lua_setSpriteCamera(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var sprite = manager.sprites.get(readString(L, 1, ''));
    if (sprite == null) return manager.pushReturn(false);

    manager.applyCamera(sprite, readString(L, 2, 'game'));
    return manager.pushReturn(true);
  }

  static function lua_addText(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    if (tag == '') return manager.pushReturn(false);

    manager.removeText(tag);
    var text = new FlxText(readFloat(L, 2, 0), readFloat(L, 3, 0), readFloat(L, 4, 0), readString(L, 5, ''), readInt(L, 6, 16));
    text.color = readColor(L, 7, FlxColor.WHITE);
    text.zIndex = readInt(L, 8, 0);
    var camera = readString(L, 9, 'hud');
    var resolved = manager.resolveCamera(camera);
    if (resolved != null) text.cameras = [resolved];
    manager.texts.set(tag, text);
    playState.add(text);
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_makeLuaTextAlias(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    var playState = PlayState.instance;
    if (manager == null || playState == null) return 0;

    var tag = readString(L, 1, '');
    if (tag == '') return manager.pushReturn(false);

    manager.removeText(tag);
    var text = new FlxText(readFloat(L, 4, 0), readFloat(L, 5, 0), readFloat(L, 3, 0), readString(L, 2, ''), readInt(L, 6, 16));
    text.color = readColor(L, 7, FlxColor.WHITE);
    text.zIndex = readInt(L, 8, 0);
    var resolved = manager.resolveCamera(readString(L, 9, 'hud'));
    if (resolved != null) text.cameras = [resolved];
    manager.texts.set(tag, text);
    playState.add(text);
    playState.refresh();
    return manager.pushReturn(true);
  }

  static function lua_setText(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var text = manager.texts.get(readString(L, 1, ''));
    if (text == null) return manager.pushReturn(false);
    text.text = readString(L, 2, text.text);
    return manager.pushReturn(true);
  }

  static function lua_setTextFormat(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var text = manager.texts.get(readString(L, 1, ''));
    if (text == null) return manager.pushReturn(false);
    text.size = readInt(L, 2, text.size);
    text.color = readColor(L, 3, text.color);
    text.alignment = readTextAlign(L, 4, text.alignment);
    text.borderStyle = readBool(L, 5, false) ? FlxTextBorderStyle.OUTLINE : FlxTextBorderStyle.NONE;
    text.borderColor = readColor(L, 6, FlxColor.BLACK);
    return manager.pushReturn(true);
  }

  static function lua_removeText(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.removeText(readString(L, 1, '')));
  }

  static function lua_setObjectCamera(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var target = manager.resolvePath(readString(L, 1, '')).value;
    var camera = manager.resolveCamera(readString(L, 2, 'game'));
    if (target == null || camera == null) return manager.pushReturn(false);

    return manager.pushReturn(manager.safeSetProperty(target, 'cameras', [camera]));
  }

  static function lua_setObjectPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    var xOk = manager.safeSetProperty(target, 'x', readFloat(L, 2, manager.safeGetProperty(target, 'x') ?? 0));
    var yOk = manager.safeSetProperty(target, 'y', readFloat(L, 3, manager.safeGetProperty(target, 'y') ?? 0));
    return manager.pushReturn(xOk && yOk);
  }

  static function lua_getObjectX(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'x', 0);
  }

  static function lua_getObjectY(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'y', 0);
  }

  static function lua_getObjectWidth(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'width', 0);
  }

  static function lua_getObjectHeight(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'height', 0);
  }

  static function lua_getObjectAlpha(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'alpha', 1);
  }

  static function lua_getObjectVisible(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeGetProperty(target, 'visible') ?? false);
  }

  static function lua_getObjectAngle(L:cpp.RawPointer<Lua_State>):Int
  {
    return getSimpleObjectField(L, 'angle', 0);
  }

  static function lua_setObjectScale(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    var scale = target == null ? null : manager.safeField(target, 'scale');
    if (scale == null) return manager.pushReturn(false);
    var set = manager.safeField(scale, 'set');
    if (set == null) return manager.pushReturn(false);
    manager.safeCallMethod(scale, set, [readFloat(L, 2, manager.safeGetProperty(scale, 'x') ?? 0), readFloat(L, 3, manager.safeGetProperty(scale, 'y') ?? 0)]);
    var updateHitbox = manager.safeField(target, 'updateHitbox');
    if (updateHitbox != null) manager.safeCallMethod(target, updateHitbox, []);
    return manager.pushReturn(true);
  }

  static function lua_setObjectSize(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null || !Std.isOfType(target, FlxSprite)) return manager.pushReturn(false);

    try
    {
      cast(target, FlxSprite).setGraphicSize(readInt(L, 2, Std.int(target.width)), readInt(L, 3, Std.int(target.height)));
      target.updateHitbox();
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] setObjectSize failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_setObjectAlpha(L:cpp.RawPointer<Lua_State>):Int
  {
    return setSimpleObjectField(L, 'alpha', 2, 1);
  }

  static function lua_setObjectVisible(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeSetProperty(target, 'visible', readBool(L, 2, true)));
  }

  static function lua_setObjectAngle(L:cpp.RawPointer<Lua_State>):Int
  {
    return setSimpleObjectField(L, 'angle', 2, 0);
  }

  static function lua_setObjectColor(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeSetProperty(target, 'color', readColor(L, 2, FlxColor.WHITE)));
  }

  static function lua_setObjectVelocity(L:cpp.RawPointer<Lua_State>):Int
  {
    return setPointObjectField(L, 'velocity', 2, 3);
  }

  static function lua_setObjectAcceleration(L:cpp.RawPointer<Lua_State>):Int
  {
    return setPointObjectField(L, 'acceleration', 2, 3);
  }

  static function lua_setObjectScrollFactor(L:cpp.RawPointer<Lua_State>):Int
  {
    return setPointObjectField(L, 'scrollFactor', 2, 3);
  }

  static function lua_setObjectZIndex(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    if (!manager.safeSetProperty(target, 'zIndex', readInt(L, 2, manager.safeGetProperty(target, 'zIndex') ?? 0))) return manager.pushReturn(false);
    PlayState.instance?.refresh();
    return manager.pushReturn(true);
  }

  static function lua_screenCenter(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null || !Std.isOfType(target, FlxSprite)) return manager.pushReturn(false);
    cast(target, FlxSprite).screenCenter(readAxes(L, 2, FlxAxes.XY));
    return manager.pushReturn(true);
  }

  static function lua_objectExists(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.resolvePath(readString(L, 1, '')).value != null);
  }

  static function lua_killObject(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    var method = target == null ? null : manager.safeField(target, 'kill');
    if (method == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeCallMethod(target, method, []).ok);
  }

  static function lua_reviveObject(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    var method = target == null ? null : manager.safeField(target, 'revive');
    if (method == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeCallMethod(target, method, []).ok);
  }

  static function lua_addAnimByPrefix(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    var animation = target == null ? null : manager.safeField(target, 'animation');
    var addByPrefix = animation == null ? null : manager.safeField(animation, 'addByPrefix');
    if (addByPrefix == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeCallMethod(animation, addByPrefix,
      [readString(L, 2, ''), readString(L, 3, ''), readInt(L, 4, 24), readBool(L, 5, false)]).ok);
  }

  static function lua_playAnim(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var target = manager.resolvePath(readString(L, 1, '')).value;
    var anim = readString(L, 2, '');
    var force = readBool(L, 3, false);

    if (target == null || anim == '') return manager.pushReturn(false);

    if (Std.isOfType(target, FunkinSprite))
    {
      cast(target, FunkinSprite).animation.play(anim, force);
      return manager.pushReturn(true);
    }

    var method = manager.safeField(target, 'playAnimation') ?? manager.safeField(target, 'playAnim');
    if (method != null)
    {
      return manager.pushReturn(manager.safeCallMethod(target, method, [anim, force]).ok);
    }

    return manager.pushReturn(false);
  }

  static function lua_hasAnim(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var target = manager.resolvePath(readString(L, 1, '')).value;
    var anim = readString(L, 2, '');
    if (target == null || anim == '') return manager.pushReturn(false);

    if (Std.isOfType(target, FunkinSprite)) return manager.pushReturn(cast(target, FunkinSprite).hasAnimation(anim));

    var method = manager.safeField(target, 'hasAnimation');
    return manager.pushReturn(method != null && manager.safeCallMethod(target, method, [anim]).value == true);
  }

  static function lua_createLuaMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.createMenu(readString(L, 1, ''), readStringArray(L, 2), readFloat(L, 3, 80), readFloat(L, 4, 120),
      readFloat(L, 5, 600), readString(L, 6, 'hud'), readColor(L, 7, FlxColor.WHITE), readColor(L, 8, FlxColor.YELLOW)));
  }

  static function lua_createLuaImageMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.createImageMenu(readString(L, 1, ''), readStringArray(L, 2), readFloat(L, 3, 80),
      readFloat(L, 4, 120), readFloat(L, 5, 95), readString(L, 6, 'hud'), manager.readValue(L, 7)));
  }

  static function lua_addLuaMainMenuItem(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null || manager.mainMenuState == null) return manager?.pushReturn(false) ?? 0;

    var id = readString(L, 1, '');
    var assetPath = readString(L, 2, 'images:mainmenu/storymode');
    var position = readInt(L, 3, 999);
    var animName = readString(L, 4, id);
    var target = readString(L, 5, '');
    return manager.pushReturn(manager.mainMenuState.addLuaMenuItem(id, assetPath, position, animName, target, function()
    {
      manager.callHook('onLuaMainMenuAccept', [id]);
    }));
  }

  static function lua_configureLuaPauseMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.configureLuaPauseMenu(manager.readValue(L, 1)));
  }

  static function lua_setLuaPauseOptionsBehavior(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    funkin.ui.options.OptionsState.prepareLuaPauseReturn({exitTarget: readString(L, 1, 'resume'), hideExit: readBool(L, 2, false)});
    return manager.pushReturn(true);
  }
  static function lua_setLuaPauseMenuItem(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.setLuaPauseMenuItem(readString(L, 1, ''), readString(L, 2, ''), readInt(L, 3, 999), readString(L, 4, ''), readBool(L, 5, false)));
  }

  static function lua_setLuaMenuItems(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.setItems(readString(L, 1, ''), readStringArray(L, 2)));
  }

  static function lua_setLuaMenuPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.setPosition(readString(L, 1, ''), readFloat(L, 2, 80), readFloat(L, 3, 120), readFloat(L, 4, 34)));
  }

  static function lua_showLuaMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.showMenu(readString(L, 1, '')));
  }

  static function lua_hideLuaMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.hideMenu(readString(L, 1, '')));
  }

  static function lua_removeLuaMenu(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.removeMenu(readString(L, 1, '')));
  }

  static function lua_getLuaMenuSelected(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.menusManager.getSelected(readString(L, 1, '')));
  }

  static function lua_createShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.createShader(readString(L, 1, ''), readString(L, 2, ''), readString(L, 3, '')));
  }

  static function lua_destroyShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.destroyShader(readString(L, 1, '')));
  }

  static function lua_setShaderFloat(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.setFloat(readString(L, 1, ''), readString(L, 2, ''), readFloat(L, 3, 0)));
  }

  static function lua_setShaderFloatArray(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.setFloatArray(readString(L, 1, ''), readString(L, 2, ''), readFloatArray(L, 3)));
  }

  static function lua_setShaderInt(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.setInt(readString(L, 1, ''), readString(L, 2, ''), readInt(L, 3, 0)));
  }

  static function lua_setShaderBool(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.setBool(readString(L, 1, ''), readString(L, 2, ''), readBool(L, 3, false)));
  }

  static function lua_applyShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.applyToTarget(readString(L, 1, ''), manager.resolvePath(readString(L, 2, '')).value));
  }

  static function lua_clearShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.clearTarget(manager.resolvePath(readString(L, 1, '')).value));
  }

  static function lua_applyCameraShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.applyToCamera(readString(L, 1, ''), manager.resolveCamera(readString(L, 2, 'game'))));
  }

  static function lua_clearCameraShader(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.shaderManager.clearCamera(manager.resolveCamera(readString(L, 1, 'game'))));
  }

  static function lua_tween(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var target = manager.resolvePath(readString(L, 2, '')).value;
    var values = manager.readValue(L, 3);
    var duration = readFloat(L, 4, 1);
    var easeName = readString(L, 5, 'linear');

    if (tag == '' || target == null || values == null) return manager.pushReturn(false);

    manager.cancelTween(tag);
    try
    {
      var tween = FlxTween.tween(target, values, duration,
        {
          ease: resolveEase(easeName),
          onComplete: function(_)
          {
            manager.tweens.remove(tag);
            manager.callHook('onTweenCompleted', [tag]);
          }
        });
      manager.tweens.set(tag, tween);
    }
    catch (e)
    {
      trace('[LuaScriptManager] tween failed: ${e}');
      return manager.pushReturn(false);
    }

    return manager.pushReturn(true);
  }

  static function lua_tweenObjectX(L:cpp.RawPointer<Lua_State>):Int
  {
    return tweenObjectField(L, 'x');
  }

  static function lua_tweenObjectY(L:cpp.RawPointer<Lua_State>):Int
  {
    return tweenObjectField(L, 'y');
  }

  static function lua_tweenObjectAlpha(L:cpp.RawPointer<Lua_State>):Int
  {
    return tweenObjectField(L, 'alpha');
  }

  static function lua_tweenObjectAngle(L:cpp.RawPointer<Lua_State>):Int
  {
    return tweenObjectField(L, 'angle');
  }

  static function tweenObjectField(L:cpp.RawPointer<Lua_State>, field:String):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var target = manager.resolvePath(readString(L, 2, '')).value;
    var values:Dynamic = {};
    Reflect.setField(values, field, readFloat(L, 3, 0));
    var duration = readFloat(L, 4, 1);
    var easeName = readString(L, 5, 'linear');

    if (tag == '' || target == null) return manager.pushReturn(false);

    manager.cancelTween(tag);
    try
    {
      var tween = FlxTween.tween(target, values, duration,
        {
          ease: resolveEase(easeName),
          onComplete: function(_)
          {
            manager.tweens.remove(tag);
            manager.callHook('onTweenCompleted', [tag]);
          }
        });
      manager.tweens.set(tag, tween);
    }
    catch (e)
    {
      trace('[LuaScriptManager] tweenObject failed: ${e}');
      return manager.pushReturn(false);
    }

    return manager.pushReturn(true);
  }

  static function lua_cancelTween(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.cancelTween(readString(L, 1, '')));
  }

  static function lua_runTimer(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var delay = readFloat(L, 2, 1);
    var loops = readInt(L, 3, 1);
    if (tag == '') return manager.pushReturn(false);

    manager.cancelTimer(tag);
    var timer = new FlxTimer().start(delay, function(tmr)
    {
      manager.callHook('onTimerCompleted', [tag, tmr.loopsLeft]);
      if (tmr.loopsLeft <= 0) manager.timers.remove(tag);
    }, loops);
    manager.timers.set(tag, timer);
    return manager.pushReturn(true);
  }

  static function lua_cancelTimer(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.cancelTimer(readString(L, 1, '')));
  }

  static function lua_playSound(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var tag = readString(L, 1, '');
    var key = readString(L, 2, '');
    var volume = readFloat(L, 3, 1);
    var looped = readBool(L, 4, false);
    if (tag == '' || key == '') return manager.pushReturn(false);

    manager.stopSound(tag);
    try
    {
      var sound = FlxG.sound.play(Paths.sound(key), volume, looped);
      manager.sounds.set(tag, sound);
    }
    catch (e)
    {
      trace('[LuaScriptManager] playSound failed: ${e}');
      return manager.pushReturn(false);
    }
    return manager.pushReturn(true);
  }

  static function lua_stopSound(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.stopSound(readString(L, 1, '')));
  }

  static function lua_pauseSound(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var sound = manager.sounds.get(readString(L, 1, ''));
    if (sound == null) return manager.pushReturn(false);
    sound.pause();
    return manager.pushReturn(true);
  }

  static function lua_resumeSound(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var sound = manager.sounds.get(readString(L, 1, ''));
    if (sound == null) return manager.pushReturn(false);
    sound.resume();
    return manager.pushReturn(true);
  }

  static function lua_setSoundVolume(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var sound = manager.sounds.get(readString(L, 1, ''));
    if (sound == null) return manager.pushReturn(false);
    sound.volume = readFloat(L, 2, sound.volume);
    return manager.pushReturn(true);
  }

  static function lua_soundExists(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    return manager.pushReturn(manager.sounds.exists(readString(L, 1, '')));
  }

  static function lua_playMusic(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      FlxG.sound.playMusic(Paths.music(readString(L, 1, '')), readFloat(L, 2, 1), readBool(L, 3, true));
      return manager.pushReturn(true);
    }
    catch (e)
    {
      trace('[LuaScriptManager] playMusic failed: ${e}');
      return manager.pushReturn(false);
    }
  }

  static function lua_stopMusic(L:cpp.RawPointer<Lua_State>):Int
  {
    FlxG.sound.music?.stop();
    return 0;
  }

  static function lua_pauseMusic(L:cpp.RawPointer<Lua_State>):Int
  {
    FlxG.sound.music?.pause();
    return 0;
  }

  static function lua_resumeMusic(L:cpp.RawPointer<Lua_State>):Int
  {
    FlxG.sound.music?.resume();
    return 0;
  }

  static function lua_setMusicVolume(L:cpp.RawPointer<Lua_State>):Int
  {
    if (FlxG.sound.music != null) FlxG.sound.music.volume = readFloat(L, 1, FlxG.sound.music.volume);
    return 0;
  }

  static function lua_cameraFlash(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    manager.resolveCamera(readString(L, 1, 'game'))?.flash(readColor(L, 2, FlxColor.WHITE), readFloat(L, 3, 1));
    return 0;
  }

  static function lua_cameraFade(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    manager.resolveCamera(readString(L, 1, 'game'))?.fade(readColor(L, 2, FlxColor.BLACK), readFloat(L, 3, 1), readBool(L, 4, false));
    return 0;
  }

  static function lua_cameraShake(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    manager.resolveCamera(readString(L, 1, 'game'))?.shake(readFloat(L, 2, 0.01), readFloat(L, 3, 0.5));
    return 0;
  }

  static function lua_setCameraZoom(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var camera = manager.resolveCamera(readString(L, 1, 'game'));
    if (camera != null) camera.zoom = readFloat(L, 2, camera.zoom);
    return 0;
  }

  static function lua_setCameraAlpha(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var camera = manager.resolveCamera(readString(L, 1, 'game'));
    if (camera != null) camera.alpha = readFloat(L, 2, camera.alpha);
    return 0;
  }

  static function lua_setCameraBgColor(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var camera = manager.resolveCamera(readString(L, 1, 'game'));
    if (camera != null) camera.bgColor = readColor(L, 2, camera.bgColor);
    return 0;
  }

  static function lua_setCameraVisible(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var camera = manager.resolveCamera(readString(L, 1, 'game'));
    if (camera != null) camera.visible = readBool(L, 2, camera.visible);
    return 0;
  }

  static function lua_setCameraPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var camera = manager.resolveCamera(readString(L, 1, 'game'));
    if (camera != null) camera.setPosition(readFloat(L, 2, camera.x), readFloat(L, 3, camera.y));
    return 0;
  }

  static function lua_setCameraFollow(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null && playState.cameraFollowPoint != null)
    {
      playState.cameraFollowPoint.setPosition(readFloat(L, 1, playState.cameraFollowPoint.x), readFloat(L, 2, playState.cameraFollowPoint.y));
    }
    return 0;
  }

  static function lua_setCameraBop(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null)
    {
      playState.cameraBopIntensity = readFloat(L, 1, playState.cameraBopIntensity);
      playState.cameraBopMultiplier = readFloat(L, 2, playState.cameraBopMultiplier);
      playState.hudCameraZoomIntensity = readFloat(L, 3, playState.hudCameraZoomIntensity);
    }
    return 0;
  }

  static function lua_setHealthBarColors(L:cpp.RawPointer<Lua_State>):Int
  {
    var playState = PlayState.instance;
    if (playState != null && playState.healthBar != null)
    {
      playState.healthBar.createFilledBar(readColor(L, 1, FlxColor.RED), readColor(L, 2, FlxColor.LIME));
      playState.healthBar.updateBar();
    }
    return 0;
  }

  static function lua_resetCamera(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.resetCamera(readBool(L, 1, true), readBool(L, 2, true), readBool(L, 3, true));
    return 0;
  }

  static function lua_tweenCameraZoom(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.tweenCameraZoom(readFloat(L, 1, 1), readFloat(L, 2, 0), readBool(L, 3, false), resolveEase(readString(L, 4, 'linear')));
    return 0;
  }

  static function lua_tweenCameraToPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.tweenCameraToPosition(readFloat(L, 1, 0), readFloat(L, 2, 0), readFloat(L, 3, 0), resolveEase(readString(L, 4, 'linear')));
    return 0;
  }

  static function lua_cancelCameraTweens(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.cancelAllCameraTweens();
    return 0;
  }

  static function lua_tweenScrollSpeed(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.tweenScrollSpeed(readFloat(L, 1, 1), readFloat(L, 2, 0), resolveEase(readString(L, 3, 'linear')), [readString(L, 4, 'player'), readString(L, 5, 'opponent')]);
    return 0;
  }

  static function lua_cancelScrollSpeedTweens(L:cpp.RawPointer<Lua_State>):Int
  {
    PlayState.instance?.cancelScrollSpeedTweens();
    return 0;
  }

  static function lua_pathImage(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.image(readString(L, 1, ''), readString(L, 2, null)));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function lua_pathSound(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.sound(readString(L, 1, ''), readString(L, 2, null)));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function lua_pathMusic(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.music(readString(L, 1, ''), readString(L, 2, null)));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function lua_pathFont(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.font(readString(L, 1, '')));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function lua_pathFile(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.file(readString(L, 1, '')));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function lua_pathJson(L:cpp.RawPointer<Lua_State>):Int
  {
    var manager = current();
    if (manager == null) return 0;
    try
    {
      return manager.pushReturn(Paths.json(readString(L, 1, ''), readString(L, 2, null)));
    }
    catch (e)
    {
      return manager.pushReturn(null);
    }
  }

  static function setSimpleObjectField(L:cpp.RawPointer<Lua_State>, field:String, valueIndex:Int, fallback:Float):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(false);
    return manager.pushReturn(manager.safeSetProperty(target, field, readFloat(L, valueIndex, fallback)));
  }

  static function getSimpleObjectField(L:cpp.RawPointer<Lua_State>, field:String, fallback:Float):Int
  {
    var manager = current();
    if (manager == null) return 0;
    var target = manager.resolvePath(readString(L, 1, '')).value;
    if (target == null) return manager.pushReturn(fallback);
    return manager.pushReturn(manager.safeGetProperty(target, field) ?? fallback);
  }

  static function setPointObjectField(L:cpp.RawPointer<Lua_State>, field:String, xIndex:Int, yIndex:Int):Int
  {
    var manager = current();
    if (manager == null) return 0;

    var target = manager.resolvePath(readString(L, 1, '')).value;
    var point = target == null ? null : manager.safeGetProperty(target, field);
    var set = point == null ? null : manager.safeField(point, 'set');
    if (set == null) return manager.pushReturn(false);

    return manager.pushReturn(manager.safeCallMethod(point, set,
      [readFloat(L, xIndex, manager.safeGetProperty(point, 'x') ?? 0), readFloat(L, yIndex, manager.safeGetProperty(point, 'y') ?? 0)]).ok);
  }

  function removeSprite(tag:String):Bool
  {
    var sprite = sprites.get(tag);
    if (sprite == null) return false;

    PlayState.instance?.remove(sprite, true);
    sprite.destroy();
    sprites.remove(tag);
    return true;
  }

  function removeText(tag:String):Bool
  {
    var text = texts.get(tag);
    if (text == null) return false;

    PlayState.instance?.remove(text, true);
    text.destroy();
    texts.remove(tag);
    return true;
  }

  function cancelTween(tag:String):Bool
  {
    var tween = tweens.get(tag);
    if (tween == null) return false;
    tween.cancel();
    tweens.remove(tag);
    return true;
  }

  function cancelTimer(tag:String):Bool
  {
    var timer = timers.get(tag);
    if (timer == null) return false;
    timer.cancel();
    timers.remove(tag);
    return true;
  }

  function stopSound(tag:String):Bool
  {
    var sound = sounds.get(tag);
    if (sound == null) return false;
    sound.stop();
    sound.destroy();
    sounds.remove(tag);
    return true;
  }

  function applyCamera(sprite:FlxSprite, camera:String):Void
  {
    var resolved = resolveCamera(camera);
    if (resolved != null) sprite.cameras = [resolved];
  }

  function resolveCamera(camera:String):Null<flixel.FlxCamera>
  {
    var playState = PlayState.instance;
    if (playState == null) return FlxG.camera;

    return switch (camera)
    {
      case 'hud' | 'camHUD': playState.camHUD;
      case 'cutscene' | 'camCutscene': playState.camCutscene;
      case 'game' | 'camGame': playState.camGame;
      default: FlxG.camera;
    }
  }

  function resolveStrumline(target:String):Null<funkin.play.notes.Strumline>
  {
    var playState = PlayState.instance;
    if (playState == null) return null;

    return switch (target)
    {
      case 'opponent' | 'dad' | 'p2' | 'enemy': playState.opponentStrumline;
      default: playState.playerStrumline;
    }
  }

  function safeField(target:Dynamic, field:String):Dynamic
  {
    try
    {
      return Reflect.field(target, field);
    }
    catch (e)
    {
      return null;
    }
  }

  function safeGetProperty(target:Dynamic, field:String):Dynamic
  {
    try
    {
      return Reflect.getProperty(target, field);
    }
    catch (e)
    {
      return null;
    }
  }

  function safeSetProperty(target:Dynamic, field:String, value:Dynamic, report:Bool = true):Bool
  {
    try
    {
      Reflect.setProperty(target, field, value);
      return true;
    }
    catch (e)
    {
      if (report) reportLuaWarning('api-error', 'lua-api', 'setProperty', 'setProperty failed for ${field}: ${e}');
      return false;
    }
  }

  function safeCallMethod(target:Dynamic, method:Dynamic, args:Array<Dynamic>):{ok:Bool, value:Dynamic}
  {
    try
    {
      return {ok: true, value: Reflect.callMethod(target, method, args)};
    }
    catch (e)
    {
      reportLuaWarning('api-error', 'lua-api', 'callMethod', 'callMethod failed: ${e}');
      return {ok: false, value: null};
    }
  }

  function resolvePath(path:String):{target:Dynamic, field:String, value:Dynamic}
  {
    if (path == '') return {target: null, field: '', value: null};

    var parts = path.split('.');
    var value:Dynamic = resolveRoot(parts.shift());

    for (part in parts)
    {
      if (value == null) return {target: null, field: part, value: null};
      value = resolvePart(value, part);
    }

    return {target: null, field: '', value: value};
  }

  function resolveEventPath(path:String):{target:Dynamic, field:String, value:Dynamic}
  {
    if (currentEvent == null) return {target: null, field: '', value: null};
    if (path == '') return {target: null, field: '', value: currentEvent};

    var parts = path.split('.');
    var value:Dynamic = currentEvent;

    for (part in parts)
    {
      if (value == null) return {target: null, field: part, value: null};
      value = resolvePart(value, part);
    }

    return {target: null, field: '', value: value};
  }

  function resolveParent(path:String):{target:Dynamic, field:String}
  {
    var parts = path.split('.');
    if (parts.length == 0) return {target: null, field: ''};

    var field = parts.pop();
    var target:Dynamic = resolveRoot(parts.shift());

    for (part in parts)
    {
      if (target == null) return {target: null, field: field};
      target = resolvePart(target, part);
    }

    return {target: target, field: field};
  }

  function resolveEventParent(path:String):{target:Dynamic, field:String}
  {
    if (currentEvent == null) return {target: null, field: ''};

    var parts = path.split('.');
    if (parts.length == 0) return {target: null, field: ''};

    var field = parts.pop();
    var target:Dynamic = currentEvent;

    for (part in parts)
    {
      if (target == null) return {target: null, field: field};
      target = resolvePart(target, part);
    }

    return {target: target, field: field};
  }

  function resolveRoot(root:Null<String>):Dynamic
  {
    var playState = PlayState.instance;

    return switch (root)
    {
      case null | '' | 'playState' | 'state': playState;
      case 'FlxG': FlxG;
      case 'sound' | 'FlxG.sound': FlxG.sound;
      case 'music' | 'FlxG.sound.music': FlxG.sound.music;
      case 'Conductor': Conductor.instance;
      case 'Highscore' | 'tallies': Highscore.tallies;
      case 'camGame': playState?.camGame;
      case 'camHUD': playState?.camHUD;
      case 'camCutscene': playState?.camCutscene;
      case 'currentStage' | 'stage': playState?.currentStage;
      case 'currentSong' | 'song': playState?.currentSong;
      case 'currentChart' | 'chart': playState?.currentChart;
      case 'currentConversation' | 'conversation': playState?.currentConversation;
      case 'vocals': playState?.vocals;
      case 'scoreText': playState == null ? null : safeField(playState, 'scoreText');
      case 'healthBar': playState?.healthBar;
      case 'healthBarBG': playState?.healthBarBG;
      case 'iconP1' | 'playerIcon': playState?.iconP1;
      case 'iconP2' | 'opponentIcon': playState?.iconP2;
      case 'comboPopUps' | 'comboPopups': playState?.comboPopUps;
      case 'cameraFollowPoint' | 'cameraTarget': playState?.cameraFollowPoint;
      case 'boyfriend' | 'bf': playState?.currentStage?.getBoyfriend();
      case 'dad' | 'opponent': playState?.currentStage?.getDad();
      case 'girlfriend' | 'gf': playState?.currentStage?.getGirlfriend();
      case 'playerStrumline': playState?.playerStrumline;
      case 'opponentStrumline': playState?.opponentStrumline;
      default:
        var sprite = sprites.get(root);
        if (sprite != null) sprite;
        else
        {
          var text = texts.get(root);
          if (text != null) text else objects.get(root);
        }
    }
  }

  function resolvePart(target:Dynamic, part:String):Dynamic
  {
    if (target == null) return null;

    var bracketIndex = part.indexOf('[');
    if (bracketIndex > -1 && StringTools.endsWith(part, ']'))
    {
      var field = part.substr(0, bracketIndex);
      var index = Std.parseInt(part.substring(bracketIndex + 1, part.length - 1));
      var value:Dynamic = field == '' ? target : safeGetProperty(target, field);
      if (index == null || value == null) return null;

      if (Std.isOfType(value, Array))
      {
        var array:Array<Dynamic> = cast value;
        return array[index];
      }

      return safeGetProperty(value, Std.string(index));
    }

    return safeGetProperty(target, part);
  }

  function readValue(L:cpp.RawPointer<Lua_State>, index:Int):Dynamic
  {
    var luaType = Lua.type(L, index);

    if (luaType == Lua.TNIL || luaType == Lua.TNONE) return null;
    if (luaType == Lua.TBOOLEAN) return Lua.toboolean(L, index) != 0;
    if (luaType == Lua.TNUMBER) return Lua.tonumber(L, index);
    if (luaType == Lua.TSTRING) return Std.string(Lua.tostring(L, index));
    if (luaType == Lua.TTABLE) return readTable(L, index);

    return Std.string(Lua.tostring(L, index));
  }

  function readArgs(L:cpp.RawPointer<Lua_State>, startIndex:Int):Array<Dynamic>
  {
    var args:Array<Dynamic> = [];
    var top = Lua.gettop(L);
    for (i in startIndex...(top + 1)) args.push(readValue(L, i));
    return args;
  }

  function readTable(L:cpp.RawPointer<Lua_State>, index:Int):Dynamic
  {
    var absoluteIndex = Lua.absindex(L, index);
    var result:Dynamic = {};
    var arrayValues:Map<Int, Dynamic> = new Map<Int, Dynamic>();
    var hasArrayValues = false;
    var hasObjectValues = false;
    var maxArrayIndex = 0;

    Lua.pushnil(L);
    while (Lua.next(L, absoluteIndex) != 0)
    {
      var key = readTableKey(L, -2);
      var value = readValue(L, -1);
      if (Std.isOfType(key, Float))
      {
        var numericKey:Float = cast key;
        var arrayIndex = Std.int(numericKey);
        if (numericKey != arrayIndex)
        {
          Reflect.setField(result, Std.string(key), value);
          hasObjectValues = true;
        }
        else
        if (arrayIndex > 0)
        {
          arrayValues.set(arrayIndex, value);
          if (arrayIndex > maxArrayIndex) maxArrayIndex = arrayIndex;
          hasArrayValues = true;
        }
        else
        {
          Reflect.setField(result, Std.string(key), value);
          hasObjectValues = true;
        }
      }
      else
      {
        Reflect.setField(result, Std.string(key), value);
        hasObjectValues = true;
      }
      Lua.pop(L, 1);
    }

    if (hasArrayValues && hasObjectValues)
    {
      for (i in arrayValues.keys()) Reflect.setField(result, Std.string(i), arrayValues.get(i));
      return result;
    }

    if (hasArrayValues)
    {
      var array:Array<Dynamic> = [];
      for (i in 1...(maxArrayIndex + 1)) array.push(arrayValues.exists(i) ? arrayValues.get(i) : null);
      return array;
    }

    return result;
  }

  function readTableKey(L:cpp.RawPointer<Lua_State>, index:Int):Dynamic
  {
    var luaType = Lua.type(L, index);
    if (luaType == Lua.TSTRING) return Std.string(Lua.tostring(L, index));
    if (luaType == Lua.TNUMBER) return Lua.tonumber(L, index);
    if (luaType == Lua.TBOOLEAN) return Lua.toboolean(L, index) != 0;
    return Std.string(luaType);
  }

  static function readString(L:cpp.RawPointer<Lua_State>, index:Int, fallback:String):String
  {
    if (Lua.gettop(L) < index || Lua.type(L, index) == Lua.TNIL) return fallback;
    return Std.string(Lua.tostring(L, index));
  }

  static function readStringArray(L:cpp.RawPointer<Lua_State>, index:Int):Array<String>
  {
    var values:Array<String> = [];
    if (Lua.gettop(L) < index || Lua.type(L, index) == Lua.TNIL) return values;
    if (Lua.type(L, index) != Lua.TTABLE)
    {
      var raw = readString(L, index, '');
      return raw == '' ? values : raw.split('|');
    }

    var absoluteIndex = Lua.absindex(L, index);
    var i = 1;
    while (true)
    {
      Lua.rawgeti(L, absoluteIndex, i);
      if (Lua.type(L, -1) == Lua.TNIL)
      {
        Lua.pop(L, 1);
        break;
      }
      values.push(readString(L, -1, ''));
      Lua.pop(L, 1);
      i++;
    }
    return values;
  }

  static function readFloatArray(L:cpp.RawPointer<Lua_State>, index:Int):Array<Float>
  {
    var values:Array<Float> = [];
    if (Lua.gettop(L) < index || Lua.type(L, index) == Lua.TNIL) return values;
    if (Lua.type(L, index) != Lua.TTABLE)
    {
      values.push(readFloat(L, index, 0));
      return values;
    }

    var absoluteIndex = Lua.absindex(L, index);
    var i = 1;
    while (true)
    {
      Lua.rawgeti(L, absoluteIndex, i);
      if (Lua.type(L, -1) == Lua.TNIL)
      {
        Lua.pop(L, 1);
        break;
      }
      values.push(readFloat(L, -1, 0));
      Lua.pop(L, 1);
      i++;
    }
    return values;
  }

  static function readFloat(L:cpp.RawPointer<Lua_State>, index:Int, fallback:Float):Float
  {
    if (Lua.gettop(L) < index || Lua.type(L, index) != Lua.TNUMBER) return fallback;
    return Lua.tonumber(L, index);
  }

  static function readInt(L:cpp.RawPointer<Lua_State>, index:Int, fallback:Int):Int
  {
    if (Lua.gettop(L) < index || Lua.type(L, index) != Lua.TNUMBER) return fallback;
    return Std.int(Lua.tonumber(L, index));
  }

  static function readBool(L:cpp.RawPointer<Lua_State>, index:Int, fallback:Bool):Bool
  {
    if (Lua.gettop(L) < index || Lua.type(L, index) == Lua.TNIL) return fallback;
    return Lua.toboolean(L, index) != 0;
  }

  static function readKey(L:cpp.RawPointer<Lua_State>, index:Int):FlxKey
  {
    return FlxKey.fromString(readString(L, index, '').toUpperCase());
  }

  static function readColor(L:cpp.RawPointer<Lua_State>, index:Int, fallback:FlxColor):FlxColor
  {
    if (Lua.gettop(L) < index || Lua.type(L, index) == Lua.TNIL) return fallback;

    var luaType = Lua.type(L, index);
    if (luaType == Lua.TNUMBER) return FlxColor.fromInt(readInt(L, index, fallback));
    if (luaType == Lua.TSTRING) return FlxColor.fromString(readString(L, index, Std.string(fallback))) ?? fallback;

    return fallback;
  }

  static function readTextAlign(L:cpp.RawPointer<Lua_State>, index:Int, fallback:FlxTextAlign):FlxTextAlign
  {
    return switch (readString(L, index, '').toLowerCase())
    {
      case 'left': FlxTextAlign.LEFT;
      case 'center': FlxTextAlign.CENTER;
      case 'right': FlxTextAlign.RIGHT;
      case 'justify': FlxTextAlign.JUSTIFY;
      default: fallback;
    }
  }

  static function readAxes(L:cpp.RawPointer<Lua_State>, index:Int, fallback:FlxAxes):FlxAxes
  {
    return switch (readString(L, index, '').toLowerCase())
    {
      case 'x': FlxAxes.X;
      case 'y': FlxAxes.Y;
      case 'xy' | 'both': FlxAxes.XY;
      default: fallback;
    }
  }

  static function resolveEase(name:String):EaseFunction
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
    }
  }
  #end
}





