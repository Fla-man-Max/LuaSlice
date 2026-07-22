package funkin.ui.debug.charting.dialogs;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.importer.PsychEngineImporter;
import funkin.input.Cursor;
import funkin.ui.debug.charting.dialogs.ChartEditorBaseDialog.DialogDropTarget;
import funkin.ui.debug.charting.dialogs.ChartEditorBaseDialog.DialogParams;
import funkin.util.Constants;
import funkin.util.FileUtil;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.containers.Box;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialog.DialogEvent;
import haxe.ui.containers.dialogs.Dialogs.FileDialogExtensionInfo;
import haxe.ui.containers.dialogs.Dialogs.SelectedFileInfo;
import haxe.ui.core.Component;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build("assets/exclude/data/ui/chart-editor/dialogs/psych-import.xml"))
@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorPsychEngineImportDialog extends ChartEditorBaseDialog
{
  static final MAX_DIFFICULTIES:Int = 8;

  var stepTitle:Label;
  var stepDescription:Label;
  var difficultyPanel:Component;
  var difficultyInput:TextField;
  var uploadScroll:Component;
  var uploadContainer:Component;
  var statusLabel:Label;
  var dialogCancel:Button;
  var dialogAdd:Button;
  var dialogSkip:Button;
  var dialogContinue:Button;

  var step:PsychImportStep = Difficulties;
  var difficulties:Array<String> = [];
  var chartEntries:Array<ChartEditorPsychImportEntry> = [];
  var chartSources:Map<String, PsychChartSource> = [];
  var externalEvents:Dynamic = null;
  var inferDifficulties:Bool = false;
  var dropHandlers:Array<DialogDropTarget> = [];
  var hasLoadedVocals:Bool = false;
  var opponentVocalsLoaded:Bool = false;
  var playerVocalsLoaded:Bool = false;

  public function new(state:ChartEditorState, dialogParams:DialogParams)
  {
    super(state, dialogParams);

    dialogCancel.onClick = _ -> hideDialog(DialogButton.CANCEL);
    dialogSkip.onClick = _ -> skipStep();
    dialogAdd.onClick = _ -> addInferredChartEntry();
    dialogContinue.onClick = _ -> continueStep();

    showDifficultyStep();
  }

  function showDifficultyStep():Void
  {
    step = Difficulties;
    clearUploads();
    stepTitle.text = 'Chart Difficulties';
    stepDescription.text = 'Use Easy, Normal, Hard, or add custom difficulty(s), up to 8 total. Skip to infer them from chart filenames.';
    difficultyPanel.hidden = false;
    uploadScroll.hidden = true;
    statusLabel.text = '';
    dialogAdd.hidden = true;
    dialogSkip.hidden = false;
    dialogContinue.hidden = false;
    dialogContinue.disabled = false;
  }

  function continueStep():Void
  {
    switch (step)
    {
      case Difficulties:
        final parsed = parseDifficulties(difficultyInput.text);
        if (parsed.length == 0)
        {
          chartEditorState.error('Psych Engine Import', 'Add at least one difficulty or press Skip to infer it from each chart filename.');
          return;
        }
        if (parsed.length > MAX_DIFFICULTIES)
        {
          chartEditorState.error('Psych Engine Import', 'You can import up to 8 difficulties.');
          return;
        }
        difficulties = parsed;
        inferDifficulties = false;
        showChartStep();
      case Charts:
        if (!allChartsSelected()) return;
        showEventsStep();
      case Vocals:
        if (opponentVocalsLoaded && playerVocalsLoaded) finishImport();
      default:
    }
  }

  function skipStep():Void
  {
    switch (step)
    {
      case Difficulties:
        difficulties = [];
        inferDifficulties = true;
        showChartStep();
      case Events:
        externalEvents = null;
        if (commitCharts()) showInstrumentalStep();
      default:
    }
  }

  function showChartStep():Void
  {
    step = Charts;
    clearUploads();
    difficultyPanel.hidden = true;
    uploadScroll.hidden = false;
    stepTitle.text = 'Charts';
    stepDescription.text = inferDifficulties ? 'Upload at least one chart. Difficulty names are read from filenames such as song-hard.json.' :
      'Upload one chart for each difficulty.';
    dialogSkip.hidden = true;
    dialogContinue.hidden = false;
    dialogContinue.disabled = true;
    dialogAdd.hidden = !inferDifficulties;
    dialogAdd.disabled = false;

    if (inferDifficulties) addInferredChartEntry();
    else
      for (difficulty in difficulties)
        addChartEntry(difficulty);
  }

  function addChartEntry(difficulty:String):Void
  {
    final entry = new ChartEditorPsychImportEntry(difficulty, selectPrompt('the ${displayDifficulty(difficulty)} chart'));
    entry.onClick = _ -> browseForChart(entry);
    chartEntries.push(entry);
    uploadContainer.addComponent(entry);
    addTextDropHandler(entry, path -> loadChart(entry, path, FileUtil.readStringFromPath(path)));
  }

  function addInferredChartEntry():Void
  {
    if (step != Charts || chartEntries.length >= MAX_DIFFICULTIES) return;
    final entry = new ChartEditorPsychImportEntry('', selectPrompt('a chart'));
    entry.onClick = _ -> browseForChart(entry);
    chartEntries.push(entry);
    uploadContainer.addComponent(entry);
    addTextDropHandler(entry, path -> loadChart(entry, path, FileUtil.readStringFromPath(path)));
    dialogAdd.disabled = chartEntries.length >= MAX_DIFFICULTIES;
  }

  function browseForChart(entry:ChartEditorPsychImportEntry):Void
  {
    FileUtil.browseForTextFile('Select Psych Engine Chart', [{label: 'Psych Engine Chart (.json)', extension: 'json'}], selected ->
    {
      loadChart(entry, selected.name ?? selected.fullPath ?? 'chart.json', selected.text ?? selected.bytes?.toString() ?? '');
    });
  }

  function loadChart(entry:ChartEditorPsychImportEntry, fileName:String, content:String):Void
  {
    final data = PsychEngineImporter.parseRaw(content, fileName);
    if (data == null || !PsychEngineImporter.isChart(data))
    {
      chartEditorState.error('Psych Engine Import', '${Path.withoutDirectory(fileName)} is not a Psych Engine chart.');
      return;
    }

    var difficulty = entry.difficulty;
    if (difficulty == '') difficulty = cleanDifficulty(PsychEngineImporter.inferDifficulty(Path.withoutExtension(Path.withoutDirectory(fileName)), Std.string(Reflect.field(data, 'song'))));
    if (difficulty == '') difficulty = 'normal';

    final oldDifficulty = entry.difficulty;
    if (oldDifficulty != difficulty && chartSources.exists(difficulty))
    {
      chartEditorState.error('Psych Engine Import', 'A chart for ${displayDifficulty(difficulty)} is already selected.');
      return;
    }
    if (oldDifficulty != '' && oldDifficulty != difficulty) chartSources.remove(oldDifficulty);

    entry.difficulty = difficulty;
    entry.markSelected(Path.withoutDirectory(fileName), displayDifficulty(difficulty));
    chartSources.set(difficulty, {data: data, fileName: fileName});
    rebuildDifficultyOrder();
    dialogContinue.disabled = !allChartsSelected();
    statusLabel.text = '${Lambda.count(chartSources)} chart(s) selected.';
  }

  function showEventsStep():Void
  {
    step = Events;
    clearUploads();
    stepTitle.text = 'Events';
    stepDescription.text = 'Select events.json, or skip this step.';
    dialogAdd.hidden = true;
    dialogSkip.hidden = false;
    dialogContinue.hidden = true;

    final entry = new ChartEditorPsychImportEntry('events', selectPrompt('events.json'));
    entry.onClick = _ -> FileUtil.browseForTextFile('Select Psych Engine events.json',
      [{label: 'Psych Engine Events (.json)', extension: 'json'}], selected ->
      {
        loadEvents(selected.name ?? selected.fullPath ?? 'events.json', selected.text ?? selected.bytes?.toString() ?? '');
      });
    uploadContainer.addComponent(entry);
    addTextDropHandler(entry, path -> loadEvents(path, FileUtil.readStringFromPath(path)));
  }

  function loadEvents(fileName:String, content:String):Void
  {
    final data = PsychEngineImporter.parseRaw(content, fileName);
    if (data == null || !Std.isOfType(Reflect.field(data, 'events'), Array))
    {
      chartEditorState.error('Psych Engine Import', '${Path.withoutDirectory(fileName)} is not a Psych Engine events file.');
      return;
    }
    externalEvents = data;
    if (commitCharts()) showInstrumentalStep();
  }

  function commitCharts():Bool
  {
    if (difficulties.length == 0 || chartSources.get(difficulties[0]) == null) return false;

    try
    {
      final firstDifficulty = difficulties[0];
      final firstSource = chartSources.get(firstDifficulty);
      final metadata:SongMetadata = PsychEngineImporter.migrateMetadata(firstSource.data, firstDifficulty);
      metadata.playData.difficulties = difficulties.copy();

      final noteMap:Map<String, Array<SongNoteData>> = [];
      final speedMap:Map<String, Float> = [];
      var events:Array<SongEventData> = [];
      for (index in 0...difficulties.length)
      {
        final difficulty = difficulties[index];
        final source = chartSources.get(difficulty);
        if (source == null) return false;
        final converted = PsychEngineImporter.migrateChartData(source.data, difficulty, index == 0 ? externalEvents : null);
        noteMap.set(difficulty, converted.notes.get(difficulty) ?? []);
        speedMap.set(difficulty, converted.scrollSpeed.get(difficulty) ?? 1);
        if (index == 0) events = converted.events;
      }

      final chart = new SongChartData(speedMap, events, noteMap);
      chart.generatedBy = 'Chart Editor Import (Psych Engine 1.0.4)';
      chartEditorState.loadSong([Constants.DEFAULT_VARIATION => metadata], [Constants.DEFAULT_VARIATION => chart]);
      chartEditorState.currentWorkingFilePath = null;
      return true;
    }
    catch (error)
    {
      chartEditorState.error('Psych Engine Import', 'Could not convert the selected charts:\n${error}');
      return false;
    }
  }

  function showInstrumentalStep():Void
  {
    step = Instrumental;
    clearUploads();
    stepTitle.text = 'Instrumental';
    stepDescription.text = 'Upload Inst.ogg or Inst.mp3.';
    dialogAdd.hidden = true;
    dialogSkip.hidden = true;
    dialogContinue.hidden = true;

    final entry = new ChartEditorPsychImportEntry('inst', selectPrompt('Inst.ogg or Inst.mp3'));
    entry.onClick = _ -> FileUtil.browseForBinaryFile('Select Instrumental', audioFilter(), selected -> loadInstrumental(selected));
    uploadContainer.addComponent(entry);
    addBinaryDropHandler(entry, loadInstrumentalPath);
  }

  function loadInstrumental(selected:SelectedFileInfo):Void
  {
    if (selected?.bytes == null || !chartEditorState.loadInstFromBytes(selected.bytes, chartEditorState.currentInstrumentalId))
    {
      chartEditorState.error('Psych Engine Import', 'Failed to load ${selected?.name ?? 'the instrumental'}.');
      return;
    }
    chartEditorState.switchToCurrentInstrumental();
    showVocalsStep();
  }

  function loadInstrumentalPath(path:String):Void
  {
    if (!chartEditorState.loadInstFromPath(new Path(path), chartEditorState.currentInstrumentalId))
    {
      chartEditorState.error('Psych Engine Import', 'Failed to load ${Path.withoutDirectory(path)}.');
      return;
    }
    chartEditorState.switchToCurrentInstrumental();
    showVocalsStep();
  }

  function showVocalsStep():Void
  {
    step = Vocals;
    clearUploads();
    stepTitle.text = 'Vocals';
    stepDescription.text = 'Upload both Opponent and Player vocals.';
    dialogAdd.hidden = true;
    dialogSkip.hidden = true;
    dialogContinue.hidden = false;
    dialogContinue.disabled = true;
    hasLoadedVocals = false;
    opponentVocalsLoaded = false;
    playerVocalsLoaded = false;

    final opponentId = chartEditorState.currentSongMetadata.playData.characters.opponent;
    final playerId = chartEditorState.currentSongMetadata.playData.characters.player;
    addVocalEntry('Opponent Vocals', opponentId, false);
    addVocalEntry('Player Vocals', playerId, true);
  }

  function addVocalEntry(title:String, characterId:String, player:Bool):Void
  {
    final entry = new ChartEditorPsychImportEntry(characterId, selectPrompt(title));
    entry.onClick = _ -> FileUtil.browseForBinaryFile('Select $title', audioFilter(), selected ->
    {
      if (selected?.bytes != null) loadVocalBytes(entry, selected.name ?? title, selected.bytes, characterId, player);
    });
    uploadContainer.addComponent(entry);
    addBinaryDropHandler(entry, path -> loadVocalPath(entry, path, characterId, player));
  }

  function loadVocalBytes(entry:ChartEditorPsychImportEntry, fileName:String, bytes:Bytes, characterId:String, player:Bool):Void
  {
    if (!chartEditorState.loadVocalsFromBytes(bytes, characterId, chartEditorState.currentInstrumentalId, !hasLoadedVocals))
    {
      chartEditorState.error('Psych Engine Import', 'Failed to load ${Path.withoutDirectory(fileName)}.');
      return;
    }
    finishVocal(entry, fileName, player);
  }

  function loadVocalPath(entry:ChartEditorPsychImportEntry, path:String, characterId:String, player:Bool):Void
  {
    if (!chartEditorState.loadVocalsFromPath(new Path(path), characterId, chartEditorState.currentInstrumentalId, !hasLoadedVocals))
    {
      chartEditorState.error('Psych Engine Import', 'Failed to load ${Path.withoutDirectory(path)}.');
      return;
    }
    finishVocal(entry, path, player);
  }

  function finishVocal(entry:ChartEditorPsychImportEntry, fileName:String, player:Bool):Void
  {
    hasLoadedVocals = true;
    if (player) playerVocalsLoaded = true;
    else opponentVocalsLoaded = true;
    entry.markSelected(Path.withoutDirectory(fileName), player ? 'Player Vocals' : 'Opponent Vocals');
    dialogContinue.disabled = !(opponentVocalsLoaded && playerVocalsLoaded);
  }

  function finishImport():Void
  {
    chartEditorState.switchToCurrentInstrumental();
    chartEditorState.postLoadInstrumental();
    chartEditorState.success('Psych Engine Import', 'Imported ${difficulties.length} chart difficulty(s), Inst, and both vocal tracks.');
    hideDialog(DialogButton.APPLY);
  }

  function parseDifficulties(value:String):Array<String>
  {
    final result:Array<String> = [];
    for (part in (value ?? '').split(','))
    {
      final difficulty = cleanDifficulty(part);
      if (difficulty != '' && !result.contains(difficulty)) result.push(difficulty);
    }
    return result;
  }

  function cleanDifficulty(value:String):String
  {
    return (value ?? '').trim().toLowerCase().replace(' ', '-');
  }

  function displayDifficulty(value:String):String
  {
    final clean = (value ?? '').replace('-', ' ');
    return clean.length == 0 ? 'Chart' : clean.toTitleCase();
  }

  function rebuildDifficultyOrder():Void
  {
    if (!inferDifficulties) return;
    difficulties = [];
    for (entry in chartEntries)
      if (entry.selected && entry.difficulty != '' && !difficulties.contains(entry.difficulty)) difficulties.push(entry.difficulty);
  }

  function allChartsSelected():Bool
  {
    if (chartEntries.length == 0) return false;
    for (entry in chartEntries)
      if (!entry.selected) return false;
    return difficulties.length > 0;
  }

  function clearUploads():Void
  {
    for (dropHandler in dropHandlers) chartEditorState.removeDropHandler(dropHandler);
    dropHandlers.resize(0);
    chartEntries.resize(0);
    uploadContainer.removeAllComponents();
  }

  function addTextDropHandler(component:Component, callback:String->Void):Void
  {
    #if FEATURE_FILE_DROP
    final handler:DialogDropTarget = {component: component, handler: callback};
    dropHandlers.push(handler);
    chartEditorState.addDropHandler(handler);
    #end
  }

  function addBinaryDropHandler(component:Component, callback:String->Void):Void
  {
    addTextDropHandler(component, callback);
  }

  function audioFilter():Array<FileDialogExtensionInfo>
  {
    return [
      {label: 'Ogg Vorbis Audio (.ogg)', extension: 'ogg'},
      {label: 'MP3 Audio (.mp3)', extension: 'mp3'}
    ];
  }

  static function selectPrompt(name:String):String
  {
    #if FEATURE_FILE_DROP
    return 'Drag and drop or click to select ${name}.';
    #else
    return 'Click to select ${name}.';
    #end
  }

  public override function onClose(event:DialogEvent):Void
  {
    clearUploads();
    super.onClose(event);
    if (event.button != DialogButton.APPLY && !(params.closable ?? false)) chartEditorState.openWelcomeDialog(params.closable ?? false);
  }

  public static function build(state:ChartEditorState, closable:Bool):ChartEditorPsychEngineImportDialog
  {
    final dialog = new ChartEditorPsychEngineImportDialog(state, {closable: closable, modal: true});
    dialog.zIndex = 1000;
    state.isHaxeUIDialogOpen = true;
    dialog.showDialog(true);
    return dialog;
  }
}

private enum PsychImportStep
{
  Difficulties;
  Charts;
  Events;
  Instrumental;
  Vocals;
}

private typedef PsychChartSource =
{
  var data:Dynamic;
  var fileName:String;
}

@:build(haxe.ui.ComponentBuilder.build("assets/exclude/data/ui/chart-editor/dialogs/psych-import-entry.xml"))
class ChartEditorPsychImportEntry extends Box
{
  public var uploadEntryLabel:Label;
  public var difficulty:String;
  public var selected:Bool = false;

  public function new(difficulty:String, text:String)
  {
    super();
    this.difficulty = difficulty;
    uploadEntryLabel.text = text;
    onMouseOver = _ ->
    {
      swapClass('upload-bg', 'upload-bg-hover');
      Cursor.cursorMode = Pointer;
    };
    onMouseOut = _ ->
    {
      swapClass('upload-bg-hover', 'upload-bg');
      Cursor.cursorMode = Default;
    };
  }

  public function markSelected(fileName:String, title:String):Void
  {
    selected = true;
    uploadEntryLabel.text = '$title\n$fileName';
  }
}
#end
