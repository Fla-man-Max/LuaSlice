package funkin.ui.debug.moddebug;

#if (FEATURE_HAXEUI && (windows || android))
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.components.DropDown;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import flixel.FlxCamera;

class ModDebugWindows
{
  static var nextDropDownId:Int = 0;
  final root:VBox;
  final windows:Map<String, CollapsibleDialog> = [];
  final order:Array<CollapsibleDialog> = [];

  public function new(root:VBox)
  {
    this.root = root;
  }

  public function open(title:String, build:VBox->Void):Void
  {
    var dialog = windows.get(title);
    if (dialog == null)
    {
      dialog = new ModDebugWindow();
      dialog.title = title;
      dialog.dialogParent = root;
      dialog.includeInLayout = false;
      dialog.centerDialog = false;
      dialog.destroyOnClose = false;
      dialog.draggable = true;
      dialog.closable = true;
      dialog.registerEvent(MouseEvent.MOUSE_DOWN, _ -> focus(dialog));
      build(dialog.dialogContent);
      windows.set(title, dialog);
      position(dialog, order.length);
    }
    if (dialog.hidden)
    {
      dialog.showDialog(false);
      redraw(dialog);
    }
    focus(dialog);
  }

  function focus(dialog:CollapsibleDialog):Void
  {
    order.remove(dialog);
    order.push(dialog);
    if (dialog.parentComponent == root && root.getComponentAt(root.numComponents - 1) != dialog)
    {
      root.setComponentIndex(dialog, root.numComponents - 1);
      if (root.members.remove(dialog)) root.members.push(dialog);
    }
  }

  public function closeTop():Bool
  {
    var i = order.length;
    while (i > 0)
    {
      var dialog = order[--i];
      if (!dialog.hidden)
      {
        dialog.hideDialog(DialogButton.CANCEL);
        return true;
      }
    }
    return false;
  }

  public function resetPositions():Void
  {
    for (i in 0...order.length) position(order[i], i);
  }

  public static function redraw(component:Component):Void
  {
    invalidateStyles(component);
    component.syncComponentValidation(false);
  }

  public static function bindDropDown(control:DropDown, camera:FlxCamera):Void
  {
    if (control.id == null) control.id = 'mod-debug-dropdown-' + (++nextDropDownId);
    control.registerEvent(UIEvent.OPEN, _ ->
    {
      final roots = Screen.instance.rootComponents;
      final popupId = control.id + '_popup';
      for (i in 0...roots.length)
      {
        if (roots[i].id != popupId) continue;
        roots[i].cameras = [camera];
        if (i > 0 && control.style?.mode == 'mobile' && roots[i - 1].id == 'modal-background')
          roots[i - 1].cameras = [camera];
        break;
      }
    });
  }

  static function invalidateStyles(component:Component):Void
  {
    component.invalidateComponentStyle(true);
    for (child in component.childComponents) invalidateStyles(child);
  }

  static function position(dialog:CollapsibleDialog, index:Int):Void
  {
    dialog.left = 12 + (index % 6) * 28;
    dialog.top = 92 + (index % 6) * 22;
  }
}

private class ModDebugWindow extends CollapsibleDialog
{
  override public function hide():Void
  {
    var parent = dialogParent;
    super.hide();
    if (hidden && parent != null && parentComponent != parent)
      parent.remove(this, true);
  }
}
#end
