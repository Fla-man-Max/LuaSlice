package funkin.ui;

#if FEATURE_LUA_SCRIPTS
import luaslice.lua.LuaScriptManager;
#end
#if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
import luaslice.script.ScriptRuntimeManager;
#end
import funkin.util.FlxStateUtil;
import funkin.modding.IScriptedClass.IEventHandler;
import funkin.ui.mainmenu.MainMenuState;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import flixel.util.FlxSort;
import flixel.util.typeLimit.NextState;
import funkin.modding.PolymodHandler;
import funkin.modding.events.ScriptEvent;
import funkin.modding.module.ModuleHandler;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import funkin.input.Controls;
import funkin.ui.FullScreenScaleMode;
import funkin.ui.transition.preload.hotreload.HotReloadState.HotReloadStateParams;
import funkin.graphics.FunkinCamera;
#if FEATURE_TOUCH_CONTROLS
import funkin.touch.ui.FunkinHitbox;
import funkin.touch.ui.FunkinBackButton;
import funkin.touch.ui.FunkinOptionsButton;
import funkin.touch.input.PreciseInputHandler;
import funkin.play.notes.NoteDirection;
#end

/**
 * MusicBeatState actually represents the core utility FlxState of the game.
 * It includes functionality for event handling, as well as maintaining BPM-based update events.
 */
@:nullSafety
class MusicBeatState extends FlxTransitionableState implements IEventHandler
{
  var controls(get, never):Controls;

  #if FEATURE_LUA_SCRIPTS
  var classLuaScriptManager:Null<LuaScriptManager>;
  #end

  #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
  var classScriptRuntimeManager:Null<ScriptRuntimeManager>;
  var classScriptRuntimeInitialized:Bool = false;
  #end

  inline function get_controls():Controls return PlayerSettings.player1.controls;

  public var leftWatermarkText:Null<FlxText> = null;
  public var rightWatermarkText:Null<FlxText> = null;
  public var conductorInUse(get, set):Conductor;
  public var default_trans_isTransitioning:Bool = false;

  var _conductorInUse:Null<Conductor>;

  function get_conductorInUse():Conductor
  {
    if (_conductorInUse == null) return Conductor.instance;
    return _conductorInUse;
  }

  function set_conductorInUse(value:Conductor):Conductor
  {
    return _conductorInUse = value;
  }

  override function transitionIn():Void
  {
    default_trans_isTransitioning = hasTransIn;
    super.transitionIn();
  }

  override function transitionOut(?onComplete:Void->Void):Void
  {
    default_trans_isTransitioning = hasTransOut;
    super.transitionOut(onComplete);
  }

  override function finishTransIn()
  {
    if (FlxStateUtil.hasSubState(this)) FlxStateUtil.closeTransitionAtTop(this);
    else
      super.finishTransIn();

    var stateClass:Null<Class<Dynamic>> = FlxG.state != null ? Type.getClass(FlxG.state) : null;
    var state:String = stateClass != null ? Type.getClassName(stateClass) : 'none';
    trace(' UI '.bold().bg_orange() + '$state: Finish transition in.');

    default_trans_isTransitioning = false;
  }

  override function finishTransOut()
  {
    super.finishTransOut();

    default_trans_isTransitioning = false;
  }

  public function new()
  {
    if (FullScreenScaleMode.instance != null) FullScreenScaleMode.instance.onMeasurePostAwait();

    super();

    initCallbacks();
  }

  function initCallbacks()
  {
    subStateOpened.add(onOpenSubStateComplete);
    subStateClosed.add(onCloseSubStateComplete);
  }

  #if FEATURE_TOUCH_CONTROLS
  public var hitbox:Null<FunkinHitbox>;
  public var backButton:Null<FunkinBackButton>;
  public var optionsButton:Null<FunkinOptionsButton>;
  public var camControls:Null<FunkinCamera>;

  public function addHitbox(visible:Bool = true,
    initInput:Bool = true,
    ?schemeOverride:String,
    ?directionsOverride:Array<NoteDirection>,
    ?colorsOverride:Array<FlxColor>):Void
  {
    if (hitbox != null)
    {
      hitbox.kill();
      remove(hitbox);
      hitbox.destroy();
    }

    if (camControls == null)
    {
      camControls = new FunkinCamera('camControls');
      FlxG.cameras.add(camControls, false);
      camControls.bgColor = 0x0;
    }

    hitbox = new FunkinHitbox(schemeOverride, true, directionsOverride, colorsOverride);
    hitbox.cameras = [camControls];
    hitbox.visible = visible;
    add(hitbox);

    if (initInput) PreciseInputHandler.initializeHitbox(hitbox);
  }

  public function addBackButton(?xPos:Float = 0,
    ?yPos:Float = 0,
    ?color:FlxColor = FlxColor.WHITE,
    ?confirmCallback:Void->Void = null,
    ?restOpacity:Float = 0.3,
    ?instant:Bool = false):Void
  {
    if (backButton != null)
    {
      remove(backButton, true);
      backButton.destroy();
      backButton = null;
    }

    if (camControls == null)
    {
      camControls = new FunkinCamera('camControls');
      FlxG.cameras.add(camControls, false);
      camControls.bgColor = 0x0;
    }

    backButton = new FunkinBackButton(xPos, yPos, color, confirmCallback, restOpacity, instant);
    backButton.cameras = [camControls];
    add(backButton);
  }

  // this should get moved post ui update but this is easier rn lolll

  public function addOptionsButton(?xPos:Float = 0,
    ?yPos:Float = 0,
    ?confirmCallback:Void->Void = null,
    ?instant:Bool = false):Void
  {
    if (optionsButton != null)
    {
      remove(optionsButton, true);
      optionsButton.destroy();
      optionsButton = null;
    }

    if (camControls == null)
    {
      camControls = new FunkinCamera('camControls');
      FlxG.cameras.add(camControls, false);
      camControls.bgColor = 0x0;
    }

    optionsButton = new FunkinOptionsButton(xPos, yPos, confirmCallback, instant);
    optionsButton.cameras = [camControls];
    add(optionsButton);
  }
  #end

  override function create():Void
  {
    if (transIn == null) transIn = FlxTransitionableState.defaultTransIn;
    if (transOut == null) transOut = FlxTransitionableState.defaultTransOut;

    super.create();

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager = LuaScriptManager.loadClassScriptsForState(this);
    classLuaScriptManager?.callHook('onCreate', []);
    #end

    createWatermarkText();

    Conductor.beatHit.add(this.beatHit);
    Conductor.stepHit.add(this.stepHit);

    var event:ScriptEvent = ScriptEvent.get(STATE_CREATE);
    dispatchEvent(event);
  }

  override public function destroy():Void
  {
    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onDestroy', []);
    classLuaScriptManager?.destroy();
    classLuaScriptManager = null;
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onDestroy', []);
    classScriptRuntimeManager?.destroy();
    classScriptRuntimeManager = null;
    #end

    #if FEATURE_TOUCH_CONTROLS
    if (hitbox != null)
    {
      remove(hitbox, true);
      hitbox.destroy();
      hitbox = null;
    }
    if (backButton != null)
    {
      remove(backButton, true);
      backButton.destroy();
      backButton = null;
    }
    if (optionsButton != null)
    {
      remove(optionsButton, true);
      optionsButton.destroy();
      optionsButton = null;
    }
    #end

    super.destroy();

    #if FEATURE_TOUCH_CONTROLS
    if (camControls != null) FlxG.cameras.remove(camControls);
    #end

    Conductor.beatHit.remove(this.beatHit);
    Conductor.stepHit.remove(this.stepHit);
  }

  override function update(elapsed:Float):Void
  {
    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    if (!classScriptRuntimeInitialized)
    {
      classScriptRuntimeInitialized = true;
      classScriptRuntimeManager = ScriptRuntimeManager.loadClassScripts(this);
      classScriptRuntimeManager?.callHook('onCreate', []);
    }
    #end

    super.update(elapsed);

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onUpdate', [elapsed]);
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onUpdate', [elapsed]);
    #end

    var event:UpdateScriptEvent = UpdateScriptEvent.get(elapsed);
    dispatchEvent(event);
  }

  override function onFocus():Void
  {
    super.onFocus();

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onFocusGained', []);
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onFocusGained', []);
    #end

    var event:ScriptEvent = FocusScriptEvent.get(FOCUS_GAINED);
    dispatchEvent(event);
  }

  override function onFocusLost():Void
  {
    super.onFocusLost();

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onFocusLost', []);
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onFocusLost', []);
    #end

    var event:ScriptEvent = FocusScriptEvent.get(FOCUS_LOST);
    dispatchEvent(event);
  }

  function createWatermarkText()
  {
    // Both have an xPos of 0, but a width equal to the full screen.
    // The rightWatermarkText is right aligned, which puts the text in the correct spot.
    // Their xPos is only changed when there's a notch on the device so it doesn't get covered by it.
    leftWatermarkText = new FlxText(funkin.ui.FullScreenScaleMode.gameNotchSize.x, FlxG.height - 18, FlxG.width, '', 12);
    rightWatermarkText = new FlxText(-(funkin.ui.FullScreenScaleMode.gameNotchSize.x), FlxG.height - 18, FlxG.width, '', 12);

    // 100,000 should be good enough.
    leftWatermarkText.zIndex = 100000;
    rightWatermarkText.zIndex = 100000;
    leftWatermarkText.scrollFactor.set(0, 0);
    rightWatermarkText.scrollFactor.set(0, 0);
    leftWatermarkText.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    rightWatermarkText.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

    add(leftWatermarkText);
    add(rightWatermarkText);
  }

  public function dispatchEvent(event:ScriptEvent, finish:Bool = true):Void
  {
    ModuleHandler.callEvent(event);
    #if FEATURE_LUA_SCRIPTS
    if (event.shouldPropagate) classLuaScriptManager?.callEvent(event, false);
    #end
    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    if (event.shouldPropagate && event.type == CUSTOM) classScriptRuntimeManager?.callCustomEvent(cast event);
    #end
    if (finish) event.finish();
  }

  public function getHotReloadParams():HotReloadStateParams
  {
    return {targetState: getConstructor()};
  }

  function getConstructor():NextState
  {
    var scriptedNextState:NextState = () ->
    {
      var path:String = _asc?.fullyQualifiedName ?? '';
      var constructorArgs:Array<Dynamic> = _asc?.getConstructorArgs() ?? [];

      var newState:Null<MusicBeatState> = MusicBeatState.scriptInit(path, ...constructorArgs);
      if (newState == null) return new funkin.ui.mainmenu.MainMenuState();
      return newState;
    }
    var nextState:NextState = _asc != null ? scriptedNextState : _constructor;

    return nextState;
  }

  /**
   * Called right before hot reloading begins.
   */
  public function onPreHotReload():Void
  {
  }

  /**
   * Called right after hot reloading and the state is initalized.
   */
  public function onPostHotReload():Void
  {
  }

  public function stepHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event:SongTimeScriptEvent = SongTimeScriptEvent.get(SONG_STEP_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onStepHit', [Std.int(conductorInUse.currentStep)]);
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onStepHit', [Std.int(conductorInUse.currentStep)]);
    #end

    dispatchEvent(event, false);

    if (event.eventCanceled)
    {
      event.finish();
      return false;
    }

    event.finish();
    return true;
  }

  public function beatHit():Bool
  {
    if (this.subState != null && !persistentUpdate) return false;

    var event:SongTimeScriptEvent = SongTimeScriptEvent.get(SONG_BEAT_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    #if FEATURE_LUA_SCRIPTS
    classLuaScriptManager?.callHook('onBeatHit', [Std.int(conductorInUse.currentBeat)]);
    #end

    #if (FEATURE_SSCRIPT_SCRIPTS || FEATURE_NXSCRIPT_SCRIPTS)
    classScriptRuntimeManager?.callHook('onBeatHit', [Std.int(conductorInUse.currentBeat)]);
    #end

    dispatchEvent(event, false);

    if (event.eventCanceled)
    {
      event.finish();
      return false;
    }

    event.finish();
    return true;
  }

  /**
   * Refreshes the state, by redoing the render order of all sprites.
   * It does this based on the `zIndex` of each prop.
   */
  public function refresh():Void
  {
    sort(SortUtil.byZIndex, FlxSort.ASCENDING);
  }

  @:nullSafety(Off)
  override function startOutro(onComplete:() -> Void):Void
  {
    var event:StateChangeScriptEvent = StateChangeScriptEvent.get(STATE_CHANGE_BEGIN, null, true);

    dispatchEvent(event, false);

    if (event.eventCanceled)
    {
      event.finish();
      return;
    }

    FunkinSound.stopAllAudio();
    onComplete();
    event.finish();
  }

  override public function openSubState(targetSubState:FlxSubState):Void
  {
    var event = SubStateScriptEvent.get(SUBSTATE_OPEN_BEGIN, targetSubState, true);

    dispatchEvent(event, false);

    if (event.eventCanceled)
    {
      event.finish();
      return;
    }

    if (FlxStateUtil.cancelTransitionAtTop(this))
    {
      FlxTransitionableState.skipNextTransIn = false;
      FlxTransitionableState.skipNextTransOut = false;
    }

    // Make sure that the game opens substates at the top of the stack.
    // Events will be dispatched by the substate.
    if (FlxStateUtil.hasSubState(this, true))
    {
      FlxStateUtil.openSubStateAtTop(targetSubState, this);
      event.finish();
      return;
    }

    super.openSubState(targetSubState);
    event.finish();
  }

  function onOpenSubStateComplete(targetState:FlxSubState):Void
  {
    var event:SubStateScriptEvent = SubStateScriptEvent.get(SUBSTATE_OPEN_END, targetState, false);
    dispatchEvent(event);
  }

  override public function closeSubState():Void
  {
    var event:SubStateScriptEvent = SubStateScriptEvent.get(SUBSTATE_CLOSE_BEGIN, this.subState, true);

    dispatchEvent(event, false);

    if (event.eventCanceled)
    {
      event.finish();
      return;
    }

    super.closeSubState();
    event.finish();
  }

  function onCloseSubStateComplete(targetState:FlxSubState):Void
  {
    var event:SubStateScriptEvent = SubStateScriptEvent.get(SUBSTATE_CLOSE_END, targetState, false);
    dispatchEvent(event);
  }
}
