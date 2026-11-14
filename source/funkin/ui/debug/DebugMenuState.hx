package funkin.ui.debug;

import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;

class DebugMenuState extends MusicBeatState
{
  var leaving:Bool = false;

  override function create():Void
  {
    super.create();

    persistentUpdate = false;
    persistentDraw = true;
    openSubState(new DebugMenuSubState(exitToMainMenu));
  }

  function exitToMainMenu():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.switchState(() -> new MainMenuState());
  }
}
