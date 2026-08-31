package funkin.ui.debug;

import flixel.FlxSprite;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.ui.FullScreenScaleMode;

class DebugMenuState extends MusicBeatState
{
  var leaving:Bool = false;

  override function create():Void
  {
    super.create();

    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    menuBG.color = 0xFF4CAF50;
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1 * FullScreenScaleMode.wideScale.x));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

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
