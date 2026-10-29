package funkin.ui.debug.charting.dialogs;

#if FEATURE_CHART_EDITOR
import haxe.ui.components.Button;
import haxe.ui.containers.Grid;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.core.Screen;
import haxe.ui.backend.DialogBase;
import haxe.ui.actions.ActionManager;
import haxe.ui.actions.ActionType;
import haxe.ui.events.ActionEvent;
import haxe.ui.containers.dialogs.Dialog.DialogEvent;

typedef ChartTouchMenuAction =
{
  var text:String;
  var enabled:Bool;
  var run:Void->Void;
}

@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorTouchContextMenu extends DialogBase
{
  var chosen:Bool = false;
  public var onDialogClosed:Null<DialogEvent->Void>;

  public function new(state:ChartEditorState, heading:String, actions:Array<ChartTouchMenuAction>)
  {
    super();
    addClass('dialog');
    closable = true;
    destroyOnClose = true;
    registerEvent(DialogEvent.DIALOG_CLOSED, event ->
    {
      state.isHaxeUIDialogOpen = false;
      if (onDialogClosed != null) onDialogClosed(event);
    });
    ActionManager.instance.registerEvent(ActionEvent.ACTION_START, onAction);
    title = heading;
    width = Math.min(460, Screen.instance.width - 24);

    var scroller = new ScrollView();
    scroller.percentWidth = 100;
    scroller.height = Math.min(360, Screen.instance.height - 120);
    var grid = new Grid();
    grid.columns = 2;
    grid.percentWidth = 100;
    for (action in actions)
    {
      var button = new Button();
      button.text = action.text;
      button.percentWidth = 50;
      button.height = 44;
      button.disabled = !action.enabled;
      var armed = false;
      button.registerEvent(haxe.ui.events.MouseEvent.MOUSE_DOWN, _ -> armed = true);
      button.onClick = _ ->
      {
        if (chosen || !armed || !action.enabled) return;
        chosen = true;
        hideDialog(DialogButton.APPLY);
        action.run();
      };
      grid.addComponent(button);
    }
    scroller.addComponent(grid);
    addComponent(scroller);
    buttons = DialogButton.CANCEL;
    state.isHaxeUIDialogOpen = true;
  }

  function onAction(event:ActionEvent):Void
  {
    if (!hidden && closable && (event.action == ActionType.CANCEL || event.action == ActionType.BACK)) hideDialog(DialogButton.CANCEL);
  }

  private override function onDestroy():Void
  {
    ActionManager.instance.unregisterEvent(ActionEvent.ACTION_START, onAction);
    onDialogClosed = null;
    super.onDestroy();
  }
}
#end
