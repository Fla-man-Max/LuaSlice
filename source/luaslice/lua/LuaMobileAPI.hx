package luaslice.lua;

#if FEATURE_LUA_SCRIPTS

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxState;
import flixel.input.touch.FlxTouch;
import flixel.util.FlxColor;
import haxe.ds.StringMap;

class LuaMobileAPI
{
    public static var buttons:StringMap<FlxSprite> = new StringMap();

    public static var camera:FlxCamera = null;

    public static var enabled:Bool = true;

    public static var alpha:Float = 0.65;

    public static function isMobile():Bool
    {
        #if mobile
        return true;
        #else
        return false;
        #end
    }

    public static function createButton(
        tag:String,
        x:Float,
        y:Float,
        width:Int = 100,
        height:Int = 100,
        color:Int = 0xFFFFFFFF
    ):Bool
    {
        if (tag == null || tag.length == 0)
            return false;

        if (buttons.exists(tag))
            removeButton(tag);

        var button = new FlxSprite(x, y);

        button.makeGraphic(
            Std.int(Math.max(1, width)),
            Std.int(Math.max(1, height)),
            color
        );

        button.alpha = alpha;
        button.scrollFactor.set(0, 0);

        if (camera != null)
            button.cameras = [camera];

        if (FlxG.state == null)
        {
            button.destroy();
            return false;
        }

        FlxG.state.add(button);

        buttons.set(tag, button);

        return true;
    }

    public static function removeButton(tag:String):Bool
    {
        if (!buttons.exists(tag))
            return false;

        var button = buttons.get(tag);

        if (button != null)
        {
            if (FlxG.state != null)
                FlxG.state.remove(button, true);

            button.destroy();
        }

        buttons.remove(tag);

        return true;
    }

    public static function removeAll():Void
    {
        var names:Array<String> = [];

        for (tag in buttons.keys())
            names.push(tag);

        for (tag in names)
            removeButton(tag);
    }

    public static function exists(tag:String):Bool
    {
        return buttons.exists(tag);
    }

    public static function setVisible(
        tag:String,
        visible:Bool
    ):Bool
    {
        var button = buttons.get(tag);

        if (button == null)
            return false;

        button.visible = visible;

        return true;
    }

    public static function setAlpha(
        tag:String,
        value:Float
    ):Bool
    {
        var button = buttons.get(tag);

        if (button == null)
            return false;

        button.alpha = Math.max(0, Math.min(1, value));

        return true;
    }

    public static function setPosition(
        tag:String,
        x:Float,
        y:Float
    ):Bool
    {
        var button = buttons.get(tag);

        if (button == null)
            return false;

        button.setPosition(x, y);

        return true;
    }

    public static function setSize(
        tag:String,
        width:Int,
        height:Int
    ):Bool
    {
        var button = buttons.get(tag);

        if (button == null)
            return false;

        button.setGraphicSize(
            Std.int(Math.max(1, width)),
            Std.int(Math.max(1, height))
        );

        button.updateHitbox();

        return true;
    }

    public static function setCamera(
        tag:String,
        target:FlxCamera
    ):Bool
    {
        var button = buttons.get(tag);

        if (button == null || target == null)
            return false;

        button.cameras = [target];

        return true;
    }

    public static function pressed(tag:String):Bool
    {
        return checkTouch(tag, 0);
    }

    public static function justPressed(tag:String):Bool
    {
        return checkTouch(tag, 1);
    }

    public static function justReleased(tag:String):Bool
    {
        return checkTouch(tag, 2);
    }

    static function checkTouch(
        tag:String,
        mode:Int
    ):Bool
    {
        #if FLX_TOUCH
        if (!enabled)
            return false;

        var button = buttons.get(tag);

        if (button == null || !button.visible || !button.exists || !button.active)
            return false;

        for (touch in FlxG.touches.list)
        {
            var valid:Bool = switch (mode)
            {
                case 1: touch.justPressed;
                case 2: touch.justReleased;
                default: touch.pressed;
            };

            if (valid && touch.overlaps(button, button.camera))
                return true;
        }
        #end

        return false;
    }

    public static function register(
        addCallback:(String, Dynamic) -> Void
    ):Void
    {
        addCallback("mobileC", isMobile);

        addCallback("createMobileButton", createButton);
        addCallback("removeMobileButton", removeButton);
        addCallback("removeAllMobileButtons", removeAll);

        addCallback("mobileButtonExists", exists);
        addCallback("setMobileButtonVisible", setVisible);
        addCallback("setMobileButtonAlpha", setAlpha);
        addCallback("setMobileButtonPosition", setPosition);
        addCallback("setMobileButtonSize", setSize);

        addCallback("mobileButtonPressed", pressed);
        addCallback("mobileButtonJustPressed", justPressed);
        addCallback("mobileButtonJustReleased", justReleased);
    }
}

#end
