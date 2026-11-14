package funkin.ui.debug.anim;

#if FEATURE_ANIMATION_EDITOR
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.input.Cursor;
import funkin.play.character.BaseCharacter;
import funkin.data.character.CharacterData;
import funkin.data.character.CharacterRegistry;
import funkin.ui.mainmenu.MainMenuState;
import funkin.util.MouseUtil;
import funkin.util.SerializerUtil;
import funkin.util.SortUtil;
import funkin.util.WindowUtil;
import funkin.audio.FunkinSound;
import haxe.ui.components.DropDown;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.core.Screen;
import haxe.ui.events.UIEvent;
import haxe.ui.RuntimeComponentBuilder;
import lime.utils.Assets as LimeAssets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.geom.Rectangle;
import openfl.net.FileReference;
#if FEATURE_TOUCH_CONTROLS
import funkin.touch.ui.FunkinBackButton;
#end
#if (mobile && FEATURE_TOUCH_CONTROLS)
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.Label;
import haxe.ui.containers.HBox;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.VBox;
import funkin.util.FileUtil;
import luaslice.debug.CharacterEditorDrag;
#end

using flixel.util.FlxSpriteUtil;

class DebugBoundingState extends FlxState
{
  var bg:FlxBackdrop;
  var txtGrp:FlxTypedGroup<FlxText>;
  var hudCam:FlxCamera;
  var curView:ANIMDEBUGVIEW = SPRITESHEET;
  var spriteSheetView:FlxGroup;
  var offsetView:FlxGroup;
  var dropDownSetup:Bool = false;
  var onionSkinChar:BaseCharacter;
  var txtOffsetShit:FlxText;
  var offsetEditorDialog:CollapsibleDialog;
  var offsetAnimationDropdown:DropDown;
  var haxeUIFocused(get, default):Bool = false;
  var currentAnimationName(get, never):String;

  #if FEATURE_TOUCH_CONTROLS
  var mobileBackButton:FunkinBackButton;
  var pinchDistance:Float = 0;
  #end
  #if (mobile && FEATURE_TOUCH_CONTROLS)
  var touchDrag = new CharacterEditorDrag();
  var fingerEdit:Bool = false;
  var fingerSpeed:Float = 1;
  var fingerOffsetX:Float = 0;
  var fingerOffsetY:Float = 0;
  var keyboardShortcuts:VBox;
  var keyboardPoll:Float = 0;
  var editorClosed:Bool = false;
  var touchStatus:Label;
  var touchOnion:CheckBox;
  var touchFlip:CheckBox;
  var touchSpeedControls:HBox;
  #end

  function get_currentAnimationName():String
  {
    return offsetAnimationDropdown?.value?.id ?? "idle";
  }

  function get_haxeUIFocused():Bool
  {
    // get the screen position, according to the HUD camera, temp default to FlxG.camera juuust in case?
    var hudMousePos:FlxPoint = FlxG.mouse.getViewPosition(hudCam ?? FlxG.camera);
    final focused = Screen.instance.hasSolidComponentUnderPoint(hudMousePos.x, hudMousePos.y);
    hudMousePos.put();
    return focused;
  }

  override function create():Void
  {
    FlxG.sound.music?.stop();

    Cursor.show();
    FunkinSound.playMusic('ui/editors/chart-editor/artistic-expression/artistic-expression', {
      startingVolume: 0.0
    });
    FlxG.sound.music.fadeIn(10, 0, 1);

    WindowUtil.setWindowTitle('${Constants.TITLE} Animation Editor');

    hudCam = new FlxCamera();
    hudCam.bgColor.alpha = 0;

    bg = new FlxBackdrop(FlxGridOverlay.createGrid(10, 10, FlxG.width, FlxG.height, true, 0xffe7e6e6, 0xffd9d5d5));
    add(bg);

    // we are setting this as the default draw camera only temporarily, to trick haxeui
    FlxG.cameras.add(hudCam);

    var str = Paths.xml('ui/editors/animation-editor/offset-editor-view');
    offsetEditorDialog = cast RuntimeComponentBuilder.fromAsset(str);

    if (offsetEditorDialog == null) throw "Could not build editor UI, check the layout file.";

    // offsetEditorDialog.findComponent("btnViewSpriteSheet").onClick = _ -> curView = SPRITESHEET;
    var viewDropdown:DropDown = offsetEditorDialog.findComponent("swapper", DropDown);
    viewDropdown.onChange = function(e:UIEvent)
    {
      curView = cast e?.data?.curView;
    };

    offsetAnimationDropdown = offsetEditorDialog.findComponent("animationDropdown", DropDown);

    offsetEditorDialog.cameras = [hudCam];
    offsetEditorDialog.closable = false;

    add(offsetEditorDialog);
    offsetEditorDialog.showDialog(false);

    // Anchor to the left side by default
    offsetEditorDialog.x = 16;
    offsetEditorDialog.y = 16;

    // sets the default camera back to FlxG.camera, since we set it to hudCamera for haxeui stuf
    FlxG.cameras.setDefaultDrawTarget(FlxG.camera, true);
    FlxG.cameras.setDefaultDrawTarget(hudCam, false);

    initSpritesheetView();
    initOffsetView();
    #if (mobile && FEATURE_TOUCH_CONTROLS)
    buildTouchControls();
    #end

    Cursor.show();

    super.create();

    #if FEATURE_TOUCH_CONTROLS
    mobileBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, exitEditor, 0.2, true);
    mobileBackButton.cameras = [hudCam];
    add(mobileBackButton);
    #end
  }

  var bf:FlxSprite;
  var swagOutlines:FlxSprite;

  function initSpritesheetView():Void
  {
    spriteSheetView = new FlxGroup();
    add(spriteSheetView);

    var tex = Paths.getSparrowAtlas('gameplay/characters/bf-pixel/bf-pixel');
    // tex.frames[0].uv

    bf = new FlxSprite();
    bf.loadGraphic(tex.parent);
    spriteSheetView.add(bf);

    swagOutlines = new FlxSprite().makeGraphic(tex.parent.width, tex.parent.height, FlxColor.TRANSPARENT);

    generateOutlines(tex.frames);

    txtGrp = new FlxTypedGroup<FlxText>();
    txtGrp.cameras = [hudCam];
    spriteSheetView.add(txtGrp);

    addInfo('boyfriend.xml', "");
    addInfo('Width', bf.width);
    addInfo('Height', bf.height);

    spriteSheetView.add(swagOutlines);
  }

  function generateOutlines(frameShit:Array<FlxFrame>):Void
  {
    // swagOutlines.width = frameShit[0].parent.width;
    // swagOutlines.height = frameShit[0].parent.height;
    swagOutlines.pixels.fillRect(new Rectangle(0, 0, swagOutlines.width, swagOutlines.height), 0x00000000);

    for (i in frameShit)
    {
      var lineStyle:LineStyle = {
        color: FlxColor.RED,
        thickness: 2
      };

      var uvW:Float = (i.uv.right * i.parent.width) - (i.uv.left * i.parent.width);
      var uvH:Float = (i.uv.bottom * i.parent.height) - (i.uv.top * i.parent.height);

      // trace(Std.int(i.uv.right * i.parent.width));
      swagOutlines.drawRect(i.uv.left * i.parent.width, i.uv.top * i.parent.height, uvW, uvH, FlxColor.TRANSPARENT, lineStyle);
      // swagGraphic.setPosition(, );
      // trace(uvH);
    }
  }

  function updateOnionSkin():Void
  {
    if (swagChar == null) return;

    onionSkinChar.alpha = 0.6;
    onionSkinChar.flipX = swagChar.flipX;

    if (onionSkinChar.hasAnimation("idle"))
    {
      onionSkinChar.playAnimation("idle", true);
    }
    else if (onionSkinChar.hasAnimation("danceLeft"))
    {
      onionSkinChar.playAnimation("danceLeft", true);
    }
    else if (onionSkinChar.hasAnimation("danceRight"))
    {
      onionSkinChar.playAnimation("danceRight", true);
    }
    else
    {
      onionSkinChar.playAnimation(currentAnimationName, true);
    }
  }

  function initOffsetView():Void
  {
    offsetView = new FlxGroup();
    add(offsetView);

    txtOffsetShit = new FlxText(20, 20, 0, "", 20);
    txtOffsetShit.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    txtOffsetShit.cameras = [hudCam];
    txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;
    offsetView.add(txtOffsetShit);

    var characters:Array<String> = CharacterRegistry.instance.listEntryIds();
    characters.sort(SortUtil.alphabetically);

    var charDropdown:DropDown = offsetEditorDialog.findComponent('characterDropdown', DropDown);
    for (char in characters)
    {
      charDropdown.dataSource.add({
        text: char
      });
    }

    charDropdown.onChange = function(e:UIEvent)
    {
      loadAnimShit(e.data.text);
    };
  }

  public var mouseOffset:FlxPoint = FlxPoint.get(0, 0);
  public var oldPos:FlxPoint = FlxPoint.get(0, 0);
  public var movingCharacter:Bool = false;

  function mouseOffsetMovement()
  {
    if (swagChar != null)
    {
      if (FlxG.mouse.justPressed && !haxeUIFocused)
      {
        movingCharacter = true;
        mouseOffset.set(FlxG.mouse.x - -swagChar.animOffsets[0], FlxG.mouse.y - -swagChar.animOffsets[1]);
      }

      if (!movingCharacter) return;

      if (FlxG.mouse.pressed)
      {
        swagChar.animOffsets = [
          (FlxG.mouse.x - mouseOffset.x) * -1,
          (FlxG.mouse.y - mouseOffset.y) * -1
        ];

        swagChar.animationOffsets.set(swagChar.getCurrentAnimation(), swagChar.animOffsets);

        txtOffsetShit.text = 'Offset: ' + swagChar.animOffsets;
        txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;
      }

      if (FlxG.mouse.justReleased)
      {
        movingCharacter = false;
      }

      if (FlxG.mouse.justReleased)
      {
        movingCharacter = false;
      }
    }
  }

  function addInfo(str:String, value:Dynamic)
  {
    var swagText:FlxText = new FlxText(10, FlxG.height - 32);
    swagText.setFormat(funkin.assets.Paths.font('ui/fonts/VCR OSD Mono'), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    swagText.scrollFactor.set();

    for (text in txtGrp.members)
    {
      text.y -= swagText.height;
    }
    txtGrp.add(swagText);

    swagText.text = str + ": " + Std.string(value);
  }

  function clearInfo()
  {
    txtGrp.clear();
  }

  override function update(elapsed:Float)
  {
    #if FEATURE_TOUCH_CONTROLS
    final pinching:Bool = handlePinchZoom();
    #else
    final pinching:Bool = false;
    #end
    #if (mobile && FEATURE_TOUCH_CONTROLS)
    keyboardPoll -= elapsed;
    if (keyboardPoll <= 0)
    {
      keyboardPoll = 0.5;
      refreshKeyboardShortcuts();
    }
    handleFingerDrag(pinching);
    #end

    if (FlxG.keys.justPressed.ONE)
    {
      var lv:DropDown = offsetEditorDialog.findComponent("swapper", DropDown);
      lv.selectedIndex = 0;
      curView = SPRITESHEET;
    }

    if (FlxG.keys.justReleased.TWO)
    {
      var lv:DropDown = offsetEditorDialog.findComponent("swapper", DropDown);
      lv.selectedIndex = 1;
      curView = ANIMATIONS;
      if (swagChar != null)
      {
        FlxG.camera.focusOn(swagChar.getMidpoint());
        FlxG.camera.zoom = 0.95;
      }
    }

    switch (curView)
    {
      case SPRITESHEET:
        spriteSheetView.visible = true;
        offsetView.visible = false;
        offsetView.active = false;
        offsetAnimationDropdown.hide();
      case ANIMATIONS:
        spriteSheetView.visible = false;
        offsetView.visible = true;
        offsetView.active = true;
        offsetAnimationDropdown.show();
        offsetControls();
        if (!pinching #if (mobile && FEATURE_TOUCH_CONTROLS) && FlxG.touches.list.length == 0 #end) mouseOffsetMovement();
    }

    if (FlxG.keys.justPressed.H) hudCam.visible = !hudCam.visible;

    if (FlxG.keys.justPressed.F4)
    {
      exitEditor();
    }

    if (FlxG.mouse.justPressed || FlxG.mouse.justPressedMiddle) FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-down'));
    if (FlxG.mouse.justReleased || FlxG.mouse.justReleasedMiddle) FunkinSound.playOnce(Paths.sound('ui/editors/chart-editor/charting-sounds/click-up'));

    if (!pinching #if (mobile && FEATURE_TOUCH_CONTROLS) && FlxG.touches.list.length == 0 #end)
    {
      MouseUtil.mouseCamDrag();
      if (!haxeUIFocused) handleTrackpadScroll();
    }

    // bg.scale.x = FlxG.camera.zoom;
    // bg.scale.y = FlxG.camera.zoom;

    bg.setGraphicSize(Std.int(bg.width / FlxG.camera.zoom));

    super.update(elapsed);
  }

  #if FEATURE_TOUCH_CONTROLS
  function handlePinchZoom():Bool
  {
    final touches = FlxG.touches.list.filter((touch) -> touch != null && touch.pressed);
    if (touches.length < 2)
    {
      pinchDistance = 0;
      return false;
    }

    movingCharacter = false;
    final deltaX:Float = touches[0].gameX - touches[1].gameX;
    final deltaY:Float = touches[0].gameY - touches[1].gameY;
    final currentDistance:Float = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

    #if mobile
    if (pinchDistance <= 0 && ((touchDrag.finger == null && !(touches[0].justPressed && touches[1].justPressed))
        || overTouchControls(touches[0].gameX, touches[0].gameY)
        || overTouchControls(touches[1].gameX, touches[1].gameY))) return true;
    #end
    if (pinchDistance > 0 && currentDistance > 0)
    {
      FlxG.camera.zoom = flixel.math.FlxMath.bound(FlxG.camera.zoom * currentDistance / pinchDistance, 0.1, 4);
    }

    pinchDistance = currentDistance;
    return true;
  }
  #end

  #if (mobile && FEATURE_TOUCH_CONTROLS)
  function refreshKeyboardShortcuts():Void
  {
    final connected = #if android funkin.external.android.KeyboardUtil.keyboardConnected
      #elseif ios funkin.external.apple.KeyboardUtil.isKeyboardConnected() #else false #end;
    if (keyboardShortcuts.hidden == connected) keyboardShortcuts.hidden = !connected;
  }

  function buildTouchControls():Void
  {
    offsetEditorDialog.findComponent('characterPanelScroll', ScrollView).scrollMode = DRAG;
    resizeTouchPanel();
    keyboardShortcuts = offsetEditorDialog.findComponent('keyboardShortcuts', VBox);
    refreshKeyboardShortcuts();
    final panel = offsetEditorDialog.findComponent('touchControls', VBox);
    panel.hidden = false;
    addTouchLabel(panel, 'Controls');
    addTouchToggle(panel, 'Finger Edit', false, enabled ->
    {
      fingerEdit = enabled;
      touchDrag.cancel();
      if (touchSpeedControls != null) touchSpeedControls.disabled = !enabled;
      if (enabled) showAnimationView();
      if (touchStatus != null) touchStatus.text = enabled ? 'Drag to edit the animation offset.' : 'Drag to move the camera.';
    });
    addTouchLabel(panel, 'Finger Edit Speed');
    touchSpeedControls = new HBox();
    panel.addComponent(touchSpeedControls);
    final speedText = new Label();
    speedText.text = '1x';
    speedText.width = 45;
    final changeSpeed = (amount:Float) ->
    {
      fingerSpeed = flixel.math.FlxMath.bound(fingerSpeed + amount, 0.25, 4);
      speedText.text = '${fingerSpeed}x';
    };
    addTouchButton(touchSpeedControls, '−', changeSpeed.bind(-0.25));
    touchSpeedControls.addComponent(speedText);
    addTouchButton(touchSpeedControls, '+', changeSpeed.bind(0.25));
    touchSpeedControls.disabled = true;
    final zoom = new HBox();
    panel.addComponent(zoom);
    addTouchButton(zoom, 'Zoom In', () -> zoomPreview(1.2));
    addTouchButton(zoom, 'Zoom Out', () -> zoomPreview(1 / 1.2));
    addTouchButton(panel, 'Save Character', saveCharacterFile);
    addTouchButton(panel, 'Load Character', loadCharacterFile);
    addTouchLabel(panel, 'Toggles');
    touchOnion = addTouchToggle(panel, 'Onion Skin', true, visible ->
    {
      if (onionSkinChar == null) return;
      onionSkinChar.visible = visible;
      if (visible) updateOnionSkin();
    });
    touchFlip = addTouchToggle(panel, 'Flip Horizontally', false, flipped ->
    {
      if (swagChar == null) return;
      swagChar.flipX = flipped;
      if (onionSkinChar?.visible == true) updateOnionSkin();
    });
    addTouchButton(panel, 'Play Idle', () ->
    {
      if (swagChar != null) playTouchAnimation(swagChar.hasAnimation('danceLeft') ? 'danceLeft' : 'idle');
    });
    final arrows = new HBox();
    panel.addComponent(arrows);
    for (item in [{text: '←', anim: 'singLEFT'}, {text: '↓', anim: 'singDOWN'}, {text: '↑', anim: 'singUP'}, {text: '→', anim: 'singRIGHT'}])
      addTouchButton(arrows, item.text, playTouchAnimation.bind(item.anim));
    touchStatus = addTouchLabel(panel, 'Drag to move the camera.');
    touchStatus.percentWidth = 100;
    touchStatus.wordWrap = true;
  }

  function resizeTouchPanel():Void
  {
    if (offsetEditorDialog != null)
      offsetEditorDialog.height = Math.min(500, FlxG.height / haxe.ui.Toolkit.scaleY - 32);
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    resizeTouchPanel();
  }

  function overTouchControls(x:Float, y:Float):Bool
  {
    final uiX = x / haxe.ui.Toolkit.scaleX;
    final uiY = y / haxe.ui.Toolkit.scaleY;
    return (offsetEditorDialog.visible && hudCam.visible
        && (offsetEditorDialog.hitTest(uiX, uiY) || Screen.instance.hasSolidComponentUnderPoint(uiX, uiY)))
      || (mobileBackButton != null && x >= mobileBackButton.x && x <= mobileBackButton.x + mobileBackButton.width
        && y >= mobileBackButton.y && y <= mobileBackButton.y + mobileBackButton.height);
  }

  function handleFingerDrag(pinching:Bool):Void
  {
    if (pinching)
    {
      touchDrag.cancel();
      return;
    }
    for (touch in FlxG.touches.list)
    {
      if (!touch.pressed) continue;
      if (touchDrag.finger == null && touch.justPressed && !overTouchControls(touch.gameX, touch.gameY))
      {
        touchDrag.begin(touch.touchPointID, touch.gameX, touch.gameY, fingerEdit && curView == ANIMATIONS && swagChar != null);
        final offsets = swagChar?.animOffsets;
        fingerOffsetX = offsets == null ? 0 : offsets[0];
        fingerOffsetY = offsets == null ? 0 : offsets[1];
      }
      if (touch.touchPointID != touchDrag.finger) continue;
      final delta = touchDrag.move(touch.touchPointID, touch.gameX, touch.gameY, FlxG.camera.zoom, fingerSpeed);
      if (delta == null) return;
      if (delta.edit && swagChar != null)
      {
        fingerOffsetX += delta.x;
        fingerOffsetY += delta.y;
        final x = Math.round(fingerOffsetX);
        final y = Math.round(fingerOffsetY);
        if (swagChar.animOffsets[0] == x && swagChar.animOffsets[1] == y) return;
        swagChar.animOffsets = [x, y];
        swagChar.animationOffsets.set(swagChar.getCurrentAnimation(), swagChar.animOffsets);
        txtOffsetShit.text = 'Offset: ' + swagChar.animOffsets;
        txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;
      }
      else if (!delta.edit) FlxG.camera.scroll.add(delta.x, delta.y);
      return;
    }
    touchDrag.cancel();
  }

  function showAnimationView():Void
  {
    if (curView == ANIMATIONS) return;
    final view = offsetEditorDialog.findComponent('swapper', DropDown);
    view.selectedIndex = 1;
    curView = ANIMATIONS;
    if (swagChar != null) FlxG.camera.focusOn(swagChar.getMidpoint(FlxPoint.weak()));
  }

  function playTouchAnimation(name:String):Void
  {
    if (swagChar == null || !swagChar.hasAnimation(name)) return;
    showAnimationView();
    offsetAnimationDropdown.selectItemBy(item -> item.id == name);
    playCharacterAnimation(name, true);
  }

  function zoomPreview(factor:Float):Void
  {
    FlxG.camera.zoom = flixel.math.FlxMath.bound(FlxG.camera.zoom * factor, 0.1, 4);
  }

  function saveCharacterFile():Void
  {
    if (swagChar == null) return;
    FileUtil.saveFile('Save Character', haxe.io.Bytes.ofString(buildOutputStringNew()), [FileUtil.FILE_FILTER_JSON], _ ->
    {
      if (!editorClosed) touchStatus.text = 'Character saved.';
    }, null, haxe.io.Path.withoutDirectory(swagChar.characterId) + '.json');
  }

  function loadCharacterFile():Void
  {
    FileUtil.browseForFile('Load Character', [FileUtil.FILE_FILTER_JSON], file ->
    {
      if (editorClosed) return;
      var id = file.name;
      #if android
      if (StringTools.startsWith(file.fullPath, 'content://'))
      {
        final displayName = funkin.external.android.JNIUtil.createStaticMethod('funkin/util/DocumentUtil', 'getDisplayName',
          '(Ljava/lang/String;)Ljava/lang/String;');
        final name:Null<String> = displayName == null ? null : displayName(file.fullPath);
        if (name != null) id = haxe.io.Path.withoutExtension(name);
      }
      #end
      var preview:BaseCharacter = null;
      var onion:BaseCharacter = null;
      try
      {
        final parser = new json2object.JsonParser<CharacterData>({ignoreUnknownVariables: false});
        parser.fromJson(SerializerUtil.sanitizeJSON(file.bytes.toString()), file.name);
        final data = parser.errors.length == 0 ? CharacterData.validateCharacterData(id, parser.value) : null;
        if (data == null) throw 'Invalid character JSON.';
        preview = CharacterRegistry.instance.createPreviewCharacter(id, data);
        onion = CharacterRegistry.instance.createPreviewCharacter(id, data);
      }
      catch (error:Dynamic)
      {
        preview?.destroy();
        onion?.destroy();
        touchStatus.text = Std.string(error);
        return;
      }
      installCharacterPreview(preview, onion);
      showAnimationView();
      FlxG.camera.focusOn(swagChar.getMidpoint(FlxPoint.weak()));
      touchStatus.text = 'Loaded ' + id + '.';
    }, null, null, error ->
    {
      if (!editorClosed) touchStatus.text = error;
    });
  }

  static function addTouchButton(parent:haxe.ui.core.Component, text:String, run:Void->Void):Void
  {
    final control = new Button();
    control.text = text;
    control.height = 39;
    control.onClick = _ -> run();
    parent.addComponent(control);
  }

  static function addTouchLabel(parent:VBox, text:String):Label
  {
    final control = new Label();
    control.text = text;
    parent.addComponent(control);
    return control;
  }

  static function addTouchToggle(parent:VBox, text:String, selected:Bool, change:Bool->Void):CheckBox
  {
    final control = new CheckBox();
    control.text = text;
    control.height = 35;
    control.selected = selected;
    control.onChange = _ -> change(control.selected);
    parent.addComponent(control);
    return control;
  }
  #end

  function handleTrackpadScroll():Void
  {
    final dx = FlxG.mouse.deltaWheel.x;
    final dy = FlxG.mouse.deltaWheel.y;
    if (!Math.isFinite(dx) || !Math.isFinite(dy) || (dx == 0 && dy == 0)) return;
    if (FlxG.keys.pressed.CONTROL)
    {
      final zoomFactor = flixel.math.FlxMath.bound(Math.exp(dy / 10), 0.75, 1.25);
      FlxG.camera.zoom = flixel.math.FlxMath.bound(FlxG.camera.zoom * zoomFactor, 0.1, 10);
    }
    else
    {
      FlxG.camera.scroll.x += dx * 25 / FlxG.camera.zoom;
      FlxG.camera.scroll.y -= dy * 25 / FlxG.camera.zoom;
    }
  }

  function exitEditor():Void
  {
    resetWindowTitle();
    #if FEATURE_TOUCH_CONTROLS
    FlxG.switchState(() -> new funkin.ui.debug.DebugMenuState());
    #else
    FlxG.switchState(() -> new MainMenuState());
    #end
  }

  function resetWindowTitle():Void
  {
    WindowUtil.setWindowTitle(Constants.TITLE);
  }

  override function destroy()
  {
    #if (mobile && FEATURE_TOUCH_CONTROLS)
    editorClosed = true;
    #end
    mouseOffset.put();
    oldPos.put();
    super.destroy();

    // Hide the mouse cursor on other states.
    Cursor.hide();

    // Reset the sounds used by some playables.
    funkin.play.GameOverSubState.reset();
    funkin.play.PauseSubState.reset();
    funkin.play.Countdown.reset();
  }

  function offsetControls():Void
  {
    if (swagChar == null) return;
    // CTRL + S = Save Character Data
    // CTRL + SHIFT + S = Save Offsets
    // "WINDOWS" key code is the same keycode as COMMAND on mac
    if ((FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.WINDOWS) && FlxG.keys.justPressed.S)
    {
      var outputString = FlxG.keys.pressed.SHIFT ? buildOutputStringOld() : buildOutputStringNew();
      saveOffsets(outputString, FlxG.keys.pressed.SHIFT ? swagChar.characterId + "Offsets.txt" : swagChar.characterId + ".json");
      return;
    }

    if (FlxG.keys.justPressed.RBRACKET || FlxG.keys.justPressed.E)
    {
      if (offsetAnimationDropdown.selectedIndex + 1 <= offsetAnimationDropdown.dataSource.size)
      {
        offsetAnimationDropdown.selectedIndex += 1;
      }
      else
      {
        offsetAnimationDropdown.selectedIndex = 0;
      }
      trace(offsetAnimationDropdown.selectedIndex);
      trace(offsetAnimationDropdown.dataSource.size);
      trace(offsetAnimationDropdown.value);
      trace(currentAnimationName);
      playCharacterAnimation(currentAnimationName, true);
    }
    if (FlxG.keys.justPressed.LBRACKET || FlxG.keys.justPressed.Q)
    {
      if (offsetAnimationDropdown.selectedIndex - 1 >= 0)
      {
        offsetAnimationDropdown.selectedIndex -= 1;
      }
      else
      {
        offsetAnimationDropdown.selectedIndex = offsetAnimationDropdown.dataSource.size - 1;
      }
      playCharacterAnimation(currentAnimationName, true);
    }

    // Keyboards controls for general WASD "movement"
    // modifies the animDrooffsetAnimationDropdownpDownMenu so that it's properly updated and shit
    // and then it's just played and updated from the offsetAnimationDropdown callback, which is set in the loadAnimShit() function probably
    if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S || FlxG.keys.justPressed.D || FlxG.keys.justPressed.A)
    {
      var suffix:String = '';
      var targetLabel:String = '';

      if (FlxG.keys.pressed.SHIFT) suffix = 'miss';

      if (FlxG.keys.justPressed.W) targetLabel = 'singUP$suffix';
      if (FlxG.keys.justPressed.S) targetLabel = 'singDOWN$suffix';
      if (FlxG.keys.justPressed.A) targetLabel = 'singLEFT$suffix';
      if (FlxG.keys.justPressed.D) targetLabel = 'singRIGHT$suffix';

      if (targetLabel != currentAnimationName)
      {
        offsetAnimationDropdown.value = {
          id: targetLabel,
          text: targetLabel
        };

        // Play the new animation if the IDs are different.
        // Override the onion skin.
        playCharacterAnimation(currentAnimationName, true);
      }
      else
      {
        // Replay the current animation if the IDs are the same.
        // Don't override the onion skin.
        playCharacterAnimation(currentAnimationName, false);
      }
    }

    if (FlxG.keys.justPressed.F)
    {
      onionSkinChar.visible = !onionSkinChar.visible;
      #if (mobile && FEATURE_TOUCH_CONTROLS)
      touchOnion.selected = onionSkinChar.visible;
      #end
      if (onionSkinChar.visible) updateOnionSkin();
    }

    if (FlxG.keys.justPressed.G)
    {
      swagChar.flipX = !swagChar.flipX;
      #if (mobile && FEATURE_TOUCH_CONTROLS)
      touchFlip.selected = swagChar.flipX;
      #end
      if (onionSkinChar.visible) updateOnionSkin();
    }

    // Plays the idle animation
    if (FlxG.keys.justPressed.SPACE)
    {
      if (swagChar?.hasAnimation('danceLeft')) offsetAnimationDropdown.value = {
        id: 'danceLeft',
        text: 'danceLeft'
      };
      else
        offsetAnimationDropdown.value = {
          id: 'idle',
          text: 'idle'
        };

      playCharacterAnimation(currentAnimationName, true);
    }

    // Playback the animation
    if (FlxG.keys.justPressed.ENTER)
    {
      playCharacterAnimation(currentAnimationName, false);
    }

    if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
    {
      var animName = currentAnimationName;
      var coolValues:Array<Float> = swagChar.animationOffsets.get(animName).copy();

      var multiplier:Int = 5;

      if (FlxG.keys.pressed.CONTROL) multiplier = 1;

      if (FlxG.keys.pressed.SHIFT) multiplier = 10;

      if (FlxG.keys.justPressed.RIGHT) coolValues[0] -= 1 * multiplier;
      else if (FlxG.keys.justPressed.LEFT) coolValues[0] += 1 * multiplier;
      else if (FlxG.keys.justPressed.UP) coolValues[1] += 1 * multiplier;
      else if (FlxG.keys.justPressed.DOWN) coolValues[1] -= 1 * multiplier;

      swagChar.animationOffsets.set(currentAnimationName, coolValues);
      swagChar.playAnimation(animName);

      txtOffsetShit.text = 'Offset: ' + coolValues;
      txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;

      trace(animName);
    }
  }

  function buildOutputStringOld():String
  {
    var outputString:String = "";

    for (i in swagChar.animationOffsets.keys())
    {
      outputString += i + " " + swagChar.animationOffsets.get(i)[0] + " " + swagChar.animationOffsets.get(i)[1] + "\n";
    }

    outputString.trim();

    return outputString;
  }

  function buildOutputStringNew():String
  {
    final charData:Dynamic = SerializerUtil.fromJSON(SerializerUtil.toJSON(swagChar._data, false));
    if (charData == null) return SerializerUtil.toJSON(swagChar._data, true);
    charData.flipX = swagChar.flipX;
    final characterIsPixel:Bool = charData.isPixel ?? CharacterData.DEFAULT_ISPIXEL;

    if (charData.renderType == CharacterData.DEFAULT_RENDERTYPE) Reflect.deleteField(charData, 'renderType');
    if (isZeroPair(charData.offsets)) Reflect.deleteField(charData, 'offsets');
    if (isZeroPair(charData.cameraOffsets)) Reflect.deleteField(charData, 'cameraOffsets');

    final healthIcon = charData.healthIcon;
    if (healthIcon != null)
    {
      if (healthIcon.id == swagChar.characterId) Reflect.deleteField(healthIcon, 'id');
      if (healthIcon.shouldBop == CharacterData.DEFAULT_SHOULDBOP) Reflect.deleteField(healthIcon, 'shouldBop');
      if (healthIcon.scale == CharacterData.DEFAULT_SCALE) Reflect.deleteField(healthIcon, 'scale');
      if (healthIcon.flipX == CharacterData.DEFAULT_FLIPX) Reflect.deleteField(healthIcon, 'flipX');
      if (healthIcon.isPixel == characterIsPixel) Reflect.deleteField(healthIcon, 'isPixel');
      if (isZeroPair(healthIcon.offsets)) Reflect.deleteField(healthIcon, 'offsets');
      if (Reflect.fields(healthIcon).length == 0) Reflect.deleteField(charData, 'healthIcon');
    }

    if (charData.startingAnimation == CharacterData.DEFAULT_STARTINGANIM) Reflect.deleteField(charData, 'startingAnimation');
    if (charData.scale == CharacterData.DEFAULT_SCALE) Reflect.deleteField(charData, 'scale');
    if (charData.isPixel == CharacterData.DEFAULT_ISPIXEL) Reflect.deleteField(charData, 'isPixel');
    if (charData.danceEvery == CharacterData.DEFAULT_DANCEEVERY) Reflect.deleteField(charData, 'danceEvery');
    if (charData.singTime == CharacterData.DEFAULT_SINGTIME) Reflect.deleteField(charData, 'singTime');
    if (charData.flipX == CharacterData.DEFAULT_FLIPX) Reflect.deleteField(charData, 'flipX');
    if (charData.applyStageMatrix == CharacterData.DEFAULT_APPLYSTAGEMATRIX) Reflect.deleteField(charData, 'applyStageMatrix');
    if (hasDefaultAtlasSettings(charData.atlasSettings)) Reflect.deleteField(charData, 'atlasSettings');

    for (charDataAnim in (cast charData.animations:Array<Dynamic>))
    {
      var animName:String = charDataAnim.name;
      charDataAnim.offsets = swagChar.animationOffsets.get(animName);

      if (charDataAnim.animType == CharacterData.DEFAULT_ANIMTYPE) Reflect.deleteField(charDataAnim, 'animType');
      if (charDataAnim.frameRate == CharacterData.DEFAULT_FRAMERATE) Reflect.deleteField(charDataAnim, 'frameRate');
      if (isZeroPair(charDataAnim.offsets)) Reflect.deleteField(charDataAnim, 'offsets');
      if (charDataAnim.looped == CharacterData.DEFAULT_LOOP) Reflect.deleteField(charDataAnim, 'looped');
      if (charDataAnim.flipX == CharacterData.DEFAULT_FLIPX) Reflect.deleteField(charDataAnim, 'flipX');
      if (charDataAnim.flipY == CharacterData.DEFAULT_FLIPY) Reflect.deleteField(charDataAnim, 'flipY');
    }

    return SerializerUtil.toJSON(charData, true);
  }

  static function isZeroPair(value:Dynamic):Bool
  {
    return value != null && value.length == 2 && value[0] == 0 && value[1] == 0;
  }

  static function hasDefaultAtlasSettings(value:Dynamic):Bool
  {
    if (value == null) return true;

    return Reflect.field(value, 'swfMode') == true
      && Reflect.field(value, 'cacheOnLoad') == false
      && Reflect.field(value, 'filterQuality') == 1
      && Reflect.field(value, 'applyStageMatrix') == false
      && Reflect.field(value, 'useRenderTexture') == false;
  }

  var swagChar:BaseCharacter;

  /**
   * Called when animation dropdown is changed!
   */
  function loadAnimShit(char:String)
  {
    final registry = CharacterRegistry.instance;
    final preview = registry.fetchEntry(char, {debug: true});
    final onion = registry.fetchEntry(char, {debug: true});
    if (preview == null || preview.frames == null || onion == null)
    {
      preview?.destroy();
      onion?.destroy();
      trace('ERROR: Failed to load character ${char}!');
      return;
    }
    installCharacterPreview(preview, onion);
  }

  function installCharacterPreview(preview:BaseCharacter, onion:BaseCharacter):Void
  {
    if (swagChar != null)
    {
      offsetView.remove(swagChar);
      swagChar.destroy();
    }

    if (onionSkinChar != null)
    {
      offsetView.remove(onionSkinChar);
      onionSkinChar.destroy();
    }

    swagChar = preview;
    swagChar.x = 100;
    swagChar.y = 100;

    onionSkinChar = onion;
    onionSkinChar.x = swagChar.x;
    onionSkinChar.y = swagChar.y;

    // Enable `useRenderTexture` for texture atlas sprites so the alpha renders properly for them.
    // This doesn't do anything for sparrows, don't worry!
    onionSkinChar.useRenderTexture = true;
    #if (mobile && FEATURE_TOUCH_CONTROLS)
    if (touchOnion != null) onionSkinChar.visible = touchOnion.selected;
    if (touchFlip != null) touchFlip.selected = swagChar.flipX;
    #end

    offsetView.add(onionSkinChar);
    offsetView.add(swagChar);

    updateOnionSkin();
    generateOutlines(swagChar.frames.frames);
    bf.pixels = swagChar.pixels;

    clearInfo();
    addInfo(swagChar._data.assetPath, "");
    addInfo('Width', bf.width);
    addInfo('Height', bf.height);

    characterAnimNames = [];

    for (i in swagChar.animationOffsets.keys())
    {
      characterAnimNames.push(i);
    }

    offsetAnimationDropdown.dataSource.clear();

    for (charAnim in characterAnimNames)
    {
      offsetAnimationDropdown.dataSource.add({
        id: charAnim,
        text: charAnim
      });
    }

    offsetAnimationDropdown.selectedIndex = 0;

    trace('Added ${offsetAnimationDropdown.dataSource.size} animations to HaxeUI dropdown');

    offsetAnimationDropdown.onChange = function(event:UIEvent)
    {
      if (event.data != null)
      {
        trace('Selected animation ${event.data.id}');
        playCharacterAnimation(event.data.id, true);
      }
    }

    txtOffsetShit.text = 'Offset: ' + swagChar.animOffsets;
    txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;
    dropDownSetup = true;
  }

  private var characterAnimNames:Array<String>;

  function playCharacterAnimation(str:String, setOnionSkin:Bool = true)
  {
    if (setOnionSkin) updateOnionSkin();

    // var animName = characterAnimNames[Std.parseInt(str)];
    var animName = str;
    swagChar.playAnimation(animName, true); // trace();

    txtOffsetShit.text = 'Offset: ' + swagChar.animOffsets;
    txtOffsetShit.y = FlxG.height - 20 - txtOffsetShit.height;
  }

  var _file:FileReference;

  function saveOffsets(saveString:String, fileName:String)
  {
    if ((saveString != null) && (saveString.length > 0))
    {
      _file = new FileReference();
      _file.addEventListener(Event.COMPLETE, onSaveComplete);
      _file.addEventListener(Event.CANCEL, onSaveCancel);
      _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
      _file.save(saveString, fileName);
    }
  }

  function onSaveComplete(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
    FlxG.log.notice("Successfully saved LEVEL DATA.");
  }

  /**
   * Called when the save file dialog is cancelled.
   */
  function onSaveCancel(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
  }

  /**
   * Called if there is an error while saving the gameplay recording.
   */
  function onSaveError(_):Void
  {
    _file.removeEventListener(Event.COMPLETE, onSaveComplete);
    _file.removeEventListener(Event.CANCEL, onSaveCancel);
    _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    _file = null;
    FlxG.log.error("Problem saving Level data");
  }
}

enum abstract ANIMDEBUGVIEW(String)
{
  var SPRITESHEET;
  var ANIMATIONS;
}
#end
