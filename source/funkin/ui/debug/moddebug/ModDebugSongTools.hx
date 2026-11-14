package funkin.ui.debug.moddebug;

#if (FEATURE_HAXEUI && (windows || android))
import flixel.FlxCamera;
import flixel.FlxSprite;
import funkin.Conductor;
import funkin.data.event.SongEventRegistry;
import funkin.input.Cursor;
import funkin.play.PlayState;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.TextField;
import haxe.ui.containers.HBox;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;

@:access(funkin.play.PlayState)
class ModDebugSongTools extends VBox
{
  final game:PlayState;
  final uiCamera:FlxCamera;
  final windows:ModDebugWindows;
  var cameraMode:Int = 0;
  var modeChoice:DropDown;
  var updatingCameraChoices:Bool = false;
  var cameraHint:Label;
  var freeX:Float = 0;
  var freeY:Float = 0;
  var hudHidden:Bool;
  var seek:HorizontalSlider;
  var seekLabel:Label;
  var jump:Button;
  var hudOriginals:Array<{sprite:FlxSprite, x:Float, y:Float, alpha:Float}> = [];

  public function new(game:PlayState)
  {
    super();
    this.game = game;
    hudHidden = game.diagnosticHideHud;
    uiCamera = new FlxCamera();
    uiCamera.bgColor = 0;
    FlxG.cameras.add(uiCamera, false);
    cameras = [uiCamera];
    width = FlxG.width;
    height = FlxG.height;
    windows = new ModDebugWindows(this);
    var toolbar = new HBox();
    toolbar.addClass('menubar');
    addComponent(toolbar);
    button(toolbar, 'Playtest Tools', () -> windows.open('Playtest Tools', buildPanel));
    Cursor.show();
  }

  public function attach():Void
  {
    Screen.instance.addComponent(this);
    cameras = [uiCamera];
    windows.open('Playtest Tools', buildPanel);
    ModDebugWindows.redraw(this);
  }

  function buildPanel(panel:VBox):Void
  {
    label(panel, 'Temporary • applies only to this playtest');
    checkbox(panel, 'Botplay', game.isBotPlayMode, setBotPlay);
    checkbox(panel, 'Hide HUD', hudHidden, setHudHidden);
    label(panel, 'Camera mode');
    modeChoice = dropdown(panel, []);
    refreshCameraChoices();
    modeChoice.onChange = _ ->
    {
      if (updatingCameraChoices) return;
      var item = modeChoice.selectedItem;
      if (item != null) setCameraMode(item.mode);
    };
    var pan = new HBox();
    panel.addComponent(pan);
    button(pan, '←', () -> panBy(-100, 0));
    button(pan, '↑', () -> panBy(0, -100));
    button(pan, '↓', () -> panBy(0, 100));
    button(pan, '→', () -> panBy(100, 0));
    cameraHint = label(panel, 'Turn on Botplay to use free camera.');

    seekLabel = label(panel, 'Jump to 0:00');
    seek = new HorizontalSlider();
    seek.width = 250;
    seek.min = 0;
    seek.max = 100;
    seek.step = 1;
    seek.onChange = _ -> seekLabel.text = 'Jump to ' + timeLabel((FlxG.sound.music?.length ?? 0) * seek.pos / 100);
    seek.onDragEnd = _ -> seekToPercent(seek.pos);
    panel.addComponent(seek);
    jump = button(panel, 'Jump', () -> seekToPercent(seek.pos));

    button(panel, 'Edit HUD', () -> windows.open('Edit HUD', buildHudPanel));
    button(panel, 'Return to Test Debug Editor', () -> game.close());
  }

  function buildHudPanel(panel:VBox):Void
  {
    label(panel, 'Preview only. Nothing is saved.');
    var items = dropdown(panel, ['Score text', 'Health bar', 'Health bar backing', 'Player icon', 'Opponent icon', 'Player notes', 'Opponent notes']);
    var property = dropdown(panel, ['X', 'Y', 'Opacity']);
    var value = new TextField();
    value.width = 120;
    panel.addComponent(value);
    var result = label(panel, '');
    function updateValue()
    {
      var sprite = hudItem(items.selectedIndex);
      if (sprite == null)
      {
        value.text = '';
        result.text = 'This song does not have that element.';
        return;
      }
      value.text = Std.string(switch (property.selectedIndex) { case 0: sprite.x; case 1: sprite.y; default: sprite.alpha; });
      result.text = property.selectedIndex == 2 ? 'Opacity: 0 to 1.' : 'Position in game pixels.';
    }
    items.onChange = _ -> updateValue();
    property.onChange = _ -> updateValue();
    updateValue();
    button(panel, 'Apply', () ->
    {
      result.text = editHud(items.selectedIndex, property.selectedIndex, Std.parseFloat(value.text))
        ? 'Applied for this playtest.' : 'Enter a valid number for an available HUD element.';
    });
    button(panel, 'Reset HUD Edits', () ->
    {
      for (entry in hudOriginals)
      {
        if (entry.sprite.animation == null) continue;
        entry.sprite.setPosition(entry.x, entry.y);
        entry.sprite.alpha = entry.alpha;
      }
      hudOriginals.resize(0);
      updateValue();
    });
  }

  function hudItem(index:Int):Null<FlxSprite>
  {
    return switch (index)
    {
      case 0: game.scoreText;
      case 1: game.healthBar;
      case 2: game.healthBarBG;
      case 3: game.iconP1;
      case 4: game.iconP2;
      case 5: game.playerStrumline;
      case 6: game.opponentStrumline;
      default: null;
    };
  }

  public function editHud(index:Int, property:Int, value:Float):Bool
  {
    var sprite = hudItem(index);
    if (sprite == null || !Math.isFinite(value) || property < 0 || property > 2 || (property == 2 && (value < 0 || value > 1)))
      return false;
    if (!hudOriginals.exists(entry -> entry.sprite == sprite))
      hudOriginals.push({sprite: sprite, x: sprite.x, y: sprite.y, alpha: sprite.alpha});
    switch (property) { case 0: sprite.x = value; case 1: sprite.y = value; case 2: sprite.alpha = value; default: }
    return true;
  }

  public function setBotPlay(value:Bool):Void
  {
    game.isBotPlayMode = value;
    game.playerStrumline.isPlayer = !value;
    for (direction in funkin.play.notes.Strumline.DIRECTIONS) game.playerStrumline.releaseKey(direction);
    game.inputPressQueue.resize(0);
    game.inputReleaseQueue.resize(0);
    game.updateScoreText();
    if (!value && cameraMode == 1) setCameraMode(0);
    refreshCameraChoices();
    if (cameraHint != null) cameraHint.text = value
      ? 'Free camera: use the arrows above or WASD.'
      : 'Turn on Botplay to use free camera.';
  }

  public function setHudHidden(value:Bool):Void
  {
    hudHidden = value;
    game.camHUD.visible = !value;
  }

  public function setCameraMode(mode:Int):Void
  {
    if (mode == cameraMode || mode < 0 || mode > 4) return;
    if (mode == 1 && !game.isBotPlayMode) return;
    cameraMode = mode;
    if (mode == 0)
    {
      game.resetCamera(false, false, false);
      return;
    }
    freeX = game.camGame.scroll.x;
    freeY = game.camGame.scroll.y;
    game.camGame.follow(null);
  }

  function refreshCameraChoices():Void
  {
    updatingCameraChoices = true;
    modeChoice.hideDropDown();
    final names = ['Follow chart', 'Free camera', 'Always follow Player', 'Always follow Opponent', 'Always follow Girlfriend'];
    var choices = new haxe.ui.data.ArrayDataSource<Dynamic>();
    var selected = 0;
    for (mode in 0...names.length)
    {
      if (mode == 1 && !game.isBotPlayMode) continue;
      if (mode == cameraMode) selected = choices.size;
      choices.add({text: names[mode], mode: mode});
    }
    modeChoice.dataSource = choices;
    modeChoice.syncComponentValidation(false);
    modeChoice.selectedIndex = -1;
    modeChoice.selectedIndex = selected;
    modeChoice.text = choices.get(selected).text;
    modeChoice.syncComponentValidation(false);
    updatingCameraChoices = false;
  }

  public function panBy(x:Float, y:Float):Void
  {
    if (cameraMode != 1 || !game.isBotPlayMode) return;
    freeX += x / game.camGame.zoom;
    freeY += y / game.camGame.zoom;
    game.camGame.scroll.set(freeX, freeY);
  }

  function canSeek():Bool
  {
    final music = FlxG.sound.music;
    return !game.startingSong && !game.isInCutscene && !game.isSongEnd && music != null && music.playing && music.length > 1;
  }

  public function seekToPercent(percent:Float):Bool
  {
    if (!canSeek() || !Math.isFinite(percent)) return false;
    final music = FlxG.sound.music;
    final time = Math.max(0, Math.min(music.length - 1, music.length * percent / 100));
    music.time = time;
    Conductor.instance.update(time);
    game.playerStrumline.clean();
    game.opponentStrumline.clean();
    game.regenNoteData(time);
    SongEventRegistry.handleSkippedEvents(game.songEvents, time);
    game.resyncVocals();
    return true;
  }

  public function apply(elapsed:Float):Void
  {
    var active = game.subState == null && !game.isInCutscene;
    setShown(active);
    if (!active) return;
    if (hudHidden && game.camHUD.visible) game.camHUD.visible = false;
    if (seek != null)
    {
      var ready = canSeek();
      if (seek.disabled == ready) seek.disabled = !ready;
      if (jump.disabled == ready) jump.disabled = !ready;
    }
    if (cameraMode != 0)
    {
      if (game.camGame.target != null) game.camGame.follow(null);
      if (cameraMode == 1)
      {
        #if FLX_KEYBOARD
        if (!Std.isOfType(haxe.ui.focus.FocusManager.instance.focus, TextField))
        {
          var x = (FlxG.keys.pressed.D ? 1 : 0) - (FlxG.keys.pressed.A ? 1 : 0);
          var y = (FlxG.keys.pressed.S ? 1 : 0) - (FlxG.keys.pressed.W ? 1 : 0);
          panBy(x * elapsed * 450, y * elapsed * 450);
        }
        #end
        game.camGame.scroll.set(freeX, freeY);
      }
      else
      {
        var character = switch (cameraMode)
        {
          case 2: game.currentStage?.getBoyfriend();
          case 3: game.currentStage?.getDad();
          default: game.currentStage?.getGirlfriend();
        };
        if (character != null) game.camGame.focusOn(character.cameraFocusPoint);
      }
    }
  }

  public function setShown(value:Bool):Void
  {
    if (hidden == !value) return;
    hidden = !value;
    uiCamera.visible = value;
    if (value)
    {
      ModDebugWindows.redraw(this);
      Cursor.show();
    }
    else Cursor.hide();
  }

  override public function destroy():Void
  {
    if (Screen.instance.rootComponents.contains(this)) Screen.instance.removeComponent(this, false);
    if (FlxG.cameras.list.contains(uiCamera)) FlxG.cameras.remove(uiCamera);
    Cursor.hide();
    super.destroy();
  }

  static function timeLabel(milliseconds:Float):String
  {
    final seconds = Std.int(milliseconds / 1000);
    return Std.int(seconds / 60) + ':' + StringTools.lpad(Std.string(seconds % 60), '0', 2);
  }

  static function button(parent:Component, text:String, action:Void->Void):Button
  {
    var result = new Button();
    result.text = text;
    result.height = #if android 36 #else 26 #end;
    result.onClick = _ -> action();
    parent.addComponent(result);
    return result;
  }

  static function label(parent:Component, text:String):Label
  {
    var result = new Label();
    result.text = text;
    parent.addComponent(result);
    return result;
  }

  static function checkbox(parent:Component, text:String, checked:Bool, change:Bool->Void):Void
  {
    var control = new CheckBox();
    control.text = text;
    control.selected = checked;
    control.onChange = _ -> change(control.selected);
    parent.addComponent(control);
  }

  function dropdown(parent:Component, values:Array<String>):DropDown
  {
    var control = new DropDown();
    ModDebugWindows.bindDropDown(control, uiCamera);
    control.width = 250;
    for (value in values) control.dataSource.add({text: value});
    control.selectedIndex = 0;
    parent.addComponent(control);
    return control;
  }
}
#end
