package funkin.ui.debug.stageeditor.toolboxes;

#if FEATURE_STAGE_EDITOR
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextField;
import haxe.ui.containers.ListView;
import haxe.ui.data.ArrayDataSource;
import flixel.graphics.frames.FlxFrame;
import haxe.ui.events.UIEvent;

using StringTools;

@:access(funkin.ui.debug.stageeditor.StageEditorState)
@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/stage-editor/toolboxes/object-anims.xml"))
class StageEditorObjectAnimsToolbox extends StageEditorDefaultToolbox
{
  var linkedObj:StageEditorObject = null;

  var objAnims:DropDown;
  var objAnimName:TextField;
  var objFrameList:ListView;

  var objAnimPrefix:TextField;
  var objAnimIndices:TextField;
  var objAnimLooped:CheckBox;
  var objAnimFlipX:CheckBox;
  var objAnimFlipY:CheckBox;
  var objAnimStart:CheckBox;
  var objAnimFramerate:NumberStepper;
  var objAnimOffsetX:NumberStepper;
  var objAnimOffsetY:NumberStepper;

  var objAnimSave:Button;
  var objAnimDelete:Button;

  override public function new(state:StageEditorState)
  {
    super(state);

    objFrameList.onChange = function(_)
    {
      if (objFrameList.selectedIndex == -1) return;
      objAnimPrefix.text = objFrameList.selectedItem.name;
    }

    objAnims.onChange = function(_)
    {
      var animData = linkedObj?.animDatas[objAnims.selectedItem?.text ?? ""];

      if (linkedObj == null || objAnims.selectedIndex == -1 || animData == null)
      {
        // Reset everything.
        objAnimName.text = objAnimPrefix.text = objAnimIndices.text = "";
        objAnimLooped.selected = objAnimFlipX.selected = objAnimFlipY.selected = objAnimStart.selected = false;
        objAnimFramerate.pos = 24;
        objAnimOffsetX.pos = objAnimOffsetY.pos = 0;
        return;
      }

      // Update the displays.
      objAnimName.text = objAnims.selectedItem.text;
      objAnimPrefix.text = animData.prefix ?? "";
      objAnimIndices.text = (animData.frameIndices?.join(", ") ?? "");

      objAnimLooped.selected = animData.looped ?? false;
      objAnimFlipX.selected = animData.flipX ?? false;
      objAnimFlipY.selected = animData.flipY ?? false;
      objAnimFramerate.pos = animData.frameRate ?? 24;
      objAnimStart.selected = objAnimName.text == linkedObj.startingAnimation;

      var offsets = animData.offsets ?? [0, 0];
      objAnimOffsetX.pos = (offsets[0] ?? 0);
      objAnimOffsetY.pos = (offsets[1] ?? 0);
    }

    objAnimSave.onClick = function(_)
    {
      if (linkedObj == null) return;

      if ((objAnimName.text ?? "") == "")
      {
        state.notifyChange("Animation Saving Error", "The Animation Name is missing.", true);
        return;
      }

      if ((objAnimPrefix.text ?? "") == "")
      {
        state.notifyChange("Animation Saving Error", "The Animation Prefix is missing.", true);
        return;
      }

      addAnimation();
    }

    objAnimDelete.onClick = function(_)
    {
      if (linkedObj == null || linkedObj.animation.getNameList().length <= 0 || objAnims.selectedIndex < 0) return;

      linkedObj.animation.pause();
      linkedObj.animation.stop();
      linkedObj.animation.curAnim = null;

      var daAnim:String = linkedObj.animation.getNameList()[objAnims.selectedIndex];
      if (linkedObj.startingAnimation == daAnim) linkedObj.startingAnimation = "";

      linkedObj.animation.remove(daAnim);
      linkedObj.animDatas.remove(daAnim);
      linkedObj.offset.set();
      state.saved = false;

      state.notifyChange("Animation Deletion Done", "Animation "
        + objAnims.selectedItem.text
        + " has been removed from the Object "
        + linkedObj.name
        + ".");

      updateAnimList();

      objAnims.selectedIndex = objAnims.dataSource.size - 1;
    }

    this.onDialogClosed = onClose;
  }

  function onClose(event:UIEvent)
  {
    stageEditorState.menubarItemWindowObjectAnims.selected = false;
  }

  var previousFrames:Array<String> = [];
  var previousAnims:Array<String> = [];

  override public function refresh()
  {
    linkedObj = stageEditorState.selectedSprite;

    // If the selected object is null, reset the displays.
    if (linkedObj == null)
    {
      updateFrameList();
      updateAnimList();
      objAnims.selectedIndex = -1;
      return;
    }

    // Otherwise, update them accordingly.

    if (previousFrames != [for (f in linkedObj.frames.frames) f.name]) updateFrameList();
    if (previousAnims != linkedObj.animation.getNameList().copy()) updateAnimList();
  }

  function updateFrameList()
  {
    previousFrames = [];
    objFrameList.dataSource = new ArrayDataSource();

    if (linkedObj == null) return;

    for (fname in linkedObj.frames.frames)
    {
      if (fname != null)
      {
        objFrameList.dataSource.add({name: fname.name});
        previousFrames.push(fname.name);
      }
    }
  }

  function updateAnimList()
  {
    objAnims.dataSource.clear();
    previousAnims = [];

    if (linkedObj == null) return;

    for (aname in linkedObj.animation.getNameList())
    {
      objAnims.dataSource.add({text: aname});
      previousAnims.push(aname);
    }

    if (previousAnims.contains(linkedObj.startingAnimation)) objAnims.selectedIndex = previousAnims.indexOf(linkedObj.startingAnimation);
  }

  function addAnimation()
  {
    var animName = (objAnimName.text ?? "").trim();
    var animPrefix = (objAnimPrefix.text ?? "").trim();

    if (animName == "" || animPrefix == "")
    {
      stageEditorState.notifyChange("Animation Saving Error", "Animation name and prefix are required.", true);
      return;
    }

    if (linkedObj.animation.getNameList().contains(animName))
    {
      linkedObj.animation.remove(animName);
      linkedObj.animDatas.remove(animName);
    }

    var indices:Array<Int> = [];

    if ((objAnimIndices.text ?? "") != "")
    {
      var splitter = objAnimIndices.text.replace(" ", "").split(",");

      for (num in splitter)
      {
        if (num == "") continue;

        var index = Std.parseInt(num);
        if (index == null)
        {
          stageEditorState.notifyChange("Animation Saving Error", 'Invalid frame index "$num". Use numbers separated by commas.', true);
          return;
        }

        indices.push(index);
      }
    }

    linkedObj.addAnim(animName, animPrefix, [objAnimOffsetX.pos, objAnimOffsetY.pos], indices,
      Std.int(objAnimFramerate.pos), objAnimLooped.selected, objAnimFlipX.selected, objAnimFlipY.selected);

    if (linkedObj.animation.getByName(animName) == null)
    {
      stageEditorState.notifyChange("Animation Saving Error", "Could not build Animation by the provided Frames.", true);
      return;
    }

    if (objAnimStart.selected) linkedObj.startingAnimation = animName;
    else if (linkedObj.startingAnimation == animName) linkedObj.startingAnimation = "";
    linkedObj.playAnim(animName);
    stageEditorState.saved = false;

    stageEditorState.notifyChange("Animation Saving Done", "Animation " + animName + " has been saved to the Object " + linkedObj.name + ".");
    updateAnimList();

    // Stop the animation after a certain time.
    flixel.util.FlxTimer.wait(StageEditorState.TIME_BEFORE_ANIM_STOP, function()
    {
      if (linkedObj?.animation?.curAnim != null) linkedObj.animation.stop();
    });
  }
}
#end
