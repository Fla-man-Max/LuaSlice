package funkin.ui.options;

import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.util.plugins.ReloadAssetsDebugPlugin;

class ModPhotosensitivityWarningState extends FlxState
{
  var onContinue:Void->Void;
  var buttons:Array<FlxSprite> = [];
  var labels:Array<FlxText> = [];
  var selected:Int = 1;
  var elapsedTime:Float = 0;
  var inputReady:Bool = false;
  var leaving:Bool = false;
  var mouseButton:Int = -1;
  var previousMouseVisibility:Bool = false;
  var previousReloadFlag:Bool = false;
  #if FLX_TOUCH
  var touchButtons:Map<Int, Int> = [];
  #end

  public function new(onContinue:Void->Void)
  {
    super();
    this.onContinue = onContinue;
  }

  override public function create():Void
  {
    super.create();
    previousReloadFlag = ReloadAssetsDebugPlugin.hotReloadInProgress;
    ReloadAssetsDebugPlugin.hotReloadInProgress = true;
    previousMouseVisibility = FlxG.mouse.visible;
    FlxG.mouse.visible = true;
    FlxG.camera.bgColor = FlxColor.BLACK;
    flixel.tweens.FlxTween.globalManager.clear();
    flixel.util.FlxTimer.globalManager.clear();
    if (FlxG.sound.music != null) FlxG.sound.music.pause();
    FlxG.sound.list.forEach(sound -> sound.pause());

    var margin = FlxG.width * 0.07;
    var width = FlxG.width - margin * 2;
    var scale = Math.min(FlxG.width / 1280, FlxG.height / 720);
    addText(margin, FlxG.height * 0.09, width, 'Photosensitivity Warning', Math.round(38 * scale));
    var names = PolymodHandler.pendingVisualWarnings.map(warning -> warning.title);
    var modNames = names.slice(0, 3).join(', ');
    if (names.length > 3) modNames += ' and ${names.length - 3} more';
    modNames = 'Affected mods (${names.length}): ' + modNames;
    if (modNames.length > 72) modNames = modNames.substr(0, 69) + '...';
    addText(margin, FlxG.height * 0.20, width, modNames, Math.round(22 * scale));
    addText(margin, FlxG.height * 0.28, width,
      'This mod contains flashing lights, rapidly changing colors, or intense visual effects that may affect people with photosensitivity or certain medical conditions.',
      Math.round(26 * scale));
    addText(margin, FlxG.height * 0.46, width,
      'Disabling Flashing Lights reduces supported effects, but does not remove every photosensitivity risk. You can change this later in Options > Performance.\n\nFlashing Lights: '
      + (Preferences.flashingLights ? 'Enabled' : 'Disabled'), Math.round(20 * scale));

    var buttonWidth = Math.min(width, 760 * scale);
    var buttonHeight = Math.max(56, Math.round(64 * scale));
    var buttonX = (FlxG.width - buttonWidth) / 2;
    for (index in 0...2)
    {
      var y = FlxG.height * 0.68 + index * (buttonHeight + 16 * scale);
      var button = new FlxSprite(buttonX, y).makeGraphic(Math.ceil(buttonWidth), Math.ceil(buttonHeight), FlxColor.WHITE);
      buttons.push(button);
      add(button);
      var label = addText(buttonX + 8, y + (buttonHeight - 30 * scale) / 2, buttonWidth - 16,
        index == 0 ? 'Continue' : 'Disable Flashing Lights & Continue', Math.round(24 * scale));
      labels.push(label);
    }
    refreshSelection();
    trace('[MOD WARNING] Waiting for acknowledgment before loading: ${PolymodHandler.pendingVisualWarnings.map(warning -> warning.dir).join(", ")}');
  }

  function addText(x:Float, y:Float, width:Float, text:String, size:Int):FlxText
  {
    var label = new FlxText(x, y, width, text, Std.int(Math.max(12, size)));
    label.alignment = CENTER;
    label.color = FlxColor.WHITE;
    add(label);
    return label;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leaving) return;
    elapsedTime += elapsed;
    if (!inputReady)
    {
      var pressed = FlxG.mouse.pressed || FlxG.keys.anyPressed([ENTER, SPACE])
        || FlxG.gamepads.anyPressed(FlxGamepadInputID.ACCEPT);
      #if FLX_TOUCH
      for (touch in FlxG.touches.list) if (touch.pressed) pressed = true;
      #end
      inputReady = elapsedTime >= 0.4 && !pressed;
      return;
    }

    if (FlxG.keys.anyJustPressed([UP, DOWN, LEFT, RIGHT, W, S, TAB])
      || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_UP)
      || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_DOWN))
    {
      selected = 1 - selected;
      refreshSelection();
    }

    if (FlxG.mouse.justPressed)
    {
      mouseButton = -1;
      for (index in 0...buttons.length) if (FlxG.mouse.overlaps(buttons[index])) mouseButton = index;
    }
    if (FlxG.mouse.justReleased && mouseButton >= 0)
    {
      if (FlxG.mouse.overlaps(buttons[mouseButton])) choose(mouseButton);
      mouseButton = -1;
    }
    #if FLX_TOUCH
    for (touch in FlxG.touches.list)
    {
      if (touch.justPressed)
        for (index in 0...buttons.length)
          if (touch.overlaps(buttons[index])) touchButtons.set(touch.touchPointID, index);
      if (touch.justReleased)
      {
        var index = touchButtons.get(touch.touchPointID);
        if (index != null && touch.overlaps(buttons[index])) choose(index);
        touchButtons.remove(touch.touchPointID);
      }
    }
    #end
    if (FlxG.keys.anyJustPressed([ENTER, SPACE]) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.ACCEPT)) choose(selected);
  }

  function refreshSelection():Void
  {
    for (index in 0...buttons.length)
    {
      buttons[index].color = selected == index ? 0xFFDDDDDD : 0xFF333333;
      labels[index].color = selected == index ? FlxColor.BLACK : FlxColor.WHITE;
    }
  }

  function choose(index:Int):Void
  {
    if (leaving) return;
    leaving = true;
    if (index == 1) Preferences.flashingLights = false;
    trace('[MOD WARNING] Acknowledged; Flashing Lights: ${Preferences.flashingLights}');
    onContinue();
  }

  override public function destroy():Void
  {
    FlxG.mouse.visible = previousMouseVisibility;
    ReloadAssetsDebugPlugin.hotReloadInProgress = previousReloadFlag;
    super.destroy();
  }
}
