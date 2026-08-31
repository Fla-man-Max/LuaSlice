package funkin.ui.options;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.ui.Page;
#if FEATURE_TOUCH_CONTROLS
import funkin.util.TouchUtil;
#end
import polymod.Polymod.ModMetadata;

class ModMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var grpMods:FlxTypedGroup<ModMenuItem>;
  var detectedMods:Array<ModMetadata> = [];
  var curSelected:Int = 0;

  public function new():Void
  {
    super();

    grpMods = new FlxTypedGroup<ModMenuItem>();
    add(grpMods);
    refreshModList();
  }

  override function update(elapsed:Float):Void
  {
    if (FlxG.keys.justPressed.R) refreshModList();

    if (detectedMods.length > 0)
    {
      if (controls.UI_UP_P) changeSelection(-1);
      if (controls.UI_DOWN_P) changeSelection(1);
      if (controls.ACCEPT_P || FlxG.keys.justPressed.SPACE) toggleSelected();

      if (FlxG.keys.justPressed.I && curSelected > 0) moveSelected(-1);
      if (FlxG.keys.justPressed.K && curSelected < detectedMods.length - 1) moveSelected(1);

      #if FEATURE_TOUCH_CONTROLS
      for (index in 0...grpMods.members.length)
      {
        final item = grpMods.members[index];
        if (item != null && TouchUtil.pressAction(item, item.camera, false))
        {
          curSelected = index;
          updateSelection();
          toggleSelected();
          break;
        }
      }
      #end
    }

    super.update(elapsed);
  }

  function changeSelection(change:Int):Void
  {
    if (detectedMods.length == 0) return;

    curSelected = (curSelected + change + detectedMods.length) % detectedMods.length;
    updateSelection();
  }

  function updateSelection():Void
  {
    for (index in 0...grpMods.members.length)
    {
      final item = grpMods.members[index];
      if (item != null) item.color = index == curSelected ? FlxColor.YELLOW : FlxColor.WHITE;
    }
  }

  function toggleSelected():Void
  {
    final item = grpMods.members[curSelected];
    if (item != null) item.modEnabled = !item.modEnabled;
  }

  function moveSelected(change:Int):Void
  {
    final nextIndex = curSelected + change;
    if (nextIndex < 0 || nextIndex >= detectedMods.length) return;

    final mod = detectedMods[curSelected];
    detectedMods[curSelected] = detectedMods[nextIndex];
    detectedMods[nextIndex] = mod;

    final item = grpMods.members[curSelected];
    grpMods.members[curSelected] = grpMods.members[nextIndex];
    grpMods.members[nextIndex] = item;
    curSelected = nextIndex;

    organizeByY();
    updateSelection();
  }

  function refreshModList():Void
  {
    grpMods.clear();
    detectedMods = [];

    #if sys
    detectedMods = PolymodHandler.getAllMods();
    final enabledDirs = Save.instance.enabledModDirs.value;

    detectedMods.sort((a, b) ->
    {
      final aIndex = enabledDirs.indexOf(a.dirName);
      final bIndex = enabledDirs.indexOf(b.dirName);
      if (aIndex >= 0 && bIndex >= 0) return aIndex - bIndex;
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return Reflect.compare(a.title ?? a.id, b.title ?? b.id);
    });

    for (index in 0...detectedMods.length)
    {
      final mod = detectedMods[index];
      final item = new ModMenuItem(0, 10 + 40 * index, 0, mod.title ?? mod.id, 32);
      item.modDir = mod.dirName;
      item.modEnabled = enabledDirs.contains(mod.dirName);
      grpMods.add(item);
    }
    #end

    curSelected = 0;
    updateSelection();
  }

  function organizeByY():Void
  {
    for (index in 0...grpMods.members.length)
    {
      final item = grpMods.members[index];
      if (item != null) item.y = 10 + 40 * index;
    }
  }

  public function applyChanges():Bool
  {
    final enabledDirs:Array<String> = [];
    for (item in grpMods.members)
    {
      if (item != null && item.modEnabled) enabledDirs.push(item.modDir);
    }

    final savedDirs = Save.instance.enabledModDirs.value;
    if (savedDirs.join('\n') == enabledDirs.join('\n')) return false;

    Save.instance.enabledModDirs.value = enabledDirs;
    Save.system.flush();
    return true;
  }
}

class ModMenuItem extends FlxText
{
  public var modEnabled:Bool = false;
  public var modDir:String = '';

  public function new(x:Float, y:Float, width:Float, text:String, size:Int)
  {
    super(x, y, width, text, size);
  }

  override function update(elapsed:Float):Void
  {
    alpha = modEnabled ? 1 : 0.5;
    super.update(elapsed);
  }
}
