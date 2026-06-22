package funkin.scripting;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import funkin.Paths;
import funkin.play.PlayState;
#end

#if FEATURE_LUA_SCRIPTS
typedef LuaMenuData =
{
  var group:FlxTypedGroup<FlxBasic>;
  var items:Array<String>;
  var selected:Int;
  var normalColor:FlxColor;
  var selectedColor:FlxColor;
  var itemSprites:Array<FlxSprite>;
  var mode:String;
}
#end

class LuaMenusManager
{
  #if FEATURE_LUA_SCRIPTS
  var owner:LuaScriptManager;
  var menus:Map<String, LuaMenuData> = [];

  public function new(owner:LuaScriptManager)
  {
    this.owner = owner;
  }

  public function createMenu(tag:String, items:Array<String>, x:Float, y:Float, width:Float, camera:String, normalColor:FlxColor, selectedColor:FlxColor):Bool
  {
    var targetState = FlxG.state;
    if (tag == '' || items.length == 0 || targetState == null) return false;

    removeMenu(tag);

    var group = new FlxTypedGroup<FlxBasic>();
    var resolvedCamera = resolveCamera(camera);

    for (i in 0...items.length)
    {
      var item = new FlxText(x, y + (i * 34), width, items[i], 28);
      item.setFormat(null, 28, normalColor, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      item.scrollFactor.set();
      if (resolvedCamera != null) item.cameras = [resolvedCamera];
      group.add(item);
    }

    targetState.add(group);
    menus.set(tag, {
      group: group,
      items: items,
      selected: 0,
      normalColor: normalColor,
      selectedColor: selectedColor,
      itemSprites: [],
      mode: 'text'
    });
    refreshMenu(tag);
    return true;
  }

  public function createImageMenu(tag:String, items:Array<String>, x:Float, y:Float, spacing:Float, camera:String, config:Dynamic):Bool
  {
    var targetState = FlxG.state;
    if (tag == '' || items.length == 0 || targetState == null) return false;

    removeMenu(tag);

    var group = new FlxTypedGroup<FlxBasic>();
    var resolvedCamera = resolveCamera(camera);

    var bgColor = readColorField(config, 'backgroundColor', FlxColor.TRANSPARENT);
    if (bgColor != FlxColor.TRANSPARENT)
    {
      var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, bgColor);
      bg.scrollFactor.set();
      if (resolvedCamera != null) bg.cameras = [resolvedCamera];
      group.add(bg);
    }

    var bgPath = readStringField(config, 'backgroundImage', '');
    if (bgPath != '')
    {
      var bgImage = new FlxSprite().loadGraphic(Paths.image(cleanAssetPath(bgPath)));
      bgImage.scrollFactor.set();
      bgImage.screenCenter();
      if (resolvedCamera != null) bgImage.cameras = [resolvedCamera];
      group.add(bgImage);
    }

    var itemSprites:Array<FlxSprite> = [];
    for (i in 0...items.length)
    {
      var itemName = items[i];
      var itemConfig = readObjectField(config, itemName) ?? config;
      var assetPath = cleanAssetPath(readStringField(itemConfig, 'assetPath', 'mainmenu/storymode'));
      var item = new FlxSprite(x, y + (i * spacing));
      item.frames = Paths.getSparrowAtlas(assetPath);
      item.animation.addByPrefix('idle', readAnimPrefix(itemConfig, 'idle', '${itemName} idle'), 24, true);
      item.animation.addByPrefix('selected', readAnimPrefix(itemConfig, 'selected', '${itemName} selected'), 24, true);
      item.scale.set(readFloatField(itemConfig, 'scale', 1), readFloatField(itemConfig, 'scale', 1));
      applyOffsets(item, itemConfig);
      item.scrollFactor.set();
      if (resolvedCamera != null) item.cameras = [resolvedCamera];
      group.add(item);
      itemSprites.push(item);
    }

    targetState.add(group);
    menus.set(tag, {
      group: group,
      items: items,
      selected: 0,
      normalColor: FlxColor.WHITE,
      selectedColor: FlxColor.YELLOW,
      itemSprites: itemSprites,
      mode: 'image'
    });
    refreshMenu(tag);
    return true;
  }

  public function setItems(tag:String, items:Array<String>):Bool
  {
    var menu = menus.get(tag);
    if (menu == null || items.length == 0 || menu.mode != 'text') return false;
    var firstText = firstTextItem(menu);
    var x = firstText != null ? firstText.x : 0;
    var y = firstText != null ? firstText.y : 0;
    var width = firstText != null ? firstText.fieldWidth : FlxG.width;
    var camera = firstText != null && firstText.cameras != null && firstText.cameras.length > 0 ? firstText.cameras[0] : null;

    while (menu.group.members.length > 0)
    {
      var member = menu.group.members[0];
      menu.group.remove(member, true);
      if (member != null) member.destroy();
    }

    menu.items = items;
    menu.selected = 0;
    for (i in 0...items.length)
    {
      var item = new FlxText(x, y + (i * 34), width, items[i], 28);
      item.setFormat(null, 28, menu.normalColor, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      item.scrollFactor.set();
      if (camera != null) item.cameras = [camera];
      menu.group.add(item);
    }
    refreshMenu(tag);
    return true;
  }

  public function setPosition(tag:String, x:Float, y:Float, spacing:Float):Bool
  {
    var menu = menus.get(tag);
    if (menu == null) return false;
    if (menu.mode == 'image')
    {
      for (i in 0...menu.itemSprites.length)
      {
        var item = menu.itemSprites[i];
        if (item != null) item.setPosition(x, y + (i * spacing));
      }
      return true;
    }

    var textIndex = 0;
    for (member in menu.group.members)
    {
      if (member == null || !Std.isOfType(member, FlxText)) continue;
      cast(member, FlxText).setPosition(x, y + (textIndex * spacing));
      textIndex++;
    }
    return true;
  }

  public function showMenu(tag:String):Bool
  {
    var menu = menus.get(tag);
    if (menu == null) return false;
    menu.group.visible = true;
    return true;
  }

  public function hideMenu(tag:String):Bool
  {
    var menu = menus.get(tag);
    if (menu == null) return false;
    menu.group.visible = false;
    return true;
  }

  public function removeMenu(tag:String):Bool
  {
    var menu = menus.get(tag);
    if (menu == null) return false;
    FlxG.state?.remove(menu.group, true);
    menu.group.destroy();
    menus.remove(tag);
    return true;
  }

  public function getSelected(tag:String):Dynamic
  {
    var menu = menus.get(tag);
    if (menu == null) return null;
    return {
      index: menu.selected + 1,
      value: menu.items[menu.selected]
    };
  }

  public function update(elapsed:Float):Void
  {
    for (tag in menus.keys())
    {
      var menu = menus.get(tag);
      if (menu == null || !menu.group.visible) continue;

      var oldSelected = menu.selected;
      if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W) menu.selected--;
      if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S) menu.selected++;
      if (menu.selected < 0) menu.selected = menu.items.length - 1;
      if (menu.selected >= menu.items.length) menu.selected = 0;

      if (oldSelected != menu.selected)
      {
        refreshMenu(tag);
        owner.callHook('onLuaMenuChange', [tag, menu.selected + 1, menu.items[menu.selected]]);
      }

      if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) owner.callHook('onLuaMenuAccept', [tag, menu.selected + 1, menu.items[menu.selected]]);
      if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) owner.callHook('onLuaMenuCancel', [tag]);
    }
  }

  public function clear():Void
  {
    var tags = [for (tag in menus.keys()) tag];
    for (tag in tags) removeMenu(tag);
  }

  function refreshMenu(tag:String):Void
  {
    var menu = menus.get(tag);
    if (menu == null) return;
    for (i in 0...menu.group.members.length)
    {
      var item = menu.group.members[i];
      if (item == null) continue;
      if (Std.isOfType(item, FlxText))
      {
        var text = cast(item, FlxText);
        text.color = i == menu.selected ? menu.selectedColor : menu.normalColor;
        text.text = (i == menu.selected ? '> ' : '  ') + menu.items[i];
      }
    }

    for (i in 0...menu.itemSprites.length)
    {
      var item = menu.itemSprites[i];
      if (item == null) continue;
      item.animation.play(i == menu.selected ? 'selected' : 'idle', true);
      item.alpha = i == menu.selected ? 1.0 : 0.7;
    }
  }

  function resolveCamera(camera:String):Null<flixel.FlxCamera>
  {
    var playState = PlayState.instance;
    if (playState == null) return FlxG.camera;
    return switch (camera)
    {
      case 'hud' | 'camHUD': playState.camHUD;
      case 'cutscene' | 'camCutscene': playState.camCutscene;
      case 'game' | 'camGame': playState.camGame;
      default: FlxG.camera;
    }
  }

  function firstTextItem(menu:LuaMenuData):Null<FlxText>
  {
    for (member in menu.group.members)
    {
      if (member != null && Std.isOfType(member, FlxText)) return cast member;
    }
    return null;
  }

  function cleanAssetPath(path:String):String
  {
    if (StringTools.startsWith(path, 'images:')) return path.substr('images:'.length);
    if (StringTools.startsWith(path, 'images/')) return path.substr('images/'.length);
    return path;
  }

  function readObjectField(value:Dynamic, field:String):Dynamic
  {
    return value == null || !Reflect.hasField(value, field) ? null : Reflect.field(value, field);
  }

  function readStringField(value:Dynamic, field:String, fallback:String):String
  {
    var raw = readObjectField(value, field);
    return raw == null ? fallback : Std.string(raw);
  }

  function readFloatField(value:Dynamic, field:String, fallback:Float):Float
  {
    var raw = readObjectField(value, field);
    if (raw == null) return fallback;
    var parsed = Std.parseFloat(Std.string(raw));
    return Math.isNaN(parsed) ? fallback : parsed;
  }

  function readColorField(value:Dynamic, field:String, fallback:FlxColor):FlxColor
  {
    var raw = readObjectField(value, field);
    if (raw == null) return fallback;
    if (Std.isOfType(raw, Int)) return FlxColor.fromInt(cast raw);
    return FlxColor.fromString(Std.string(raw)) ?? fallback;
  }

  function readAnimPrefix(value:Dynamic, anim:String, fallback:String):String
  {
    var xml = readObjectField(value, 'xml');
    var animData = readObjectField(xml, anim);
    return readStringField(animData, 'prefix', fallback);
  }

  function applyOffsets(item:FlxSprite, config:Dynamic):Void
  {
    var offsets = readObjectField(config, 'offsets');
    if (Std.isOfType(offsets, Array))
    {
      var values:Array<Dynamic> = cast offsets;
      if (values.length >= 2) item.offset.set(Std.parseFloat(Std.string(values[0])), Std.parseFloat(Std.string(values[1])));
    }
  }
  #end
}
