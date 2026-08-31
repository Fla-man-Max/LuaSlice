package funkin.util.plugins;

import funkin.ui.ScriptedMusicBeatState;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.addons.transition.FlxTransitionableState;
import funkin.ui.MusicBeatState;
import funkin.ui.MusicBeatSubState;
import funkin.ui.transition.preload.hotreload.HotReloadState;
import funkin.ui.transition.preload.hotreload.HotReloadState.HotReloadStateParams;
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
  public static var hotReloadInProgress:Bool = false;

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

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    #if html5
    if (FlxG.keys.justPressed.FIVE && FlxG.keys.pressed.SHIFT)
    #else
    if (FlxG.keys.justPressed.F5)
    #end
    if (!hotReloadInProgress)
    {
      reload();
    }
  }

  override public function destroy():Void
  {
    super.destroy();

    #if android
    if (CallbackUtil.onActivityResult.has(onActivityResult))
    {
      CallbackUtil.onActivityResult.remove(onActivityResult);
    }
    #end
  }

  var path:String = '';

  @:noCompletion
  function reload():Void
  {
    if (hotReloadInProgress) return;
    hotReloadInProgress = true;
    FlxTransitionableState.skipNextTransIn = true;

    var state:Dynamic = FlxG.state;
    var params:HotReloadStateParams = {};
    if (state is MusicBeatState || state is MusicBeatSubState)
    {
      state.onPreHotReload();
      params = state.getHotReloadParams();
    }
    else
    {
      @:privateAccess
      params.targetState = state._constructor;
    }
    FlxG.switchState(() -> new HotReloadState(params));
  }

  #if android
  @:noCompletion
  function onActivityResult(requestCode:Int, resultCode:Int):Void
  {
    if (requestCode == CallbackUtil.DATA_FOLDER_CLOSED)
    {
      reload();
    }
  }
  #end
}
