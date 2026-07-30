package funkin.ui.debug.stageeditor.components;

#if FEATURE_STAGE_EDITOR
import funkin.ui.debug.stageeditor.handlers.StageFormatConverter;
import funkin.ui.debug.stageeditor.handlers.StageFormatConverter.StageConversionResult;
import funkin.util.FileUtil;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs.FileDialogExtensionInfo;
import openfl.net.FileFilter;

@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/stage-editor/dialogs/convert.xml"))
class StageConversionDialog extends Dialog
{
  static final ENGINE_IDS:Array<String> = [StageFormatConverter.BASE, StageFormatConverter.PSYCH, StageFormatConverter.CODENAME];

  var fromEngine:DropDown;
  var toEngine:DropDown;
  var conversionDescription:Label;
  var conversionStatus:Label;
  var stageEditorState:StageEditorState;

  override public function new(state:StageEditorState)
  {
    super();
    stageEditorState = state;
    destroyOnClose = true;
    buttons = DialogButton.CANCEL | "{{Convert}}";
    defaultButton = "{{Convert}}";
    fromEngine.onChange = function(_) updateDescription();
    toEngine.onChange = function(_) updateDescription();
    updateDescription();
  }

  override public function validateDialog(button:DialogButton, fn:Bool->Void)
  {
    if (button == DialogButton.CANCEL)
    {
      fn(true);
      return;
    }

    var source = selectedEngine(fromEngine);
    var target = selectedEngine(toEngine);
    if (source == target)
    {
      conversionStatus.text = "Choose two different engine formats.";
      stageEditorState.notifyChange("Stage Conversion", conversionStatus.text, true);
      fn(false);
      return;
    }

    conversionStatus.text = "Choose the stage file to convert...";
    fn(false);
    FileUtil.browseForBinaryFile('Open ${engineName(source)} stage', inputFilters(source), function(file)
    {
      try
      {
        var validationError = StageFormatConverter.validateSource(source, file.bytes, file.name);
        if (validationError != null)
        {
          conversionStatus.text = validationError;
          stageEditorState.notifyChange("Wrong Stage Format", validationError, true);
          return;
        }
        conversionStatus.text = "Converting...";
        var result = StageFormatConverter.convert(source, target, file.bytes, file.name);
        saveResult(result, target);
      }
      catch (error:Dynamic)
      {
        conversionStatus.text = 'Conversion failed: ${Std.string(error)}';
        stageEditorState.notifyChange("Stage Conversion Failed", Std.string(error), true);
      }
    }, function()
    {
      conversionStatus.text = "Conversion cancelled.";
    });
  }

  function saveResult(result:StageConversionResult, target:String):Void
  {
    conversionStatus.text = "Choose where to save the converted stage...";
    FileUtil.saveFile(result.bytes, [outputFilter(target)], function(_)
    {
      var warningText = result.warnings.length == 0 ? "" : "\n\n" + result.warnings.join("\n");
      conversionStatus.text = "Stage converted successfully.";
      stageEditorState.notifyChange("Stage Conversion Complete", 'Saved ${result.defaultFileName}.$warningText');
      hideDialog("{{Convert}}");
    }, function()
    {
      conversionStatus.text = "Save cancelled.";
    }, result.defaultFileName, 'Save ${engineName(target)} stage');
  }

  function updateDescription():Void
  {
    conversionDescription.text = '${engineName(selectedEngine(fromEngine))}  →  ${engineName(selectedEngine(toEngine))}';
    conversionStatus.text = "";
  }

  static function selectedEngine(dropdown:DropDown):String
  {
    var index = dropdown.selectedIndex;
    return index >= 0 && index < ENGINE_IDS.length ? ENGINE_IDS[index] : StageFormatConverter.BASE;
  }

  static function engineName(engine:String):String
  {
    return switch (engine)
    {
      case StageFormatConverter.BASE: "Base Game";
      case StageFormatConverter.PSYCH: "Psych Engine v1.0.4";
      case StageFormatConverter.CODENAME: "Codename Engine";
      default: engine;
    };
  }

  static function inputFilters(engine:String):Array<FileDialogExtensionInfo>
  {
    return switch (engine)
    {
      case StageFormatConverter.BASE:
        [
          {extension: "fnfs", label: "Base Game Stage Package"},
          {extension: "json", label: "Base Game Stage JSON"}
        ];
      case StageFormatConverter.PSYCH:
        [{extension: "json", label: "Psych Engine Stage JSON"}];
      case StageFormatConverter.CODENAME:
        [{extension: "xml", label: "Codename Engine Stage XML"}];
      default:
        [];
    };
  }

  static function outputFilter(engine:String):FileFilter
  {
    return switch (engine)
    {
      case StageFormatConverter.BASE: new FileFilter("Base Game Stage Package (.fnfs)", "*.fnfs");
      case StageFormatConverter.PSYCH: new FileFilter("Psych Engine Stage JSON (.json)", "*.json");
      case StageFormatConverter.CODENAME: new FileFilter("Codename Engine Stage XML (.xml)", "*.xml");
      default: new FileFilter("Stage File", "*.*");
    };
  }
}
#end
