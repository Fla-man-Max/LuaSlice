package funkin.util.plugins;

import funkin.ui.ScriptedMusicBeatState;
import flixel.FlxG;
import flixel.FlxBasic;
import funkin.ui.MusicBeatState;
import funkin.ui.MusicBeatSubState;
#if FEATURE_LUA_SCRIPTS
import funkin.play.PlayState;
import funkin.play.GameOverSubState;
#end
#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
#end
#if android
import funkin.external.android.CallbackUtil;
#end

/**
 * A plugin which adds functionality to press `F5` to reload all game assets, then reload the current state.
 * This is useful for hot reloading assets during development.
 */
@:nullSafety
class ReloadAssetsDebugPlugin extends FlxBasic
{
  public function new()
  {
    super();

    #if android
    CallbackUtil.onActivityResult.add(onActivityResult);
    #end
  }

  public static function initialize():Void
  {
    FlxG.plugins.addPlugin(new ReloadAssetsDebugPlugin());
  }

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    #if html5
    if (FlxG.keys.justPressed.FIVE && FlxG.keys.pressed.SHIFT)
    #else
    if (FlxG.keys.justPressed.F5)
    #end
    {
      reload(true);
    }
  }

  public override function destroy():Void
  {
    super.destroy();

    #if android
    if (CallbackUtil.onActivityResult.has(onActivityResult))
    {
      CallbackUtil.onActivityResult.remove(onActivityResult);
    }
    #end
  }

  var path:String = "";

  @:noCompletion
  function reload(luaHotReload:Bool = false):Void
  {
    var state:Dynamic = FlxG.state;
    #if FEATURE_LUA_SCRIPTS
    var playState:Null<PlayState> = null;
    if (!(state is PlayState) && state?.subState is PlayState)
    {
      playState = cast state.subState;
    }

    if (luaHotReload && playState != null && !playState.isGameOverState && GameOverSubState.instance == null)
    {
      playState.reloadLuaScriptsFromDisk();
      return;
    }
    #end

    #if FEATURE_CHART_EDITOR
    if (state is ChartEditorState)
    {
      (cast state : ChartEditorState).reloadAssets();
      return;
    }
    #end

    var isScripted:Bool = state is ScriptedMusicBeatState;
    if (isScripted)
    {
      var s:ScriptedMusicBeatState = cast FlxG.state;
      @:privateAccess
      path = s._asc.fullyQualifiedName;
      trace("Current scripted state path: " + path);
    }

    if ((state is MusicBeatState || state is MusicBeatSubState) && !isScripted) state.reloadAssets();
    else
    {
      funkin.modding.PolymodHandler.forceReloadAssets();

      trace("Reloaded assets, checking for scripted state. Scripted: " + isScripted + ", Path: " + path);
      if (isScripted)
      {
        trace("Reloading scripted state: " + path);
        var state:Dynamic = ScriptedMusicBeatState.scriptInit(path);
        FlxG.switchState(state);
      }

      // Create a new instance of the current state, so old data is cleared.
      if (!isScripted) FlxG.resetState();
    }
  }

  #if android
  @:noCompletion
  function onActivityResult(requestCode:Int, resultCode:Int):Void
  {
    if (requestCode == CallbackUtil.DATA_FOLDER_CLOSED)
    {
      reload(false);
    }
  }
  #end
}
