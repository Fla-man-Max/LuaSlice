package luaslice.lua;

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
    final scriptedStateClass:Dynamic = ScriptedMusicBeatState;
    final listStateScripts:Dynamic = Reflect.field(scriptedStateClass, 'listScriptClasses');
    final initStateScript:Dynamic = Reflect.field(scriptedStateClass, 'scriptInit');
    final scriptedStates:Array<String> = listStateScripts == null ? [] : cast Reflect.callMethod(scriptedStateClass, listStateScripts, []);
    if (scriptedStates.indexOf(target) >= 0 && initStateScript != null)
      state = Reflect.callMethod(scriptedStateClass, initStateScript, [target]);
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
    final scriptedSubStateClass:Dynamic = ScriptedMusicBeatSubState;
    final listSubStateScripts:Dynamic = Reflect.field(scriptedSubStateClass, 'listScriptClasses');
    final initSubStateScript:Dynamic = Reflect.field(scriptedSubStateClass, 'scriptInit');
    final scriptedSubStates:Array<String> = listSubStateScripts == null ? [] : cast Reflect.callMethod(scriptedSubStateClass, listSubStateScripts, []);
    if (scriptedSubStates.indexOf(target) >= 0 && initSubStateScript != null)
      subState = Reflect.callMethod(scriptedSubStateClass, initSubStateScript, [target]);
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
