package funkin.ui.options;

import funkin.ui.Page.PageName;
import funkin.ui.transition.LoadingState;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.math.FlxPoint;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.graphics.shaders.HSVShader;
import funkin.input.Controls;
#if FEATURE_LUA_SCRIPTS
import funkin.scripting.LuaScriptManager;
#end
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
#if mobile
import funkin.util.TouchUtil;
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.ui.options.ControlsSchemeMenu;
#end
#if FEATURE_MOBILE_IAP
import funkin.mobile.util.InAppPurchasesUtil;
#end
import flixel.util.FlxColor;

/**
 * The main options menu
 * It mainly is controlled via the "optionsCodex" object,
 * which handles paging and going to the different submenus
 */
class OptionsState extends MusicBeatState
{
  /**
   * Instance of the OptionsState
   */
  public static var instance:OptionsState;

  static var luaPauseExitTarget:Null<String>;
  static var luaPauseHideExit:Bool = false;

  var optionsCodex:Codex<OptionsMenuPageName>;
  var luaPauseExitTargetForThisState:Null<String>;
  #if FEATURE_LUA_SCRIPTS
  var luaOptionsScriptManager:Null<LuaScriptManager>;
  #end

  public var drumsBG:FunkinSound;

  public static var rememberedSelectedIndex:Int = 0;

  override function create():Void
  {
    instance = this;

    persistentUpdate = true;

    drumsBG = FunkinSound.load(Paths.music('offsetsLoop/drumsLoop'), 0, true, false, false, false);

    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    var hsv = new HSVShader(-0.6, 0.9, 3.6);
    menuBG.shader = hsv;
    menuBG.setGraphicSize(Std.int(FlxG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    optionsCodex = new Codex<OptionsMenuPageName>(Options);
    add(optionsCodex);

    var options:OptionsMenu = optionsCodex.addPage(Options, new OptionsMenu());
    var preferences:PreferencesMenu = optionsCodex.addPage(Preferences, new PreferencesMenu());
    var controls:ControlsMenu = optionsCodex.addPage(Controls, new ControlsMenu());
    #if FEATURE_LAG_ADJUSTMENT
    var offsets:OffsetMenu = optionsCodex.addPage(Offsets, new OffsetMenu());
    #end
    var saveData:SaveDataMenu = optionsCodex.addPage(SaveData, new SaveDataMenu());

    luaPauseExitTargetForThisState = luaPauseExitTarget;
    var hideExitForThisState = luaPauseHideExit;
    clearLuaPauseReturn();

    options.addSaveDataOptionsItem(saveData);
    options.addExitItem();
    if (hideExitForThisState) options.removeLuaOptionsItem("EXIT");

    if (options.hasMultipleOptions())
    {
      options.onExit.add(luaPauseExitTargetForThisState == null ? exitToMainMenu : exitFromLuaPause);
      controls.onExit.add(exitControls);
      preferences.onExit.add(optionsCodex.switchPage.bind(Options));
      #if FEATURE_LAG_ADJUSTMENT
      offsets.onExit.add(exitOffsets);
      #end
      saveData.onExit.add(optionsCodex.switchPage.bind(Options));
    }
    else
    {
      // No need to show Options page
      #if mobile
      preferences.onExit.add(luaPauseExitTargetForThisState == null ? exitToMainMenu : exitFromLuaPause);
      optionsCodex.setPage(Preferences);
      #else
      controls.onExit.add(luaPauseExitTargetForThisState == null ? exitToMainMenu : exitFromLuaPause);
      optionsCodex.setPage(Controls);
      #end
    }

    super.create();
    #if FEATURE_LUA_SCRIPTS
    luaOptionsScriptManager = LuaScriptManager.loadOptionsScriptsForState(this);
    #end
    #if mobile
    addHitbox();
    hitbox.visible = false;
    #end
  }

  override function destroy():Void
  {
    #if FEATURE_LUA_SCRIPTS
    luaOptionsScriptManager?.destroy();
    luaOptionsScriptManager = null;
    #end
    super.destroy();
  }

  function exitOffsets():Void
  {
    if (drumsBG.volume > 0)
    {
      drumsBG.fadeOut(0.5, 0);
    }
    FlxG.sound.music.fadeOut(0.5, 0, function(tw)
    {
      FunkinSound.playMusic('freakyMenu', {
        startingVolume: 0,
        overrideExisting: true,
        restartTrack: true,
        persist: true
      });
      FlxG.sound.music.fadeIn(0.5, 1);
    });
    optionsCodex.switchPage(Options);
  }

  function exitControls():Void
  {
    // Apply any changes to the controls.
    PlayerSettings.reset();
    PlayerSettings.init();

    optionsCodex.switchPage(Options);
  }

  function exitToMainMenu()
  {
    optionsCodex.currentPage.enabled = false;
    // TODO: Animate this transition?
    FlxG.keys.enabled = false;
    FlxG.switchState(() -> new MainMenuState());
  }

  function exitFromLuaPause():Void
  {
    optionsCodex.currentPage.enabled = false;
    FlxG.keys.enabled = true;
    var target = luaPauseExitTargetForThisState ?? 'resume';

    switch (target.toLowerCase())
    {
      case 'resume' | 'backtosong' | 'back_to_song' | 'song' | 'back':
        if (!funkin.play.PlayState.restartLastSong()) FlxG.switchState(() -> new MainMenuState());
      case 'restart' | 'restartsong' | 'restart_song':
        if (!funkin.play.PlayState.restartLastSong()) FlxG.switchState(() -> new MainMenuState());
      case 'mainmenu' | 'menu' | 'exit':
        FlxG.switchState(() -> new MainMenuState());
      default:
        try
        {
          var stateClass = Type.resolveClass(target);
          if (stateClass == null)
          {
            FlxG.switchState(() -> new MainMenuState());
            return;
          }
          var stateInstance = Type.createInstance(stateClass, []);
          if (!Std.isOfType(stateInstance, FlxState))
          {
            FlxG.switchState(() -> new MainMenuState());
            return;
          }
          FlxG.switchState(() -> cast(stateInstance, FlxState));
        }
        catch (e)
        {
          FlxG.switchState(() -> new MainMenuState());
        }
    }
  }

  #if FEATURE_LUA_SCRIPTS
  public static function prepareLuaPauseReturn(config:Dynamic):Void
  {
    luaPauseExitTarget = readLuaString(config, 'howExit', readLuaString(config, 'exitTarget', 'resume'));
    luaPauseHideExit = readLuaBool(config, 'hideExit', true);
  }

  public static function hasPendingLuaPauseReturn():Bool
  {
    return luaPauseExitTarget != null || luaPauseHideExit;
  }

  static function readLuaString(data:Dynamic, field:String, fallback:String):String
  {
    if (data == null || !Reflect.hasField(data, field)) return fallback;
    var value = Reflect.field(data, field);
    return value == null ? fallback : Std.string(value);
  }

  static function readLuaBool(data:Dynamic, field:String, fallback:Bool):Bool
  {
    if (data == null || !Reflect.hasField(data, field)) return fallback;
    var value = Reflect.field(data, field);
    if (Std.isOfType(value, Bool)) return value;
    return Std.string(value).toLowerCase() == 'true';
  }
  #end

  static function clearLuaPauseReturn():Void
  {
    luaPauseExitTarget = null;
    luaPauseHideExit = false;
  }
}

/**
 * Our default Page when we enter the OptionsState, a bit of the root
 */
class OptionsMenu extends Page<OptionsMenuPageName>
{
  var items:TextMenuList;

  #if FEATURE_TOUCH_CONTROLS
  var backButton:FunkinBackButton;
  var goingBack:Bool = false;
  #end

  /**
   * Camera focus point
   */
  var camFocusPoint:FlxObject;

  final CAMERA_MARGIN:Int = 150;

  public function new()
  {
    super();
    add(items = new TextMenuList());

    createItem("PREFERENCES", function() codex.switchPage(Preferences));
    #if mobile
    if (ControlsHandler.hasExternalInputDevice)
    #end
    createItem("CONTROLS", function() codex.switchPage(Controls));
    // createItem("CONTROL SCHEMES", function() {
    //   FlxG.state.openSubState(new ControlsSchemeMenu());
    // });
    #if FEATURE_LAG_ADJUSTMENT
    createItem("LAG ADJUSTMENT", function()
    {
      var switchToOffsets = function()
      {
        FunkinSound.playMusic('offsetsLoop', {
          startingVolume: 0,
          overrideExisting: true,
          restartTrack: true,
          loop: true
        });
        OptionsState.instance.drumsBG.play(true);
        FlxG.sound.music.fadeIn(1, 1);
        codex.switchPage(Offsets);
      };

      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.fadeOut(0.5, 0, function(tw)
        {
          switchToOffsets();
        });
      }
      else
      {
        switchToOffsets();
      }
    });
    #end
    #if FEATURE_MOBILE_IAP
    createItem("RESTORE PURCHASES", function()
    {
      InAppPurchasesUtil.restorePurchases();
    });
    #end
    #if android
    createItem("OPEN DATA FOLDER", function()
    {
      funkin.external.android.DataFolderUtil.openDataFolder();
    });
    #end
    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem("LOGOUT OF NG", function()
      {
        NewgroundsClient.instance.logout(function()
        {
          // Reset the options menu when logout succeeds.
          // This means the login option will be displayed.
          FlxG.resetState();
        }, function()
        {
          FlxG.log.warn("Newgrounds logout failed!");
        });
      });
    }
    #end

    // Create an object for the camera to track.
    camFocusPoint = new FlxObject(0, 0, 140, 70);
    add(camFocusPoint);

    // Follow the camera focus as we scroll.
    FlxG.camera.follow(camFocusPoint, null, 0.085);
    FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
    FlxG.camera.minScrollY = -CAMERA_MARGIN / 2;

    // Move the camera when the menu is scrolled.
    items.onChange.add(onMenuChange);

    onMenuChange(items.members[0]);

    items.selectItem(OptionsState.rememberedSelectedIndex);
    #if FEATURE_TOUCH_CONTROLS
    FlxG.touches.swipeThreshold.y = 100;
    #end
  }

  public function addSaveDataOptionsItem(saveDataMenu:SaveDataMenu):Void
  {
    // no need to show an entire new menu for just one option
    if (saveDataMenu.hasMultipleOptions())
    {
      createItem("SAVE DATA OPTIONS", function()
      {
        codex.switchPage(SaveData);
      });
    }
    else
    {
      createItem("CLEAR SAVE DATA", saveDataMenu.openSaveDataPrompt);
    }
  }

  public function addExitItem():Void
  {
    #if NO_FEATURE_TOUCH_CONTROLS
    createItem("EXIT", exit);
    #else
    backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    backButton.onConfirmStart.add(function()
    {
      items.busy = true;
      goingBack = true;
      backButton.active = true;
    });
    add(backButton);
    #end
  }

  public function addLuaOptionsItem(name:String, callback:Void->Void):TextMenuItem
  {
    return createItem(name, callback);
  }

  public function removeLuaOptionsItem(name:String):Bool
  {
    var item = items.getItem(name);
    if (item == null) return false;
    items.remove(item, true);
    item.destroy();
    return true;
  }

  public function moveLuaOptionsItemBefore(item:TextMenuItem, beforeName:String):Void
  {
    var beforeItem = items.getItem(beforeName);
    if (beforeItem == null) return;
    items.members.remove(item);
    var index = items.members.indexOf(beforeItem);
    items.members.insert(index < 0 ? items.members.length : index, item);
  }

  public function moveLuaOptionsItemToPosition(item:TextMenuItem, position:Int):Void
  {
    items.members.remove(item);
    var index = position - 1;
    if (index < 0) index = 0;
    if (index > items.members.length) index = items.members.length;
    items.members.insert(index, item);
  }

  public function repositionLuaOptionsItems():Void
  {
    for (i in 0...items.members.length)
    {
      var item = items.members[i];
      if (item != null) item.y = 100 + i * 100;
    }
  }

  function onMenuChange(selected:TextMenuItem):Void
  {
    camFocusPoint.y = selected.y;
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false):TextMenuItem
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override function update(elapsed:Float):Void
  {
    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    #if FEATURE_TOUCH_CONTROLS
    backButton.active = (!goingBack) ? !items.busy : true;
    #end
    super.update(elapsed);
  }

  override function set_enabled(value:Bool):Bool
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  /**
   * True if this page has multiple options, excluding the exit option.
   * If false, there's no reason to ever show this page.
   */
  public function hasMultipleOptions():Bool
  {
    return items.length > 2;
  }
}

enum abstract OptionsMenuPageName(String) to PageName
{
  var Options = "options";
  var Controls = "controls";
  var Colors = "colors";
  var Mods = "mods";
  var Preferences = "preferences";
  var Offsets = "offsets";
  var SaveData = "saveData";
}
