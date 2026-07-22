package funkin.ui.debug.charting.toolboxes;

#if FEATURE_CHART_EDITOR
import funkin.play.event.SongEventHelper;
import funkin.play.event.ShaderSongEvent;
import funkin.data.event.SongEventSchema;
import funkin.ui.debug.charting.util.ChartEditorDropdowns;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.Spacer;
import haxe.ui.core.Component;
import funkin.data.event.SongEventRegistry;
import haxe.ui.components.TextField;
import haxe.ui.containers.Box;
import haxe.ui.containers.HBox;
import haxe.ui.containers.VBox;
import haxe.ui.containers.Frame;
import haxe.ui.events.UIEvent;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.containers.Grid;
import haxe.ui.components.Image;
import haxe.ui.components.popups.ColorPickerPopup;
import haxe.ui.Toolkit;
import haxe.ui.backend.ImageData;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.Assets;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.FlxG;
import haxe.io.Path;
import sys.FileSystem;

/**
 * The toolbox which allows modifying information like Song Title, Scroll Speed, Characters/Stages, and starting BPM.
 */
@:access(funkin.ui.debug.charting.ChartEditorState)
@:build(haxe.ui.ComponentBuilder.build("assets/exclude/data/ui/chart-editor/toolboxes/event-data.xml"))
class ChartEditorEventDataToolbox extends ChartEditorBaseToolbox
{
  static final rememberedEventColors:Map<String, Dynamic> = [];

  var toolboxEventsEventKind:DropDown;
  var toolboxEventsDataFrame:Frame;
  var toolboxEventsDataBox:VBox;

  var easeGraphImage:Image;
  var easeDotImage:Image;
  var overlayPreviewImage:Image;
  var overlayPreviewBox:VBox;
  var overlayPreviewSprite:flixel.FlxSprite;
  var overlayPreviewPreviousSprite:flixel.FlxSprite;
  var hudPreviewImage:Image;
  var hudPreviewSprite:flixel.FlxSprite;
  var hudPreviewPreviousSprite:flixel.FlxSprite;
  var hudPreviewBitmap:BitmapData;
  var hudPreviewLayers:Array<BitmapData> = [];
  var overlayPreviewSignature:String = '';
  var shaderValueSliders:Map<String, HorizontalSlider> = [];
  var shaderValueLabels:Map<String, Label> = [];
  var shaderValueScales:Map<String, Float> = [];
  var shaderValueLastDisplays:Map<String, Float> = [];
  var shaderValueEndpointOnly:Map<String, Bool> = [];

  var _easeGraphSprite:Null<flixel.FlxSprite> = null;
  var _easeDotSprites:Array<flixel.FlxSprite> = [];
  var _dotTimer:Null<FlxTimer> = null;
  var _pauseTimer:Null<FlxTimer> = null;
  var _dotIndex:Int = 0;

  static var _dotInterval:Float = 1.0 / 30.0;
  static var _loopPause:Float = 0.15;

  var _initializing:Bool = true;

  /**
   * If `true`, changing the value of the Event Kind dropdown will trigger the `onEventKindChanged` callback,
   * modifying the event kind of all selected events.
   * Set to `false` to safety modify the dropdown directly, without modifying placed events.
   */
  var shouldTriggerOnEventKindChanged(default, set):Bool = true;

  function set_shouldTriggerOnEventKindChanged(value:Bool):Bool
  {
    shouldTriggerOnEventKindChanged = value;

    if (!shouldTriggerOnEventKindChanged)
    {
      toolboxEventsEventKind.pauseEvent(UIEvent.CHANGE, true);
    }
    else
    {
      toolboxEventsEventKind.resumeEvent(UIEvent.CHANGE, true, true);
    }

    return shouldTriggerOnEventKindChanged;
  }

  public function new(chartEditorState2:ChartEditorState)
  {
    super(chartEditorState2);

    initialize();

    this.onDialogClosed = onClose;
    this.registerEvent(UIEvent.DESTROY, _ -> cleanupPreviewResources());

    this._initializing = false;
  }

  function onClose(event:UIEvent)
  {
    chartEditorState.menubarItemToggleToolboxEventData.selected = false;
  }

  function cleanupPreviewResources():Void
  {
    _dotTimer?.cancel();
    _dotTimer?.destroy();
    _pauseTimer?.cancel();
    _pauseTimer?.destroy();
    _dotTimer = null;
    _pauseTimer = null;
    _easeGraphSprite?.destroy();
    _easeGraphSprite = null;
    _easeDotSprites = [];
    hudPreviewSprite?.destroy();
    hudPreviewPreviousSprite?.destroy();
    hudPreviewSprite = null;
    hudPreviewPreviousSprite = null;
    hudPreviewBitmap?.dispose();
    hudPreviewBitmap = null;
    for (layer in hudPreviewLayers)
      layer?.dispose();
    hudPreviewLayers = [];
    overlayPreviewSprite?.destroy();
    overlayPreviewPreviousSprite?.destroy();
    overlayPreviewSprite = null;
    overlayPreviewPreviousSprite = null;
    overlayPreviewImage = null;
    overlayPreviewBox = null;
    hudPreviewImage = null;
    shaderValueSliders.clear();
    shaderValueLabels.clear();
    shaderValueScales.clear();
    shaderValueLastDisplays.clear();
    shaderValueEndpointOnly.clear();
  }

  function initialize():Void
  {
    toolboxEventsEventKind.onChange = onEventKindChanged;
    shouldTriggerOnEventKindChanged = false;

    var startingEventValue = ChartEditorDropdowns.populateDropdownWithSongEvents(toolboxEventsEventKind, chartEditorState.eventKindToPlace);
    trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Building Event toolbox with kind "${startingEventValue}"');
    toolboxEventsEventKind.value = startingEventValue;

    shouldTriggerOnEventKindChanged = true;
  }

  function onEventKindChanged(event:UIEvent):Void
  {
    if (event.data == null)
    {
      trace(' WARNING '.bg_yellow().bold() + ' CHART EDITOR '.bold().bg_bright_yellow() + 'Event toolbox received an invalid UI event.');
      return;
    }

    var eventKind:String = event.data.id;
    var sameEvent:Bool = (eventKind == chartEditorState.eventKindToPlace);

    trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event toolbox changed kind to "$eventKind"');

    // Edit the event data to place.
    chartEditorState.eventKindToPlace = eventKind;

    var schema:SongEventSchema = SongEventRegistry.getEventSchema(eventKind);

    if (schema == null)
    {
      trace(' WARNING '.bold().bg_yellow() + ' Event toolbox attempted to use unknown event kind "$eventKind"');
      return;
    }

    if (!sameEvent) chartEditorState.eventDataToPlace = {};
    buildEventDataFormFromSchema(toolboxEventsDataBox, schema, chartEditorState.eventKindToPlace);

    if (!_initializing && chartEditorState.currentEventSelection.length > 0)
    {
      // Edit the event data of any selected events.
      trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event toolbox MODIFYING events to kind "${chartEditorState.eventKindToPlace}"');
      for (event in chartEditorState.currentEventSelection)
      {
        event.eventKind = chartEditorState.eventKindToPlace;
        event.value = chartEditorState.eventDataToPlace;
      }
      chartEditorState.saveDataDirty = true;
      chartEditorState.noteDisplayDirty = true;
      chartEditorState.notePreviewDirty = true;
    }
  }

  public override function refresh():Void
  {
    super.refresh();

    shouldTriggerOnEventKindChanged = false;

    var newDropdownElement = ChartEditorDropdowns.findDropdownElement(chartEditorState.eventKindToPlace, toolboxEventsEventKind);

    if (newDropdownElement == null)
    {
      final event = SongEventRegistry.getEvent(chartEditorState.eventKindToPlace);
      if (event == null)
      {
        trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event kind "${chartEditorState.eventKindToPlace}" is not registered.');
        shouldTriggerOnEventKindChanged = true;
        return;
      }
      newDropdownElement = {id: event.id, text: event.getTitle()};
      toolboxEventsEventKind.dataSource.add(newDropdownElement);
    }
    if (toolboxEventsEventKind.value != newDropdownElement || lastEventKind != toolboxEventsEventKind.value.id)
    {
      toolboxEventsEventKind.value = newDropdownElement;

      var schema:SongEventSchema = SongEventRegistry.getEventSchema(chartEditorState.eventKindToPlace);
      if (schema == null)
      {
        trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event kind "${chartEditorState.eventKindToPlace}" has no schema for Event toolbox!');
      }
      else
      {
        trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event Toolbox: Kind changed to "${chartEditorState.eventKindToPlace}", rebuilding form...');
        buildEventDataFormFromSchema(toolboxEventsDataBox, schema, chartEditorState.eventKindToPlace);
      }
    }
    else
    {
      trace('ChartEditorEventDataToolbox - Event kind not changed: ${toolboxEventsEventKind.value} == ${newDropdownElement} == ${lastEventKind}');
    }

    var staleFieldIds:Array<String> = [];
    for (pair in chartEditorState.eventDataToPlace.keyValueIterator())
    {
      var fieldId:String = pair.key;
      var value:Null<Dynamic> = pair.value;

      var field:Component = toolboxEventsDataBox.findComponent(fieldId);
      if (field == null)
      {
        staleFieldIds.push(fieldId);
        continue;
      }
      else
      {
        field.pauseEvent(UIEvent.CHANGE, true);
        switch (field)
        {
          case Std.isOfType(_, HorizontalSlider) => true:
            var slider:HorizontalSlider = cast field;
            slider.pos = (Std.parseFloat(Std.string(value)) * (shaderValueScales.get(fieldId) ?? 1.0));
          case Std.isOfType(_, NumberStepper) => true:
            var numberStepper:NumberStepper = cast field;
            numberStepper.value = value;
          case Std.isOfType(_, CheckBox) => true:
            var checkBox:CheckBox = cast field;
            checkBox.selected = value;
          case Std.isOfType(_, ColorPickerPopup) => true:
            var colorPicker:ColorPickerPopup = cast field;
            colorPicker.selectedItem = value;
          case Std.isOfType(_, DropDown) => true:
            var dropDown:DropDown = cast field;
            dropDown.value = value;
          case Std.isOfType(_, TextField) => true:
            var textField:TextField = cast field;
            textField.text = value;
          default:
            throw 'ChartEditorEventDataToolbox - Field "${fieldId}" is of unknown type "${Type.getClassName(Type.getClass(field))}".';
        }
      }
      field.resumeEvent(UIEvent.CHANGE, true, true);
    }
    for (fieldId in staleFieldIds)
      chartEditorState.eventDataToPlace.remove(fieldId);

    shouldTriggerOnEventKindChanged = true;
    updateShaderPropertyChoices();
    updateContextualFieldVisibility();
    updateEasePreview();
    updateOverlayPreview();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (_initializing || minimized || (overlayPreviewImage == null && hudPreviewImage == null)) return;
    final signature = getOverlayPreviewSignature();
    if (signature == overlayPreviewSignature) return;
    updateOverlayPreview();
  }

  var lastEventKind:String = 'unknown';

  function buildEventDataFormFromSchema(target:Box, schema:SongEventSchema, eventKind:String):Void
  {
    trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event Toolbox: Building form from schema ("${eventKind}")...');

    _initializing = true;

    lastEventKind = eventKind ?? 'unknown';

    // Clear the frame.
    target.removeAllComponents();

    recursiveChildAdd(target, schema);

    _initializing = false;
    updateShaderPropertyChoices();
    updateContextualFieldVisibility();
  }

  function recursiveChildAdd(parent:Component, schema:SongEventSchema)
  {
    // Ensure we have a cleared preview reference for rebuilt form
    easeGraphImage = null;
    easeDotImage = null;
    overlayPreviewImage = null;
    overlayPreviewBox = null;
    hudPreviewImage = null;
    hudPreviewSprite?.destroy();
    hudPreviewPreviousSprite?.destroy();
    hudPreviewSprite = null;
    hudPreviewPreviousSprite = null;
    hudPreviewBitmap?.dispose();
    hudPreviewBitmap = null;
    for (layer in hudPreviewLayers)
      layer.dispose();
    hudPreviewLayers = [];
    overlayPreviewSprite?.destroy();
    overlayPreviewPreviousSprite?.destroy();
    overlayPreviewSprite = null;
    overlayPreviewPreviousSprite = null;
    overlayPreviewSignature = '';
    shaderValueSliders.clear();
    shaderValueLabels.clear();
    shaderValueScales.clear();
    shaderValueLastDisplays.clear();
    shaderValueEndpointOnly.clear();
    var _needEasePreview:Bool = false;

    for (field in schema)
    {
      if (field == null) continue;
      final isShaderValue = lastEventKind == 'Shader' && shaderSlotForField(field.name, 'value') > 0;

      if (field.type == COLOR && chartEditorState.eventDataToPlace.get(field.name) == null)
      {
        final remembered = rememberedEventColors.get('${lastEventKind}:${field.name}');
        if (remembered != null) chartEditorState.eventDataToPlace.set(field.name, remembered);
      }

      var hbox:HBox = new HBox();
      hbox.id = '${field.name}-row';
      hbox.percentWidth = 100;
      parent.addComponent(hbox);

      // Add a label for the data field.
      var label:Label = new Label();
      label.id = '${field.name}-label';
      label.text = field.title;
      label.verticalAlign = "center";
      label.percentWidth = 50;
      hbox.addComponent(label);

      // Add an input field for the data field.
      var input:Component;
      switch (field.type)
      {
        case INTEGER:
          var numberStepper:NumberStepper = new NumberStepper();
          numberStepper.id = field.name;
          numberStepper.step = field.step ?? 1.0;
          if (field.min != null) numberStepper.min = field.min;
          if (field.max != null) numberStepper.max = field.max;
          if (field.defaultValue != null) numberStepper.value = field.defaultValue;
          input = numberStepper;
        case FLOAT:
          if (isShaderValue)
          {
            final slider = new HorizontalSlider();
            slider.id = field.name;
            slider.percentWidth = 100;
            slider.min = 0;
            slider.max = 100;
            slider.step = 1;
            slider.precision = 0;
            shaderValueSliders.set(field.name, slider);
            shaderValueScales.set(field.name, 1.0);
            input = slider;
          }
          else
          {
            var numberStepper:NumberStepper = new NumberStepper();
            numberStepper.id = field.name;
            numberStepper.step = field.step ?? 0.1;
            if (field.min != null) numberStepper.min = field.min;
            if (field.max != null) numberStepper.max = field.max;
            if (field.defaultValue != null) numberStepper.value = field.defaultValue;
            input = numberStepper;
          }
        case BOOL:
          var checkBox:CheckBox = new CheckBox();
          checkBox.id = field.name;
          if (field.defaultValue != null) checkBox.selected = field.defaultValue;
          input = checkBox;
        case ENUM:
          var dropDown:DropDown = new DropDown();
          dropDown.id = field.name;
          dropDown.width = 150.0;
          dropDown.dropdownSize = 10;
          dropDown.dropdownWidth = 157;
          dropDown.searchable = true;
          dropDown.dataSource = new ArrayDataSource();

          if (field.keys == null) throw 'Field "${field.name}" is of Enum type but has no keys.';

          // Add entries to the dropdown.

          for (optionName in field.keys.keys())
          {
            var optionValue:Null<Dynamic> = field.keys.get(optionName);
            dropDown.dataSource.add({value: optionValue, text: optionName});
          }

          dropDown.value = field.defaultValue;

          // TODO: Add an option to customize sort.
          dropDown.dataSource.sort('text', ASCENDING);

          input = dropDown;
        case STRING:
          input = new TextField();
          input.id = field.name;
          if (field.defaultValue != null) input.text = field.defaultValue;
        case COLOR:
          var colorPicker = new ColorPickerPopup();
          colorPicker.id = field.name;
          colorPicker.width = 95;
          colorPicker.liveTracking = false;
          if (field.defaultValue != null) colorPicker.selectedItem = field.defaultValue;
          input = colorPicker;
        case FRAME:
          hbox.removeComponent(label, true);

          input = new Frame();
          input.id = field.name;
          input.text = field.title;
          input.percentWidth = 100;
          if (field.collapsible != null)
          {
            var targetFrame:Frame = cast(input, Frame);
            if (targetFrame != null) targetFrame.collapsible = field.collapsible;
          }

          var frameVBox:VBox = new VBox();
          frameVBox.percentWidth = 100;
          input.addComponent(frameVBox);

          if (field.children != null) recursiveChildAdd(frameVBox, new SongEventSchema(field.children));

        default:
          // Unknown type. Display a label that proclaims the type so we can debug it.
          input = new Label();
          input.id = field.name;
          input.text = field.type;
      }

      // Putting in a box so we can add a unit label easily if there is one.
      var inputBox:HBox = new HBox();
      inputBox.percentWidth = 50;
      if (field.type != FRAME)
      {
        if (isShaderValue)
        {
          label.percentWidth = 35;
          inputBox.percentWidth = 65;
          final sliderBox = new VBox();
          sliderBox.percentWidth = 100;
          final valueLabel = new Label();
          valueLabel.id = '${field.name}-display';
          shaderValueLabels.set(field.name, valueLabel);
          final valueRow = new HBox();
          valueRow.percentWidth = 100;
          final valueSpacer = new Spacer();
          valueSpacer.percentWidth = 100;
          sliderBox.addComponent(input);
          valueRow.addComponent(valueSpacer);
          valueRow.addComponent(valueLabel);
          sliderBox.addComponent(valueRow);
          inputBox.addComponent(sliderBox);
        }
        else
        {
          inputBox.addComponent(input);
        }
      }

      if (field.type == ENUM && (field.name == "ease" || field.name == "easeDir"))
      {
        _needEasePreview = true;
      }

      // Add a unit label if applicable.
      if (field.units != null && field.units != "")
      {
        var units:Label = new Label();
        units.text = field.units;
        units.verticalAlign = "center";
        inputBox.addComponent(units);
      }

      hbox.addComponent(field.type == FRAME ? input : inputBox);

      // Ensure chartEditorState.eventDataToPlace reflects default UI values so preview is correct on first open
      if (field.defaultValue != null)
      {
        // Only set if not already present (don't overwrite existing selection data)
        if (chartEditorState.eventDataToPlace.get(field.name) == null)
        {
          chartEditorState.eventDataToPlace.set(field.name, field.defaultValue);
        }
      }

      final storedValue = chartEditorState.eventDataToPlace.get(field.name);
      if (storedValue != null)
      {
        switch (field.type)
        {
          case INTEGER: cast(input, NumberStepper).value = storedValue;
          case FLOAT: if (!isShaderValue) cast(input, NumberStepper).value = storedValue;
          case BOOL: cast(input, CheckBox).selected = storedValue;
          case ENUM: cast(input, DropDown).value = storedValue;
          case STRING: cast(input, TextField).text = Std.string(storedValue);
          case COLOR:
            cast(input, ColorPickerPopup).selectedItem = storedValue;
            rememberedEventColors.set('${lastEventKind}:${field.name}', storedValue);
          default:
        }
      }

      if (lastEventKind == 'Shader' && field.name == 'removeExisting')
      {
        final removeExisting:CheckBox = cast input;
        removeExisting.selected = true;
        removeExisting.disabled = true;
        chartEditorState.eventDataToPlace.set(field.name, true);
      }

      // Update the value of the event data without modifying
      input.pauseEvent(UIEvent.CHANGE, true);
      if (isShaderValue)
      {
        final valueFieldName = field.name;
        final slider = shaderValueSliders.get(valueFieldName);
        if (slider != null)
        {
          slider.onChange = _ -> syncShaderSliderValue(valueFieldName, false);
          slider.onDrag = _ -> syncShaderSliderValue(valueFieldName, true);
          slider.onDragEnd = _ -> syncShaderSliderValue(valueFieldName, false);
          final currentShader = Std.string(chartEditorState.eventDataToPlace.get('shader') ?? '');
          final currentProp = Std.string(chartEditorState.eventDataToPlace.get(shaderSlotField('property', shaderSlotForField(valueFieldName, 'value'))) ?? 'amount');
          updateShaderValueControl(currentShader, currentProp, valueFieldName);
        }
      }
      else
      {
        input.onChange = function(event:UIEvent)
        {
          if (field.type == FRAME) return;

          var value:Any = input.value;
          if (field.type == ENUM)
          {
            var drp:DropDown = cast input;
            value = drp.selectedItem?.value ?? field.defaultValue;
            updateEasePreview();
          }
          else if (field.type == BOOL)
          {
            var chk:CheckBox = cast input;
            value = cast(chk.selected, Null<Bool>);
          }
          else if (field.type == COLOR)
          {
            final picker:ColorPickerPopup = cast input;
            value = getColorPickerValue(picker, field.defaultValue);
            if (value != null) rememberedEventColors.set('${lastEventKind}:${field.name}', value);
          }

          commitEventFieldValue(field.name, value);
        }
      }

      input.resumeEvent(UIEvent.CHANGE, true, true);
    }

    if (_needEasePreview)
    {
      if (easeGraphImage == null)
      {
        easeGraphImage = new Image();
        easeGraphImage.id = "easeGraph";
        easeGraphImage.width = 100;
        easeGraphImage.height = 100;
        easeGraphImage.hidden = true;
        easeGraphImage.verticalAlign = "bottom";
      }
      if (easeDotImage == null)
      {
        easeDotImage = new Image();
        easeDotImage.id = "easeDot";
        easeDotImage.width = 16;
        easeDotImage.height = 100;
        easeDotImage.hidden = true;
        easeDotImage.verticalAlign = "bottom";
      }

      var easeHBox = new HBox();
      easeHBox.percentWidth = 100;
      easeHBox.height = 100;
      easeHBox.verticalAlign = "bottom";

      easeHBox.addComponent(easeGraphImage);
      easeHBox.addComponent(easeDotImage);

      currentEaseHBox = easeHBox;
      currentEaseHBox.hidden = true;
      parent.addComponent(easeHBox);

      updateEasePreview();
    }

    if (lastEventKind == 'Overlay' || lastEventKind == 'HUDFade')
    {
      overlayPreviewBox = new VBox();
      overlayPreviewBox.percentWidth = 100;
      final label = new Label();
      label.text = lastEventKind == 'HUDFade' ? 'HUD Preview' : 'Image Preview';
      overlayPreviewBox.addComponent(label);
      final layerNames = ['HUD-BG', 'HUD-Strumline', 'HUD-Notes', 'HUD-Healthbar', 'HUD-Icons'];
      for (layerName in layerNames)
      {
        final path = Paths.image('ui/chart-editor/HUD/${layerName}');
        if (Assets.exists(path))
        {
          final source = Assets.getBitmapData(path);
          final layer = new BitmapData(160, 90, true, 0x00000000);
          final matrix = new Matrix();
          matrix.scale(160 / source.width, 90 / source.height);
          layer.draw(source, matrix, null, null, null, true);
          hudPreviewLayers.push(layer);
        }
      }
      if (lastEventKind == 'HUDFade')
      {
        hudPreviewImage = new Image();
        hudPreviewImage.width = 160;
        hudPreviewImage.height = 90;
        hudPreviewBitmap = new BitmapData(160, 90, true, 0xFFFFFFFF);
        overlayPreviewBox.addComponent(hudPreviewImage);
      }
      else
      {
        overlayPreviewImage = new Image();
        overlayPreviewImage.width = 160;
        overlayPreviewImage.height = 90;
        overlayPreviewBox.addComponent(overlayPreviewImage);
      }
      parent.addComponent(overlayPreviewBox);
      updateOverlayPreview();
    }
  }

  function getColorPickerValue(picker:ColorPickerPopup, fallback:Dynamic):Dynamic
  {
    final selected:Dynamic = picker.selectedItem ?? fallback;
    if (Std.isOfType(selected, String)) return selected;
    if (selected == null) return fallback;
    final selectedColor:haxe.ui.util.Color = cast selected;
    return selectedColor.toHex();
  }

  function commitEventFieldValue(fieldName:String, value:Dynamic):Void
  {
    trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event Toolbox Form: ${fieldName} = ${value}');
    if (value == null)
      chartEditorState.eventDataToPlace.remove(fieldName);
    else
      chartEditorState.eventDataToPlace.set(fieldName, value);

    final changesLayout = switch (lastEventKind)
    {
      case 'Shader': ['action', 'targetType', 'shader'].contains(fieldName) || shaderSlotForField(fieldName, 'property') > 0;
      case 'Overlay': ['action', 'kind'].contains(fieldName);
      case 'HUDFade': fieldName == 'target';
      case 'PlayAudio', 'StageObjectControl': fieldName == 'action';
      case 'HealthDrain': fieldName == 'changeScore' || fieldName == 'target';
      case 'Blackout': fieldName == 'instant';
      default: false;
    };
    final shaderPropertySlot = lastEventKind == 'Shader' ? shaderSlotForField(fieldName, 'property') : 0;
    if (shaderPropertySlot > 0)
    {
      final shaderInput:DropDown = cast toolboxEventsDataBox.findComponent('shader');
      final shader = Std.string(shaderInput?.selectedItem?.value ?? shaderInput?.value ?? chartEditorState.eventDataToPlace.get('shader') ?? '');
      final valueType = ShaderSongEvent.getUniformValueTypeForShader(shader, Std.string(value));
      final valueTypeName = shaderSlotField('valueType', shaderPropertySlot);
      final valueTypeInput:DropDown = cast toolboxEventsDataBox.findComponent(valueTypeName);
      if (valueTypeInput != null)
      {
        valueTypeInput.pauseEvent(UIEvent.CHANGE, true);
        valueTypeInput.value = valueType;
        valueTypeInput.resumeEvent(UIEvent.CHANGE, true, false);
        chartEditorState.eventDataToPlace.set(valueTypeName, valueType);
      }
    }
    if (changesLayout)
    {
      final eventKind = lastEventKind;
      Toolkit.callLater(() ->
      {
        if (lastEventKind != eventKind || toolboxEventsDataBox == null) return;
        if (eventKind == 'Shader' && (fieldName == 'shader' || shaderPropertySlot > 0)) updateShaderPropertyChoices();
        else updateContextualFieldVisibility();
        toolboxEventsDataBox.invalidateComponentLayout();
      });
    }

    if (!_initializing && chartEditorState.currentEventSelection.length > 0)
    {
      trace(' CHART EDITOR '.bold().bg_bright_yellow() + 'Event Toolbox MODIFYING all selected events...');
      for (songEvent in chartEditorState.currentEventSelection)
      {
        songEvent.eventKind = chartEditorState.eventKindToPlace;
        songEvent.value = Reflect.copy(chartEditorState.eventDataToPlace);
      }
      chartEditorState.saveDataDirty = true;
      chartEditorState.noteDisplayDirty = true;
      chartEditorState.notePreviewDirty = true;
      chartEditorState.noteTooltipsDirty = true;
    }
    if (fieldName == 'ease' || fieldName == 'easeDir') updateEasePreview();
    if (lastEventKind == 'Overlay' || lastEventKind == 'HUDFade') updateOverlayPreview();
  }

  function syncShaderSliderValue(fieldName:String, isDragging:Bool = false):Void
  {
    final slider = shaderValueSliders.get(fieldName);
    if (slider == null) return;
    final scale = shaderValueScales.get(fieldName) ?? 1.0;
    final step = (shaderValueEndpointOnly.get(fieldName) ?? false) ? slider.max - slider.min : FlxG.keys.pressed.SHIFT ? 5.0 : 1.0;
    var displayValue = Math.round(slider.pos / step) * step;
    displayValue = Math.max(slider.min, Math.min(slider.max, displayValue));
    if (slider.pos != displayValue)
    {
      slider.pauseEvent(UIEvent.CHANGE, true);
      slider.pos = displayValue;
      slider.resumeEvent(UIEvent.CHANGE, true, false);
    }
    final label = shaderValueLabels.get(fieldName);
    if (label != null) label.text = Std.string(Std.int(Math.round(displayValue)));
    final previousDisplay = shaderValueLastDisplays.get(fieldName);
    if (previousDisplay != null && Math.abs(previousDisplay - displayValue) < 0.001) return;
    shaderValueLastDisplays.set(fieldName, displayValue);
    if (isDragging)
    {
      chartEditorState.eventDataToPlace.set(fieldName, displayValue / scale);
    }
    else
    {
      commitEventFieldValue(fieldName, displayValue / scale);
    }
  }

  function updateOverlayPreview():Void
  {
    if (overlayPreviewImage == null && hudPreviewImage == null) return;
    overlayPreviewSignature = getOverlayPreviewSignature();
    final data = chartEditorState.eventDataToPlace;
    if (lastEventKind == 'HUDFade')
    {
      updateHudFadePreview();
      return;
    }
    final kind:String = Std.string(getPreviewControlValue('kind', data.get('kind') ?? 'solid'));
    final action:String = Std.string(getPreviewControlValue('action', data.get('action') ?? 'create'));
    final showPreview = action == 'create' && (kind == 'image' || kind == 'animated');
    if (overlayPreviewBox != null) overlayPreviewBox.hidden = !showPreview;
    if (!showPreview) return;
    final parsedOpacity = Std.parseFloat(Std.string(getPreviewControlValue('opacity', data.get('opacity') ?? 1)));
    final opacity = Math.max(0, Math.min(1, Math.isNaN(parsedOpacity) ? 1 : parsedOpacity));
    final resource = Std.string(getPreviewControlValue('resource', data.get('resource') ?? ''));
    final atlasType = Std.string(getPreviewControlValue('atlasType', data.get('atlasType') ?? 'sparrow'));
    final prefix = Std.string(getPreviewControlValue('prefix', data.get('prefix') ?? ''));
    final bitmap = loadOverlayPreviewBitmap(resource, kind, atlasType, prefix);
    final parsedScale = Std.parseFloat(Std.string(getPreviewControlValue('scale', data.get('scale') ?? 1)));
    final previewScale = Math.isNaN(parsedScale) ? 1 : Math.max(0, parsedScale);
    final large = bitmap != null && (bitmap.width * previewScale > FlxG.width / 2 || bitmap.height * previewScale > FlxG.height / 2);
    final previewWidth = large ? 320 : 160;
    final previewHeight = large ? 180 : 90;
    final previewBitmap = new BitmapData(previewWidth, previewHeight, true, 0x00000000);
    drawHudPreviewLayer(previewBitmap, 0);
    final camera = Std.string(getPreviewControlValue('camera', data.get('camera') ?? 'hud'));
    final blend = parseOverlayPreviewBlend(Std.string(getPreviewControlValue('blend', data.get('blend') ?? 'normal')));
    if (bitmap != null && camera == 'game') drawOverlayPreviewImage(previewBitmap, bitmap, opacity, blend);
    for (index in 1...hudPreviewLayers.length)
      drawHudPreviewLayer(previewBitmap, index);
    if (bitmap != null && camera != 'game') drawOverlayPreviewImage(previewBitmap, bitmap, opacity, blend);
    if (kind == 'animated' && bitmap != null) bitmap.dispose();
    setOverlayPreviewBitmap(previewBitmap);
  }

  function loadOverlayPreviewBitmap(resource:String, kind:String, atlasType:String, prefix:String):Null<BitmapData>
  {
    final imagePath = resolveOverlayPreviewImage(resource);
    if (imagePath == null) return null;
    if (kind == 'image') return readOverlayPreviewBitmap(imagePath);
    final atlasPath = Path.withoutExtension(imagePath) + (atlasType == 'packer' ? '.txt' : '.xml');
    if (!overlayPreviewFileExists(atlasPath)) return null;
    try
    {
      final frames = atlasType == 'packer' ? FlxAtlasFrames.fromSpriteSheetPacker(imagePath, atlasPath) : FlxAtlasFrames.fromSparrow(imagePath, atlasPath);
      var frame = prefix.trim() == '' ? frames.frames[0] : null;
      if (frame == null)
      {
        for (candidate in frames.frames)
          if (candidate.name != null && candidate.name.startsWith(prefix))
          {
            frame = candidate;
            break;
          }
      }
      return frame?.paint();
    }
    catch (e)
    {
      return null;
    }
  }

  function resolveOverlayPreviewImage(resource:String):Null<String>
  {
    if (resource == null || resource.trim() == '') return null;
    final normalized = resource.trim().replace('\\', '/');
    final candidates:Array<String> = [];
    if (normalized.toLowerCase().endsWith('.png')) addOverlayPreviewCandidate(candidates, normalized);
    else addOverlayPreviewCandidate(candidates, '${normalized}.png');

    var key = normalized;
    if (key.startsWith('assets/images/')) key = key.substr('assets/images/'.length);
    else if (key.startsWith('assets/shared/images/')) key = key.substr('assets/shared/images/'.length);
    else if (key.startsWith('assets/')) key = key.substr('assets/'.length);
    else if (key.startsWith('images/')) key = key.substr('images/'.length);
    if (key.toLowerCase().endsWith('.png')) key = key.substr(0, key.length - 4);
    addOverlayPreviewCandidate(candidates, Paths.image(key));
    addOverlayPreviewCandidate(candidates, 'assets/images/${key}.png');
    addOverlayPreviewCandidate(candidates, 'assets/shared/images/${key}.png');
    for (candidate in candidates)
      if (overlayPreviewFileExists(candidate)) return candidate;
    return null;
  }

  function addOverlayPreviewCandidate(candidates:Array<String>, candidate:String):Void
  {
    if (candidate != null && candidate != '' && !candidates.contains(candidate)) candidates.push(candidate);
  }

  function readOverlayPreviewBitmap(path:String):Null<BitmapData>
  {
    try
    {
      if (Assets.exists(path)) return Assets.getBitmapData(path);
      return BitmapData.fromFile(path);
    }
    catch (e)
    {
      return null;
    }
  }

  function overlayPreviewFileExists(path:String):Bool
  {
    if (path == null || path.trim() == '') return false;
    try
    {
      if (FileSystem.exists(path)) return !FileSystem.isDirectory(path);
    }
    catch (_) {}
    try
    {
      return Assets.exists(path);
    }
    catch (_) {}
    return false;
  }

  function drawHudPreviewLayer(target:BitmapData, index:Int):Void
  {
    if (index < 0 || index >= hudPreviewLayers.length) return;
    final matrix = new Matrix();
    matrix.scale(target.width / 160, target.height / 90);
    target.draw(hudPreviewLayers[index], matrix, null, null, null, true);
  }

  function drawOverlayPreviewImage(target:BitmapData, bitmap:BitmapData, opacity:Float, blend:BlendMode):Void
  {
    final data = chartEditorState.eventDataToPlace;
    final x = Std.parseFloat(Std.string(getPreviewControlValue('x', data.get('x') ?? 0)));
    final y = Std.parseFloat(Std.string(getPreviewControlValue('y', data.get('y') ?? 0)));
    final scale = Std.parseFloat(Std.string(getPreviewControlValue('scale', data.get('scale') ?? 1)));
    final rotation = Std.parseFloat(Std.string(getPreviewControlValue('rotation', data.get('rotation') ?? 0)));
    final safeX = Math.isNaN(x) ? 0 : x;
    final safeY = Math.isNaN(y) ? 0 : y;
    final safeScale = Math.isNaN(scale) ? 1 : Math.max(0, scale);
    final safeRotation = Math.isNaN(rotation) ? 0 : rotation;
    final gameScaleX = target.width / FlxG.width;
    final gameScaleY = target.height / FlxG.height;
    final matrix = new Matrix();
    matrix.translate(-bitmap.width / 2, -bitmap.height / 2);
    matrix.scale(safeScale * gameScaleX, safeScale * gameScaleY);
    matrix.rotate(safeRotation * Math.PI / 180);
    matrix.translate((safeX + bitmap.width / 2) * gameScaleX, (safeY + bitmap.height / 2) * gameScaleY);
    target.draw(bitmap, matrix, new ColorTransform(1, 1, 1, opacity), blend, null, true);
  }

  function parseOverlayPreviewBlend(value:String):BlendMode
  {
    return switch (value == null ? '' : value.toLowerCase())
    {
      case 'add': BlendMode.ADD;
      case 'multiply': BlendMode.MULTIPLY;
      case 'screen': BlendMode.SCREEN;
      case 'overlay': BlendMode.OVERLAY;
      case 'darken': BlendMode.DARKEN;
      case 'lighten': BlendMode.LIGHTEN;
      case 'difference': BlendMode.DIFFERENCE;
      case 'subtract': BlendMode.SUBTRACT;
      default: BlendMode.NORMAL;
    };
  }

  function updateHudFadePreview():Void
  {
    if (hudPreviewBitmap == null || hudPreviewLayers.length != 5) return;
    final data = chartEditorState.eventDataToPlace;
    final target:String = Std.string(getPreviewControlValue('target', data.get('target') ?? 'hud'));
    final strumlineTarget:String = Std.string(getPreviewControlValue('strumlineTarget', data.get('strumlineTarget') ?? 'both'));
    final sideTarget:String = Std.string(getPreviewControlValue('sideTarget', data.get('sideTarget') ?? 'both'));
    final parsedOpacity = Std.parseFloat(Std.string(getPreviewControlValue('opacity', data.get('opacity') ?? 1)));
    final opacity = Math.max(0, Math.min(1, Math.isNaN(parsedOpacity) ? 1 : parsedOpacity));
    final layerTargets = ['', 'receptors', 'notes', 'healthbar', 'icons'];
    final bounds = new Rectangle(0, 0, 160, 90);
    hudPreviewBitmap.lock();
    hudPreviewBitmap.copyPixels(hudPreviewLayers[0], bounds, new Point(), null, null, false);
    for (index in 1...hudPreviewLayers.length)
    {
      final splitTarget = (index == 1 && target == 'receptors') || (index == 2 && target == 'notes') || (index == 4 && target == 'icons');
      if (splitTarget)
      {
        final selectedSide = target == 'receptors' ? strumlineTarget : sideTarget;
        final leftOpacity = selectedSide == 'both' || selectedSide == 'opponent' ? opacity : 1;
        final rightOpacity = selectedSide == 'both' || selectedSide == 'player' ? opacity : 1;
        hudPreviewBitmap.draw(hudPreviewLayers[index], null, new ColorTransform(1, 1, 1, leftOpacity), null, new Rectangle(0, 0, 80, 90), true);
        hudPreviewBitmap.draw(hudPreviewLayers[index], null, new ColorTransform(1, 1, 1, rightOpacity), null, new Rectangle(80, 0, 80, 90), true);
        continue;
      }
      final layerOpacity = target != 'hud' && target != layerTargets[index] ? 1 : opacity;
      hudPreviewBitmap.draw(hudPreviewLayers[index], null, new ColorTransform(1, 1, 1, layerOpacity), null, null, true);
    }
    hudPreviewBitmap.unlock();
    hudPreviewPreviousSprite?.destroy();
    hudPreviewPreviousSprite = hudPreviewSprite;
    hudPreviewSprite = new flixel.FlxSprite().loadGraphic(hudPreviewBitmap.clone(), false, 0, 0, true);
    hudPreviewImage.resource = hudPreviewSprite.frame;
  }

  function setOverlayPreviewBitmap(bitmap:BitmapData):Void
  {
    overlayPreviewPreviousSprite?.destroy();
    overlayPreviewPreviousSprite = overlayPreviewSprite;
    overlayPreviewSprite = new flixel.FlxSprite().loadGraphic(bitmap, false, 0, 0, true);
    overlayPreviewImage.width = bitmap.width;
    overlayPreviewImage.height = bitmap.height;
    overlayPreviewImage.resource = overlayPreviewSprite.frame;
    overlayPreviewImage.opacity = 1;
    overlayPreviewImage.invalidateComponentLayout();
  }

  function getPreviewControlValue(id:String, fallback:Dynamic):Dynamic
  {
    final component = toolboxEventsDataBox.findComponent(id);
    if (component == null) return fallback;
    return switch (component)
    {
      case Std.isOfType(_, ColorPickerPopup) => true:
        final picker:ColorPickerPopup = cast component;
        final selected:Dynamic = picker.selectedItem;
        if (Std.isOfType(selected, String)) selected;
        else if (selected != null)
        {
          final selectedColor:haxe.ui.util.Color = cast selected;
          selectedColor.toHex();
        }
        else fallback;
      case Std.isOfType(_, NumberStepper) => true: cast(component, NumberStepper).value;
      case Std.isOfType(_, HorizontalSlider) => true: cast(component, HorizontalSlider).pos / (shaderValueScales.get(component.id) ?? 1.0);
      case Std.isOfType(_, DropDown) => true:
        final dropdown:DropDown = cast component;
        dropdown.selectedItem?.value ?? dropdown.value ?? fallback;
      case Std.isOfType(_, TextField) => true: cast(component, TextField).text;
      case Std.isOfType(_, CheckBox) => true: cast(component, CheckBox).selected;
      default: fallback;
    };
  }

  function getOverlayPreviewSignature():String
  {
    final ids = lastEventKind == 'HUDFade' ? ['target', 'strumlineTarget', 'sideTarget', 'opacity', 'duration', 'ease'] :
      ['action', 'kind', 'resource', 'atlasType', 'prefix', 'color', 'secondColor', 'opacity', 'x', 'y', 'scale', 'rotation', 'blend', 'camera', 'duration'];
    return lastEventKind + ':' + ids.map(function(id) return Std.string(getPreviewControlValue(id, chartEditorState.eventDataToPlace.get(id)))).join('|');
  }

  function updateShaderPropertyChoices():Void
  {
    if (lastEventKind != 'Shader') return;
    final shaderInput:DropDown = cast toolboxEventsDataBox.findComponent('shader');
    if (shaderInput == null) return;
    final shader = Std.string(shaderInput.selectedItem?.value ?? shaderInput.value ?? chartEditorState.eventDataToPlace.get('shader') ?? '');
    final properties = ShaderSongEvent.listPropertiesForShader(shader).filter(function(property) return property.name != '');
    final selectedProperties:Array<String> = [];
    var chainOpen = true;
    for (slot in 1...(ShaderSongEvent.MAX_PROPERTY_SLOTS + 1))
    {
      final propertyName = shaderSlotField('property', slot);
      final propertyInput:DropDown = cast toolboxEventsDataBox.findComponent(propertyName);
      if (propertyInput == null) continue;
      final previous = Std.string(chartEditorState.eventDataToPlace.get(propertyName) ?? propertyInput.selectedItem?.value ?? '');
      final available = properties.filter(function(property) return !selectedProperties.contains(property.name));
      var selected = chainOpen && available.exists(function(property) return property.name == previous) ? previous : '';
      if (slot == 1 && selected == '' && available.length > 0) selected = available[0].name;

      propertyInput.pauseEvent(UIEvent.CHANGE, true);
      propertyInput.dataSource.clear();
      if (slot > 1 || available.length == 0) propertyInput.dataSource.add({value: '', text: 'None'});
      for (property in available)
        propertyInput.dataSource.add({value: property.name, text: '${property.name} (${ShaderSongEvent.uniformLabel(property.type)})'});
      propertyInput.value = selected;
      propertyInput.resumeEvent(UIEvent.CHANGE, true, false);
      chartEditorState.eventDataToPlace.set(propertyName, selected);

      final valueType = selected == '' ? 'none' : ShaderSongEvent.getUniformValueTypeForShader(shader, selected);
      final valueTypeName = shaderSlotField('valueType', slot);
      final valueTypeInput:DropDown = cast toolboxEventsDataBox.findComponent(valueTypeName);
      if (valueTypeInput != null)
      {
        valueTypeInput.pauseEvent(UIEvent.CHANGE, true);
        valueTypeInput.value = valueType;
        valueTypeInput.resumeEvent(UIEvent.CHANGE, true, false);
        valueTypeInput.disabled = true;
      }
      chartEditorState.eventDataToPlace.set(valueTypeName, valueType);

      if (selected == '')
        chainOpen = false;
      else
        selectedProperties.push(selected);
    }
    updateShaderFieldVisibility();
  }

  static inline function shaderSlotField(base:String, slot:Int):String
  {
    return slot == 1 ? base : '${base}${slot}';
  }

  static function shaderSlotForField(fieldName:String, base:String):Int
  {
    if (fieldName == base) return 1;
    if (!fieldName.startsWith(base)) return 0;
    final parsed = Std.parseInt(fieldName.substr(base.length));
    return parsed != null && parsed >= 2 && parsed <= ShaderSongEvent.MAX_PROPERTY_SLOTS ? parsed : 0;
  }

  function updateShaderValueControl(shader:String, property:String, valueField:String):Void
  {
    final range = ShaderSongEvent.getUniformRangeForShader(shader, property);
    final slider = shaderValueSliders.get(valueField);
    if (slider == null) return;
    final scale = range.min >= 0 && range.max <= 1 ? 100.0 : 1.0;
    var rawVal = chartEditorState.eventDataToPlace.get(valueField);
    var current:Float = 0;
    if (rawVal == null)
    {
      current = scale == 100.0 ? 1.0 : (range.min > 0 ? range.min : 0.0);
      chartEditorState.eventDataToPlace.set(valueField, current);
    }
    else
    {
      current = Std.parseFloat(Std.string(rawVal));
      if (Math.isNaN(current)) current = 0;
    }
    if (scale == 100.0 && current > 1.0 && current <= 100.0)
    {
      current = current / 100.0;
    }
    current = Math.max(range.min, Math.min(range.max, current));
    final displayValue = current * scale;
    final endpointOnly = range.step > 0 && (range.max - range.min) / range.step <= 1;
    shaderValueScales.set(valueField, scale);
    shaderValueEndpointOnly.set(valueField, endpointOnly);
    slider.pauseEvent(UIEvent.CHANGE, true);
    slider.min = range.min * scale;
    slider.max = range.max * scale;
    slider.step = endpointOnly ? slider.max - slider.min : 1;
    slider.precision = 0;
    slider.pos = displayValue;
    slider.resumeEvent(UIEvent.CHANGE, true, false);
    final label = shaderValueLabels.get(valueField);
    if (label != null) label.text = Std.string(Std.int(Math.round(displayValue)));
    shaderValueLastDisplays.set(valueField, displayValue);
  }

  function updateContextualFieldVisibility():Void
  {
    switch (lastEventKind)
    {
      case 'Shader': updateShaderFieldVisibility();
      case 'Overlay': updateOverlayFieldVisibility();
      case 'HUDFade':
        final target = Std.string(getPreviewControlValue('target', chartEditorState.eventDataToPlace.get('target') ?? 'hud'));
        setEventFieldVisible('strumlineTarget', target == 'receptors');
        setEventFieldVisible('sideTarget', target == 'notes' || target == 'icons');
      case 'PlayAudio': updatePlayAudioFieldVisibility();
      case 'StageObjectControl': updateStageObjectFieldVisibility();
      case 'HealthDrain':
        final drainTarget = Std.string(getPreviewControlValue('target', chartEditorState.eventDataToPlace.get('target') ?? 'player'));
        setEventFieldVisible('canDie', drainTarget == 'player');
        setEventFieldVisible('scoreChange', getPreviewControlValue('changeScore', chartEditorState.eventDataToPlace.get('changeScore') ?? false) == true);
      case 'Blackout':
        final instant = getPreviewControlValue('instant', chartEditorState.eventDataToPlace.get('instant') ?? false) == true;
        setEventFieldVisible('fadeIn', !instant);
        setEventFieldVisible('fadeOut', !instant);
      default:
    }
  }

  function updateOverlayFieldVisibility():Void
  {
    final action = Std.string(getPreviewControlValue('action', chartEditorState.eventDataToPlace.get('action') ?? 'create'));
    final kind = Std.string(getPreviewControlValue('kind', chartEditorState.eventDataToPlace.get('kind') ?? 'solid'));
    final create = action == 'create';
    setEventFieldVisible('kind', create);
    setEventFieldVisible('resource', create && (kind == 'image' || kind == 'animated'));
    setEventFieldVisible('atlasType', create && kind == 'animated');
    setEventFieldVisible('prefix', create && kind == 'animated');
    setEventFieldVisible('color', create && (kind == 'solid' || kind == 'gradient'));
    setEventFieldVisible('secondColor', create && kind == 'gradient');
    setEventFieldVisible('opacity', create || action == 'fade');
    for (name in ['x', 'y', 'scale', 'rotation', 'blend', 'camera'])
      setEventFieldVisible(name, create);
    setEventFieldVisible('duration', true);
    if (overlayPreviewBox != null) overlayPreviewBox.hidden = !(create && (kind == 'image' || kind == 'animated'));
  }

  function updatePlayAudioFieldVisibility():Void
  {
    final action = Std.string(getPreviewControlValue('action', chartEditorState.eventDataToPlace.get('action') ?? 'play'));
    setEventFieldVisible('path', action == 'play');
    setEventFieldVisible('file', action == 'play');
    setEventFieldVisible('settings', action != 'pause');
    setEventFieldVisible('volume', action == 'play' || action == 'resume' || action == 'volume');
    setEventFieldVisible('loop', action == 'play');
    setEventFieldVisible('fadeIn', action == 'play' || action == 'resume');
    setEventFieldVisible('fadeOut', action == 'play' || action == 'stop');
    setEventFieldVisible('duration', action == 'volume');
  }

  function updateStageObjectFieldVisibility():Void
  {
    final action = Std.string(getPreviewControlValue('action', chartEditorState.eventDataToPlace.get('action') ?? 'show'));
    final twoValues = action == 'move' || action == 'scale' || action == 'scrollfactor';
    final oneValue = twoValues || action == 'rotate' || action == 'opacity' || action == 'layer';
    final tweened = action == 'move' || action == 'rotate' || action == 'scale' || action == 'opacity';
    setEventFieldVisible('value', oneValue);
    setEventFieldVisible('value2', twoValues);
    setEventFieldVisible('color', action == 'color');
    setEventFieldVisible('animation', action == 'animation');
    setEventFieldVisible('duration', tweened);
    setEventFieldVisible('ease', tweened);
    switch (action)
    {
      case 'move': setEventFieldLabel('value', 'X'); setEventFieldLabel('value2', 'Y');
      case 'rotate': setEventFieldLabel('value', 'Angle');
      case 'scale': setEventFieldLabel('value', 'X Scale'); setEventFieldLabel('value2', 'Y Scale');
      case 'opacity': setEventFieldLabel('value', 'Opacity');
      case 'scrollfactor': setEventFieldLabel('value', 'Scroll X'); setEventFieldLabel('value2', 'Scroll Y');
      case 'layer': setEventFieldLabel('value', 'Layer');
      default:
    }
  }

  function updateShaderTargetDropdowns(shader:String):Void
  {
    final targetTypeInput:DropDown = cast toolboxEventsDataBox.findComponent('targetType');
    if (targetTypeInput != null)
    {
      final supported = ShaderSongEvent.getSupportedTargetTypes(shader);
      final allLabels:Map<String, String> = [
        'camera' => 'Camera',
        'character' => 'Character',
        'object' => 'Object',
        'stageobject' => 'Stage Object',
        'overlay' => 'Overlay'
      ];
      final current = Std.string(chartEditorState.eventDataToPlace.get('targetType') ?? targetTypeInput.selectedItem?.value ?? 'camera');
      var selected = supported.contains(current) ? current : (supported.length > 0 ? supported[0] : 'camera');

      targetTypeInput.pauseEvent(UIEvent.CHANGE, true);
      targetTypeInput.dataSource.clear();
      for (type in supported)
      {
        if (allLabels.exists(type))
          targetTypeInput.dataSource.add({value: type, text: allLabels.get(type)});
      }
      targetTypeInput.value = selected;
      targetTypeInput.resumeEvent(UIEvent.CHANGE, true, false);
      chartEditorState.eventDataToPlace.set('targetType', selected);
    }

    final cameraTargetInput:DropDown = cast toolboxEventsDataBox.findComponent('cameraTarget');
    if (cameraTargetInput != null)
    {
      final supported = ShaderSongEvent.getSupportedCameraTargets(shader);
      final allLabels:Map<String, String> = [
        'screen' => 'Screen (Game + HUD)',
        'game' => 'Game',
        'hud' => 'HUD',
        'cutscene' => 'Cutscene'
      ];
      final current = Std.string(chartEditorState.eventDataToPlace.get('cameraTarget') ?? cameraTargetInput.selectedItem?.value ?? 'game');
      var selected = supported.contains(current) ? current : (supported.length > 0 ? supported[0] : 'game');

      cameraTargetInput.pauseEvent(UIEvent.CHANGE, true);
      cameraTargetInput.dataSource.clear();
      for (target in supported)
      {
        if (allLabels.exists(target))
          cameraTargetInput.dataSource.add({value: target, text: allLabels.get(target)});
      }
      cameraTargetInput.value = selected;
      cameraTargetInput.resumeEvent(UIEvent.CHANGE, true, false);
      chartEditorState.eventDataToPlace.set('cameraTarget', selected);
    }

    final characterTargetInput:DropDown = cast toolboxEventsDataBox.findComponent('characterTarget');
    if (characterTargetInput != null)
    {
      final supported = ShaderSongEvent.getSupportedCharacterTargets(shader);
      final allLabels:Map<String, String> = [
        'all' => 'All Characters',
        'bf' => 'BF (Player)',
        'dad' => 'Dad (Opponent)',
        'gf' => 'GF'
      ];
      final current = Std.string(chartEditorState.eventDataToPlace.get('characterTarget') ?? characterTargetInput.selectedItem?.value ?? 'all');
      var selected = supported.contains(current) ? current : (supported.length > 0 ? supported[0] : 'all');

      characterTargetInput.pauseEvent(UIEvent.CHANGE, true);
      characterTargetInput.dataSource.clear();
      for (target in supported)
      {
        if (allLabels.exists(target))
          characterTargetInput.dataSource.add({value: target, text: allLabels.get(target)});
      }
      characterTargetInput.value = selected;
      characterTargetInput.resumeEvent(UIEvent.CHANGE, true, false);
      chartEditorState.eventDataToPlace.set('characterTarget', selected);
    }
  }

  function updateShaderFieldVisibility():Void
  {
    if (lastEventKind != 'Shader') return;
    final action = Std.string(getPreviewControlValue('action', chartEditorState.eventDataToPlace.get('action') ?? 'apply'));
    final shader = Std.string(getPreviewControlValue('shader', chartEditorState.eventDataToPlace.get('shader') ?? ''));
    updateShaderTargetDropdowns(shader);
    final targetType = Std.string(getPreviewControlValue('targetType', chartEditorState.eventDataToPlace.get('targetType') ?? 'camera'));
    final applying = action == 'apply';
    final properties = ShaderSongEvent.listPropertiesForShader(shader).filter(function(property) return property.name != '');
    var selectedCount = 0;
    var previousSelected = true;
    var hasNumericProperty = false;

    setEventFieldVisible('targetType', true);
    setEventFieldVisible('characterTarget', targetType == 'character');
    setEventFieldVisible('cameraTarget', targetType == 'camera');
    setEventFieldVisible('target', targetType == 'object' || targetType == 'stageobject' || targetType == 'overlay');
    setEventFieldVisible('ignoreTransparentPixels', applying && targetType != 'camera' && shader.startsWith('frag:'));
    setEventFieldVisible('settings', true);

    for (slot in 1...(ShaderSongEvent.MAX_PROPERTY_SLOTS + 1))
    {
      final propertyField = shaderSlotField('property', slot);
      if (toolboxEventsDataBox.findComponent(propertyField) == null) continue;
      final valueTypeField = shaderSlotField('valueType', slot);
      final valueField = shaderSlotField('value', slot);
      final boolField = shaderSlotField('boolValue', slot);
      final colorField = shaderSlotField('color', slot);
      final xField = shaderSlotField('valueX', slot);
      final yField = shaderSlotField('valueY', slot);
      final property = Std.string(getPreviewControlValue(propertyField, chartEditorState.eventDataToPlace.get(propertyField) ?? ''));
      final valueType = property == '' ? 'none' : ShaderSongEvent.getUniformValueTypeForShader(shader, property);
      chartEditorState.eventDataToPlace.set(valueTypeField, valueType);
      final hasRemainingProperty = properties.length > selectedCount;
      final showProperty = applying && previousSelected && hasRemainingProperty;
      final showValue = showProperty && property != '';

      setEventFieldVisible(propertyField, showProperty);
      setEventFieldVisible(valueTypeField, false);
      setEventFieldVisible(valueField, showValue && (valueType == 'number' || valueType == 'integer'));
      setEventFieldVisible(boolField, showValue && valueType == 'bool');
      setEventFieldVisible(colorField, showValue && valueType == 'color');
      setEventFieldVisible(xField, showValue && valueType == 'position');
      setEventFieldVisible(yField, showValue && valueType == 'position');

      if (showValue && (valueType == 'number' || valueType == 'integer'))
      {
        hasNumericProperty = true;
        updateShaderValueControl(shader, property, valueField);
      }
      final propertyLabel = property == '' ? 'Value' : property.charAt(0) == '_' ? property.substr(1) : property;
      final displayProperty = propertyLabel.length == 0 ? 'Value' : propertyLabel.charAt(0).toUpperCase() + propertyLabel.substr(1);
      setEventFieldLabel(valueField, displayProperty);

      if (property != '') selectedCount++;
      previousSelected = previousSelected && property != '';
    }

    setEventFieldVisible('fadeIn', applying && hasNumericProperty);
    setEventFieldVisible('fadeOut', !applying || hasNumericProperty);
    if (targetType == 'object' || targetType == 'stageobject') setEventFieldLabel('target', 'Object Name');
    else if (targetType == 'overlay') setEventFieldLabel('target', 'Overlay Name');
  }

  function setEventFieldVisible(name:String, visible:Bool):Void
  {
    final row = toolboxEventsDataBox.findComponent('${name}-row');
    if (row != null) row.hidden = !visible;
  }

  function setEventFieldLabel(name:String, text:String):Void
  {
    final label:Label = cast toolboxEventsDataBox.findComponent('${name}-label');
    if (label != null) label.text = text;
  }

  var currentEaseHBox:HBox = null;

  function updateEasePreview():Void
  {
    if (easeGraphImage == null || easeDotImage == null) return;

    final easeVal:Null<String> = chartEditorState.eventDataToPlace.get("ease");
    final easeDirVal:Null<String> = chartEditorState.eventDataToPlace.get("easeDir");
    final easeStr:String = easeVal == null ? "linear" : easeVal;
    final easeDirStr:String = easeDirVal == null ? "In" : easeDirVal;
    final easeAlreadyHasDirection = easeStr.endsWith('In') || easeStr.endsWith('Out') || easeStr.endsWith('InOut');
    final key:String = easeAlreadyHasDirection ? easeStr : easeStr + (easeDirStr == "" ? "" : easeDirStr);

    // Hide preview when easing indicates a non-visual/legacy type such as "classic"
    if (easeStr != null && easeStr.toLowerCase().indexOf("classic") != -1)
    {
      _dotTimer?.cancel();
      _pauseTimer?.cancel();
      _dotTimer = null;
      _pauseTimer = null;
      _easeDotSprites = [];
      _dotIndex = 0;

      easeGraphImage.resource = null;
      easeDotImage.resource = null;
      easeGraphImage.hidden = true;
      easeDotImage.hidden = true;
      if (currentEaseHBox != null) currentEaseHBox.hidden = true;
      return;
    }

    // Reset any previous timers/sprites
    _dotTimer?.cancel();
    _pauseTimer?.cancel();
    _dotTimer = null;
    _pauseTimer = null;
    _easeDotSprites = [];
    _dotIndex = 0;

    final _graphBd:BitmapData = SongEventHelper.getEaseBitmap(key);
    _easeGraphSprite = SongEventHelper.createSpriteFromKey(key, 100, 100);
    easeGraphImage.resource = _easeGraphSprite?.frame;
    if (_graphBd == null || easeGraphImage.resource == null)
    {
      easeDotImage.resource = null;
      easeGraphImage.hidden = true;
      easeDotImage.hidden = true;
      if (currentEaseHBox != null) currentEaseHBox.hidden = true;
      return;
    }

    // show preview and start dot animation
    easeGraphImage.hidden = false;
    easeDotImage.hidden = false;
    if (currentEaseHBox != null) currentEaseHBox.hidden = false;

    var dotSprites:Array<flixel.FlxSprite> = SongEventHelper.getOrCreateEaseDotSprites(key, 30, 3, 16);
    if (dotSprites == null || dotSprites.length == 0)
    {
      // if no dot sprites, still show graph but keep dot empty
      easeDotImage.resource = null;
      return;
    }
    _easeDotSprites = dotSprites;
    easeDotImage.resource = _easeDotSprites[0].frame;

    var frameCallback:Dynamic = null;
    frameCallback = (tmr:FlxTimer) ->
    {
      _dotIndex++;
      if (_dotIndex >= _easeDotSprites.length)
      {
        _dotTimer?.cancel();
        _pauseTimer ??= new FlxTimer();
        _pauseTimer.start(_loopPause, function(p:FlxTimer):Void
        {
          if (easeDotImage != null && !_initializing)
          {
            _dotIndex = 0;
            if (_easeDotSprites[0].frame != null) easeDotImage.resource = _easeDotSprites[0].frame;
            _dotTimer ??= new FlxTimer();
            _dotTimer.start(_dotInterval, frameCallback, 0);
          }
        }, 1);
      }
      else if (easeDotImage != null
        && !_initializing
        && _easeDotSprites[_dotIndex].frame != null) easeDotImage.resource = _easeDotSprites[_dotIndex].frame;
    };

    _dotTimer ??= new FlxTimer();
    _dotTimer.start(_dotInterval, frameCallback, 0);
  }

  /**
   * Constructs a new Event toolbox for the given Chart Editor.
   * @param chartEditorState The Chart Editor state to build the toolbox for.
   * @return The newly constructed toolbox.
   */
  public static function build(chartEditorState:ChartEditorState):ChartEditorEventDataToolbox
  {
    return new ChartEditorEventDataToolbox(chartEditorState);
  }
}
#end
