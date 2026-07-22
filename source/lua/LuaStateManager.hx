package;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import funkin.ui.ScriptedMusicBeatState;
import funkin.ui.ScriptedMusicBeatSubState;
#end

class LuaStateManager
{
  #if FEATURE_LUA_SCRIPTS
  public static function openState(target:String, args:Array<Dynamic>):Bool
  {
    var state:Dynamic = null;
    if (ScriptedMusicBeatState.listScriptClasses().indexOf(target) >= 0)
      state = ScriptedMusicBeatState.scriptInit(target);
    else
    {
      final targetClass = Type.resolveClass(target);
      if (targetClass != null) state = Type.createInstance(targetClass, args);
    }

    if (state == null || !Std.isOfType(state, FlxState)) return false;
    final resolved:FlxState = cast state;
    FlxG.switchState(() -> resolved);
    return true;
  }

  public static function openSubState(target:String, args:Array<Dynamic>):Bool
  {
    var subState:Dynamic = null;
    if (ScriptedMusicBeatSubState.listScriptClasses().indexOf(target) >= 0)
      subState = ScriptedMusicBeatSubState.scriptInit(target);
    else
    {
      final targetClass = Type.resolveClass(target);
      if (targetClass != null) subState = Type.createInstance(targetClass, args);
    }

    if (subState == null || !Std.isOfType(subState, FlxSubState) || FlxG.state == null) return false;
    FlxG.state.openSubState(cast subState);
    return true;
  }
  #end
}
