package luaslice.lua;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import haxe.ds.StringMap;

class LuaMobileAPI
{
  public final buttons:StringMap<FlxSprite> = new StringMap();
  public var camera:Null<FlxCamera> = null;
  public var enabled:Bool = true;
  public var alpha:Float = 0.65;
  final owners:StringMap<FlxState> = new StringMap();
  var listening:Bool = false;

  public function new() {}

  public static function isMobile():Bool
  {
    return #if mobile true #else false #end;
  }

  public function createButton(tag:String, x:Float, y:Float, width:Int = 100, height:Int = 100, color:Int = 0xFFFFFFFF):Bool
  {
    if (tag == null || tag.length == 0 || !Math.isFinite(x) || !Math.isFinite(y)) return false;
    var owner = FlxG.state;
    if (owner == null) return false;
    removeButton(tag);
    var button = new FlxSprite(x, y);
    button.makeGraphic(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), color);
    button.alpha = Math.isFinite(alpha) ? Math.max(0, Math.min(1, alpha)) : 0.65;
    button.scrollFactor.set(0, 0);
    if (camera != null) button.cameras = [camera];
    owner.add(button);
    owners.set(tag, owner);
    buttons.set(tag, button);
    if (!listening)
    {
      FlxG.signals.preStateSwitch.add(clearBeforeStateSwitch);
      listening = true;
    }
    return true;
  }

  public function removeButton(tag:String):Bool
  {
    if (tag == null || !buttons.exists(tag)) return false;
    var button = buttons.get(tag);
    owners.get(tag)?.remove(button, true);
    button?.destroy();
    buttons.remove(tag);
    owners.remove(tag);
    if (!buttons.iterator().hasNext() && listening)
    {
      FlxG.signals.preStateSwitch.remove(clearBeforeStateSwitch);
      listening = false;
    }
    return true;
  }

  public function removeAll():Bool
  {
    var tags = [for (tag in buttons.keys()) tag];
    for (tag in tags) removeButton(tag);
    return true;
  }

  function clearBeforeStateSwitch():Void
  {
    removeAll();
    camera = null;
  }

  public function exists(tag:String):Bool
  {
    return tag != null && buttons.exists(tag) && buttons.get(tag) != null && buttons.get(tag).exists;
  }

  public function setVisible(tag:String, visible:Bool):Bool
  {
    var button = tag == null ? null : buttons.get(tag);
    if (button == null) return false;
    button.visible = visible;
    return true;
  }

  public function setAlpha(tag:String, value:Float):Bool
  {
    var button = tag == null ? null : buttons.get(tag);
    if (button == null || !Math.isFinite(value)) return false;
    button.alpha = Math.max(0, Math.min(1, value));
    return true;
  }

  public function setPosition(tag:String, x:Float, y:Float):Bool
  {
    var button = tag == null ? null : buttons.get(tag);
    if (button == null || !Math.isFinite(x) || !Math.isFinite(y)) return false;
    button.setPosition(x, y);
    return true;
  }

  public function setSize(tag:String, width:Int, height:Int):Bool
  {
    var button = tag == null ? null : buttons.get(tag);
    if (button == null) return false;
    button.setGraphicSize(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)));
    button.updateHitbox();
    return true;
  }

  public function setCamera(tag:String, target:FlxCamera):Bool
  {
    var button = tag == null ? null : buttons.get(tag);
    if (button == null || target == null) return false;
    button.cameras = [target];
    return true;
  }

  public function pressed(tag:String):Bool { return checkTouch(tag, 0); }
  public function justPressed(tag:String):Bool { return checkTouch(tag, 1); }
  public function justReleased(tag:String):Bool { return checkTouch(tag, 2); }

  function checkTouch(tag:String, mode:Int):Bool
  {
    #if FLX_TOUCH
    if (!enabled || tag == null) return false;
    var button = buttons.get(tag);
    if (button == null || !button.visible || !button.exists || !button.active || button.alpha <= 0) return false;
    if (FlxG.touches == null) return false;
    for (touch in FlxG.touches.list)
    {
      var valid = switch (mode)
      {
        case 1: touch.justPressed;
        case 2: touch.justReleased;
        default: touch.pressed;
      };
      if (valid && touch.overlaps(button, button.camera)) return true;
    }
    #end
    return false;
  }

  public function register(addCallback:(String, Dynamic) -> Void, ?resolveCamera:String -> Null<FlxCamera>):Void
  {
    addCallback('mobileC', isMobile);
    addCallback('createMobileButton', createButton);
    addCallback('removeMobileButton', removeButton);
    addCallback('removeAllMobileButtons', removeAll);
    addCallback('mobileButtonExists', exists);
    addCallback('setMobileButtonVisible', setVisible);
    addCallback('setMobileButtonAlpha', setAlpha);
    addCallback('setMobileButtonPosition', setPosition);
    addCallback('setMobileButtonSize', setSize);
    addCallback('setMobileButtonCamera', (tag:String, name:String = 'hud') -> setCamera(tag, resolveCamera == null ? FlxG.camera : resolveCamera(name)));
    addCallback('mobileButtonPressed', pressed);
    addCallback('mobileButtonJustPressed', justPressed);
    addCallback('mobileButtonJustReleased', justReleased);
    addCallback('mobileTouchSupported', () -> #if FLX_TOUCH true #else false #end);
  }
}
#end
