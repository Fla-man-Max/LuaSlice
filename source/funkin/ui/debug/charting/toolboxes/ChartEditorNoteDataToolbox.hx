package funkin.ui.debug.charting.toolboxes;

#if FEATURE_CHART_EDITOR
import haxe.ui.components.DropDown;
import haxe.ui.components.TextField;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.CheckBox;
import haxe.ui.containers.Grid;
import haxe.ui.core.Component;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.UIEvent;
import funkin.ui.debug.charting.util.ChartEditorDropdowns;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.play.notes.notekind.NoteKind.NoteKindParam;
import funkin.play.notes.notekind.NoteKind.NoteKindParamType;
import funkin.data.song.SongData.NoteParamData;

/**
 * The toolbox which allows modifying information like Note Kind.
 */
@:access(funkin.ui.debug.charting.ChartEditorState) @:build(haxe.ui.ComponentBuilder.build('assets/exclude/data/ui/chart-editor/toolboxes/note-data.xml'))
class ChartEditorNoteDataToolbox extends ChartEditorBaseToolbox
{
  // 100 is the height used in note-data.xml
  static final DIALOG_HEIGHT:Int = 100;
  // toolboxNotesGrid.height + 45
  // this is what i found out by printing this.height and grid.height
  // and then seeing that this.height is 100 and grid.height is 55
  static final HEIGHT_OFFSET:Int = 45;
  // minimizing creates a gray bar the bottom, which would obscure the components,
  // which is why we use an extra offset of 20
  static final MINIMIZE_FIX:Int = 20;

  var toolboxNotesGrid:Grid;
  var toolboxNotesNoteKind:DropDown;
  var toolboxNotesCustomKind:TextField;
  var toolboxNotesParams:Array<ToolboxNoteKindParam> = [];
  var _initializing:Bool = true;

  public function new(chartEditorState2:ChartEditorState)
  {
    super(chartEditorState2);

    initialize();

    this.onDialogClosed = onClose;

    this._initializing = false;
  }

  function onClose(event:UIEvent)
  {
    chartEditorState.menubarItemToggleToolboxNoteData.selected = false;
  }

  function initialize():Void
  {
    toolboxNotesNoteKind.onChange = function(event:UIEvent)
    {
      var noteKind:Null<String> = event?.data?.id ?? null;
      if (noteKind == '') noteKind = null;

      trace('ChartEditorToolboxHandler.buildToolboxNoteDataLayout() - Note kind changed: $noteKind');

      // Edit the note data to place.
      if (noteKind == '~CUSTOM~')
      {
        showCustom();
        chartEditorState.noteKindToPlace = toolboxNotesCustomKind.value;
      }
      else
      {
        hideCustom();
        chartEditorState.noteKindToPlace = noteKind;
      }

      createNoteKindParams(noteKind);

      if (!_initializing && chartEditorState.currentNoteSelection.length > 0)
      {
        for (note in chartEditorState.currentNoteSelection)
        {
          // Edit the note data of any selected notes.
          note.kind = chartEditorState.noteKindToPlace;
          note.params = ChartEditorState.cloneNoteParams(chartEditorState.noteParamsToPlace);

          // update note sprites
          for (noteSprite in chartEditorState.renderedNotes.members)
          {
            if (noteSprite.noteData == note)
            {
              noteSprite.noteStyle = NoteKindManager.getNoteStyleId(note.kind) ?? chartEditorState.currentSongNoteStyle;
              break;
            }
          }

          // update hold note sprites
          for (holdNoteSprite in chartEditorState.renderedHoldNotes.members)
          {
            if (holdNoteSprite.noteData == note)
            {
              holdNoteSprite.noteStyle = NoteKindManager.getNoteStyleId(note.kind) ?? chartEditorState.currentSongNoteStyle;
              break;
            }
          }
        }
        chartEditorState.saveDataDirty = true;
        chartEditorState.noteDisplayDirty = true;
        chartEditorState.notePreviewDirty = true;
      }
    };
    toolboxNotesNoteKind.pauseEvent(UIEvent.CHANGE, true);

    var startingValueNoteKind = ChartEditorDropdowns.populateDropdownWithNoteKinds(toolboxNotesNoteKind, chartEditorState.noteKindToPlace);
    toolboxNotesNoteKind.value = startingValueNoteKind;

    toolboxNotesNoteKind.resumeEvent(UIEvent.CHANGE, true, true);

    toolboxNotesCustomKind.onChange = function(event:UIEvent)
    {
      var customKind:Null<String> = event?.target?.text;
      chartEditorState.noteKindToPlace = customKind;

      if (toolboxNotesNoteKind.value == null || toolboxNotesNoteKind.value.id != '~CUSTOM~') return;

      if (!_initializing && chartEditorState.currentNoteSelection.length > 0)
      {
        // Edit the note data of any selected notes.
        for (note in chartEditorState.currentNoteSelection)
        {
          note.kind = chartEditorState.noteKindToPlace;
        }
        chartEditorState.saveDataDirty = true;
        chartEditorState.noteDisplayDirty = true;
        chartEditorState.notePreviewDirty = true;
      }
    };
    toolboxNotesCustomKind.pauseEvent(UIEvent.CHANGE, true);

    toolboxNotesCustomKind.value = chartEditorState.noteKindToPlace;

    toolboxNotesCustomKind.resumeEvent(UIEvent.CHANGE, true, true);
  }

  override public function refresh():Void
  {
    super.refresh();

    toolboxNotesNoteKind.pauseEvent(UIEvent.CHANGE, true);
    toolboxNotesCustomKind.pauseEvent(UIEvent.CHANGE, true);

    toolboxNotesCustomKind.value = chartEditorState.noteKindToPlace;
    var noteKindEntry = ChartEditorDropdowns.lookupNoteKind(chartEditorState.noteKindToPlace);
    toolboxNotesNoteKind.value = noteKindEntry;
    if (noteKindEntry.id == '~CUSTOM~' && chartEditorState.noteKindToPlace != null)
    {
      showCustom();
    }
    else
    {
      hideCustom();
    }

    createNoteKindParams(chartEditorState.noteKindToPlace);
    toolboxNotesNoteKind.resumeEvent(UIEvent.CHANGE, true, true);
    toolboxNotesCustomKind.resumeEvent(UIEvent.CHANGE, true, true);
  }

  function showCustom():Void
  {
    toolboxNotesCustomKindLabel.hidden = false;
    toolboxNotesCustomKind.hidden = false;
  }

  function hideCustom():Void
  {
    toolboxNotesCustomKindLabel.hidden = true;
    toolboxNotesCustomKind.hidden = true;
  }

  function createNoteKindParams(noteKind:Null<String>):Void
  {
    clearNoteKindParams();

    var setParamsToPlace:Bool = false;
    if (!_initializing)
    {
      for (note in chartEditorState.currentNoteSelection)
      {
        if (note.kind == chartEditorState.noteKindToPlace)
        {
          chartEditorState.noteParamsToPlace = ChartEditorState.cloneNoteParams(note.params);
          setParamsToPlace = true;
          break;
        }
      }
    }

    var noteKindParams:Array<NoteKindParam> = NoteKindManager.getParams(noteKind);
    if (!setParamsToPlace) chartEditorState.noteParamsToPlace = [];

    for (i in 0...noteKindParams.length)
    {
      var param:NoteKindParam = noteKindParams[i];
      var value:Dynamic = param.data?.defaultValue;
      for (savedParam in chartEditorState.noteParamsToPlace)
      {
        if (savedParam.name == param.name)
        {
          value = savedParam.value;
          break;
        }
      }

      var paramLabel:Label = new Label();
      paramLabel.value = param.description;
      paramLabel.verticalAlign = 'center';
      paramLabel.horizontalAlign = 'right';

      var paramComponent:Component = null;

      switch (param.type)
      {
        case NoteKindParamType.INT | NoteKindParamType.FLOAT:
          var paramStepper:NumberStepper = new NumberStepper();
          paramStepper.value = value ?? 0.0;
          paramStepper.percentWidth = 100;
          paramStepper.step = param.data?.step ?? 1.0;

          // this check should be unnecessary but for some reason
          // even when these are null it will set it to 0
          if (param.data?.min != null)
          {
            paramStepper.min = param.data.min;
          }
          if (param.data?.max != null)
          {
            paramStepper.max = param.data.max;
          }
          if (param.data?.precision != null)
          {
            paramStepper.precision = param.data.precision;
          }
          paramComponent = paramStepper;

        case NoteKindParamType.STRING:
          var paramTextField:TextField = new TextField();
          paramTextField.value = value ?? '';
          paramTextField.percentWidth = 100;
          paramComponent = paramTextField;

        case NoteKindParamType.BOOL:
          var paramCheckBox:CheckBox = new CheckBox();
          var selected:Bool = false;
          if (Std.isOfType(value, Bool)) selected = cast value;
          else if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) selected = value != 0;
          else if (Std.isOfType(value, String))
          {
            var text:String = StringTools.trim(cast value).toLowerCase();
            selected = text == '1' || text == 'true';
          }
          paramCheckBox.selected = selected;
          paramComponent = paramCheckBox;

        case NoteKindParamType.ENUM:
          var paramDropDown:DropDown = new DropDown();
          paramDropDown.percentWidth = 100;
          paramDropDown.dataSource = new ArrayDataSource();
          var selectedOption:Dynamic = null;
          if (param.data?.options != null)
          {
            for (option in param.data.options)
            {
              paramDropDown.dataSource.add(option);
              if (option.value == value) selectedOption = option;
            }
          }
          if (selectedOption == null && value != null)
          {
            selectedOption = {text: Std.string(value), value: value};
            paramDropDown.dataSource.add(selectedOption);
          }
          paramDropDown.selectedItem = selectedOption;
          paramComponent = paramDropDown;
      }

      if (paramComponent == null)
      {
        continue;
      }
      paramComponent.id = 'noteParam-${param.name}';

      var placedParam:NoteParamData = null;
      for (savedParam in chartEditorState.noteParamsToPlace)
      {
        if (savedParam.name == param.name)
        {
          placedParam = savedParam;
          break;
        }
      }
      if (placedParam == null)
      {
        var initialValue:Dynamic = paramComponent.value;
        if (param.type == NoteKindParamType.ENUM) initialValue = cast(paramComponent, DropDown).selectedItem?.value;
        if (param.type == NoteKindParamType.BOOL) initialValue = cast(paramComponent, CheckBox).selected;
        placedParam = new NoteParamData(param.name, initialValue);
        chartEditorState.noteParamsToPlace.push(placedParam);
      }

      paramComponent.onChange = function(event:UIEvent)
      {
        var changedValue:Dynamic = paramComponent.value;
        if (param.type == NoteKindParamType.ENUM) changedValue = cast(paramComponent, DropDown).selectedItem?.value;
        if (param.type == NoteKindParamType.BOOL) changedValue = cast(paramComponent, CheckBox).selected;
        placedParam.value = changedValue;

        for (note in chartEditorState.currentNoteSelection)
        {
          if (note.kind != chartEditorState.noteKindToPlace) continue;
          var found:Bool = false;
          for (noteParam in note.params)
          {
            if (noteParam.name == param.name)
            {
              noteParam.value = changedValue;
              found = true;
              break;
            }
          }
          if (!found) note.params.push(new NoteParamData(param.name, changedValue));
        }
        chartEditorState.saveDataDirty = true;
        chartEditorState.noteDisplayDirty = true;
        chartEditorState.notePreviewDirty = true;
        chartEditorState.noteTooltipsDirty = true;
      }

      addNoteKindParam(paramLabel, paramComponent);
    }
  }

  function addNoteKindParam(label:Label, component:Component):Void
  {
    toolboxNotesParams.push({label: label, component: component});
    toolboxNotesGrid.addComponent(label);
    toolboxNotesGrid.addComponent(component);

    this.height = Math.max(DIALOG_HEIGHT, DIALOG_HEIGHT - 30 + toolboxNotesParams.length * 30);
  }

  function clearNoteKindParams():Void
  {
    for (param in toolboxNotesParams)
    {
      toolboxNotesGrid.removeComponent(param.component);
      toolboxNotesGrid.removeComponent(param.label);
    }
    toolboxNotesParams = [];
    this.height = DIALOG_HEIGHT;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // current dialog is minimized, dont change the height
    if (this.minimized)
    {
      return;
    }

    var heightToSet:Int = Std.int(Math.max(DIALOG_HEIGHT, (toolboxNotesGrid?.height ?? 50.0) + HEIGHT_OFFSET)) + MINIMIZE_FIX;
    if (this.height != heightToSet)
    {
      this.height = heightToSet;
    }
  }

  public static function build(chartEditorState:ChartEditorState):ChartEditorNoteDataToolbox
  {
    return new ChartEditorNoteDataToolbox(chartEditorState);
  }
}

typedef ToolboxNoteKindParam =
{
  var label:Label;
  var component:Component;
}
#end
