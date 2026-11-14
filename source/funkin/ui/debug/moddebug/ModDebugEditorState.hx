package funkin.ui.debug.moddebug;

#if (FEATURE_HAXEUI && (windows || android))
import flixel.FlxCamera;
import flixel.FlxState;
import flixel.FlxSubState;
import funkin.data.character.CharacterRegistry;
import funkin.data.song.SongRegistry;
import funkin.data.stage.StageRegistry;
import funkin.input.Cursor;
import funkin.play.PlayState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.transition.loading.LoadingState;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.components.TextArea;
import haxe.ui.containers.HBox;
import haxe.ui.containers.Box;
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.core.Component;
import luaslice.debug.ModDebugSession;
import luaslice.debug.ModDebugSession.ModDebugOption;
import luaslice.debug.ModDebugDiagnostics;
import luaslice.debug.ModDebugScripts.ModDebugScript;
import luaslice.script.ScriptProfiler;

@:keep
class ModDebugEditorState extends FlxState
{
  public var session(default, null):Null<ModDebugSession>;
  public var preview(default, null):Null<ModDebugPreview>;
  var world:FlxCamera;
  var ui:FlxCamera;
  var root:VBox;
  var windows:ModDebugWindows;
  var modal:Null<Dialog>;
  var statusText:Label;
  var fpsText:Label;
  var frames:Int = 0;
  var measuredAt:Float;
  var detached:Bool = false;
  var closedLoadGeneration:Null<Int>;
  var originalAutoPause:Bool;
  var originalVolume:Float;
  var originalMute:Bool;
  var objects:ModDebugObjects;
  var ownsProfiler:Bool = false;

  override public function create():Void
  {
    super.create();
    FlxG.sound.music?.stop();
    Cursor.show();
    originalAutoPause = FlxG.autoPause;
    world = FlxG.camera;
    world.bgColor = 0xFF30343B;
    ui = new FlxCamera();
    ui.bgColor = 0;
    FlxG.cameras.add(ui, false);

    root = new VBox();
    root.cameras = [ui];
    root.width = FlxG.width;
    root.height = FlxG.height;
    add(root);
    windows = new ModDebugWindows(root);
    var menu = new HBox();
    menu.addClass('menubar');
    menu.styleString = 'spacing: 6px;';
    menu.percentWidth = 100;
    root.addComponent(menu);
    button(menu, 'Session', () -> open('Session', sessionPanel));
    button(menu, 'Test', () -> open('Test', testPanel));
    button(menu, 'Inspect', () -> open('Inspect', inspectPanel));
    button(menu, 'Test Options', () -> open('Test Options', optionsPanel));
    button(menu, 'Script Safety', () -> open('Script Safety', nonSavePanel));
    button(menu, 'View', () -> open('View', viewPanel));
    button(menu, 'Help', () -> open('Quick Start', helpPanel));
    button(menu, 'Back', back);
    var spacer = new Box();
    spacer.percentWidth = 100;
    menu.addComponent(spacer);
    label(menu, 'V0.0.1 (Stable)').verticalAlign = 'center';
    statusText = label(root, 'Test Debug Editor');
    statusText.styleString = 'background-color: #242930; color: #eceff3; padding: 5px;';
    subStateClosed.add(onPreviewClosed);
    measuredAt = haxe.Timer.stamp();

    #if android
    modal = Dialogs.messageBox(
      'This editor runs mod code and can use a lot of memory and battery. High FPS targets may exceed your display refresh rate and heat up your device. Changes here are temporary.',
      'Test Debug Editor', MessageBoxType.TYPE_YESNO, true, result ->
      {
        modal = null;
        if (result == DialogButton.YES) startSession();
        else leave();
      });
    #else
    startSession();
    #end
  }

  function startSession():Void
  {
    originalVolume = FlxG.sound.volume;
    originalMute = FlxG.sound.muted;
    session = ModDebugSession.begin(() -> {update: FlxG.updateFramerate, draw: FlxG.drawFramerate}, applyRates);
    preview = new ModDebugPreview(this, world, session, status, preparePlay, setTestingUI);
    objects = new ModDebugObjects(session, preview);
    status('Choose a registered stage or song in Test. Changes are temporary.');
    open('Test', testPanel);
  }

  function helpPanel(panel:VBox):Void
  {
    label(panel, '1. In Test, pick a stage and press Preview Stage.');
    label(panel, '2. Pick a song, variation and difficulty, then press Playtest Song.');
    label(panel, '3. Use Pause → Return to Test Debug Editor to come back.');
    label(panel, 'Inspect shows objects, scripts, assets and errors.');
    label(panel, 'Use View to move the stage camera or reset window positions.');
    label(panel, 'Back closes the top panel. During loading, Back cancels the test.');
  }

  static function applyRates(update:Int, draw:Int):Void
  {
    if (update < FlxG.drawFramerate) FlxG.drawFramerate = draw;
    FlxG.updateFramerate = update;
    FlxG.drawFramerate = draw;
  }

  function open(title:String, build:VBox->Void):Void
  {
    if (session != null && !preview.testing && modal == null) windows.open(title, build);
  }

  function sessionPanel(panel:VBox):Void
  {
    label(panel, 'Runtime FPS target (30–500)');
    var fps = field(panel, Std.string(FlxG.drawFramerate));
    button(panel, 'Apply FPS', () ->
    {
      var value = StringTools.trim(fps.text);
      if (!~/^[0-9]+$/.match(value) || !session.setRequestedFps(Std.parseInt(value) ?? -1))
        status('Enter a whole number between 30 and 500.');
      else status('Requested FPS: $value');
    });
    fpsText = label(panel, 'Measuring FPS…');
    button(panel, 'Reset Session', () ->
    {
      objects.reset();
      preview.dispose();
      session.reset();
      stopProfiler();
      fps.text = Std.string(FlxG.drawFramerate);
      windows.resetPositions();
      status('Temporary settings and preview cleared.');
    });
  }

  function testPanel(panel:VBox):Void
  {
    label(panel, 'Stage preview');
    var stage = picker(panel, 'Stage', sortedIds(StageRegistry.instance.listEntryIds()));
    selectIfPresent(stage, 'mainStage');
    for (i in 0...3)
    {
      var role = i;
      var characters = sortedIds(CharacterRegistry.instance.listEntryIds());
      var dropdown = picker(panel, ['Boyfriend', 'Opponent', 'Girlfriend'][i], characters, true);
      dropdown.selectedIndex = characters.indexOf(preview.characterIds[i]) + 1;
      dropdown.onChange = _ -> preview.characterIds[role] = selection(dropdown);
    }
    button(panel, 'Preview Stage', () ->
    {
      objects.reset();
      preview.loadStage(selection(stage));
    });
    checkbox(panel, 'Pause stage', false, value -> preview.paused = value);
    label(panel, 'Song playtest');
    var song = picker(panel, 'Song', sortedIds(SongRegistry.instance.listEntryIds()));
    selectIfPresent(song, 'tutorial');
    var variation = picker(panel, 'Variation', []);
    var difficulty = picker(panel, 'Difficulty', []);
    function updateDifficulties()
    {
      var id = selection(variation);
      var entry = SongRegistry.instance.fetchEntry(selection(song), {variation: id});
      populate(difficulty, entry?.listDifficulties(id) ?? []);
      selectIfPresent(difficulty, 'normal');
    }
    function updateVariations()
    {
      var entry = SongRegistry.instance.fetchEntry(selection(song));
      populate(variation, entry?.variations ?? []);
      selectIfPresent(variation, 'default');
      updateDifficulties();
    }
    song.onChange = _ -> updateVariations();
    variation.onChange = _ -> updateDifficulties();
    updateVariations();
    button(panel, 'Playtest Song', () ->
    {
      objects.reset();
      preview.startSong(selection(song), selection(variation), selection(difficulty));
    });
  }

  function setTestingUI(loading:Bool):Void
  {
    if (loading)
    {
      for (picker in root.findComponents(null, DropDown, 20)) picker.hideDropDown();
      var focus = haxe.ui.focus.FocusManager.instance.focus;
      if (focus != null) focus.focus = false;
    }
    root.disabled = loading;
  }

  function inspectPanel(panel:VBox):Void
  {
    button(panel, 'Object and Shader Inspector', () -> open('Objects and Shaders', objectsPanel));
    button(panel, 'Timeline and Assets', () -> open('Timeline and Assets', timelinePanel));
    button(panel, 'Script Profiler', () -> open('Script Profiler', profilerPanel));
    button(panel, 'Script Inspector', () -> open('Scripts', scriptsPanel));
  }

  function objectsPanel(panel:VBox):Void
  {
    var rows = objects.list();
    var target = picker(panel, 'Stage object', [for (row in rows) row.name]);
    function selected() return rows[target.selectedIndex];
    var info = label(panel, objects.describe(selected()));
    target.onChange = _ -> info.text = objects.describe(selected());
    button(panel, 'Refresh Objects', () ->
    {
      rows = objects.list();
      populate(target, [for (row in rows) row.name]);
      info.text = objects.describe(selected());
    });
    var property = picker(panel, 'Visual property', ['X', 'Y', 'Alpha', 'Visible']);
    var value = field(panel, '1');
    button(panel, 'Apply Visual Value', () ->
    {
      if (!objects.edit(selected(), selection(property), Std.parseFloat(value.text)))
        status('Select a live object and enter a valid value (Visible: 0 or 1).');
      info.text = objects.describe(selected());
    });
    var uniform = picker(panel, 'Supported float uniform', ModDebugObjects.uniforms);
    button(panel, 'Apply Shader Value', () ->
    {
      if (!objects.setUniform(selected(), selection(uniform), Std.parseFloat(value.text)))
        status('That uniform is not supported on the selected shader.');
    });
    button(panel, 'Reset Visual Edits', () ->
    {
      objects.reset();
      info.text = objects.describe(selected());
    });
  }

  function timelinePanel(panel:VBox):Void
  {
    var filter = field(panel, '');
    filter.placeholder = 'Filter events, assets or errors';
    var result = area(panel);
    function refresh()
    {
      var entries = session.diagnostics.snapshot(filter.text);
      result.text = 'Script errors: ${session.diagnostics.errors}\n' + [for (entry in entries.slice(-50))
        '[${entry.kind}] ${entry.source}: ${entry.detail}'].join('\n');
    }
    filter.onChange = _ -> refresh();
    checkbox(panel, 'Pause timeline', session.diagnostics.paused, value -> session.diagnostics.paused = value);
    button(panel, 'Refresh Timeline', refresh);
    button(panel, 'Clear Timeline', () ->
    {
      session.diagnostics.clear();
      refresh();
    });
    button(panel, 'Export Redacted Report', exportReport);
    refresh();
  }

  function profilerPanel(panel:VBox):Void
  {
    label(panel, 'CPU script callback timings, not GPU timings.');
    var result = area(panel);
    checkbox(panel, 'Record script timings', ScriptProfiler.enabled, value ->
    {
      if (value && !ScriptProfiler.enabled)
      {
        ScriptProfiler.start();
        ownsProfiler = true;
      }
      else if (!value) stopProfiler();
    });
    button(panel, 'Refresh Timings', () ->
    {
      var profile:Dynamic = ScriptProfiler.snapshot();
      var rows:Array<Dynamic> = profile.hooks;
      result.text = [for (row in rows.slice(0, 20))
        '${ModDebugDiagnostics.displayName(row.script)} / ${row.hook}: ${Math.round(row.totalMs * 100) / 100} ms (${row.calls} calls)'].join('\n');
    });
  }

  function stopProfiler():Void
  {
    if (!ownsProfiler) return;
    ScriptProfiler.stop();
    ScriptProfiler.reset();
    ownsProfiler = false;
  }

  function exportReport():Void
  {
    var profile = ScriptProfiler.snapshot();
    var rows:Array<Dynamic> = profile.hooks;
    for (row in rows) row.script = ModDebugDiagnostics.displayName(row.script);
    var contents = session.diagnostics.export(Constants.LUASLICE_VERSION, Sys.systemName(), profile);
    funkin.util.FileUtil.saveFile('Export Mod Debug Report', haxe.io.Bytes.ofString(contents), null, _ -> status('Diagnostic report exported.'),
      null, 'mod-debug-report.json');
  }

  static function area(panel:VBox):TextArea
  {
    var result = new TextArea();
    result.width = 410;
    result.height = 180;
    panel.addComponent(result);
    return result;
  }

  function optionsPanel(panel:VBox):Void
  {
    label(panel, 'Temporary values; restart song tests for layout changes.');
    checkbox(panel, 'Apply option overrides', session.optionsEnabled, value -> session.optionsEnabled = value);
    final options:Array<ModDebugOption> = [Downscroll, #if !mobile MiddleScroll, #end NoteSplash, CameraZoom, FlashingLights];
    for (option in options)
    {
      final key = option;
      var values = new DropDown();
      ModDebugWindows.bindDropDown(values, ui);
      values.width = 230;
      populate(values, ['Saved value', 'On', 'Off']);
      label(panel, cast key);
      panel.addComponent(values);
      values.onChange = _ -> switch (values.selectedIndex)
      {
        case 1: session.setOption(key, true);
        case 2: session.setOption(key, false);
        default: session.clearOption(key);
      }
    }
  }

  function nonSavePanel(panel:VBox):Void
  {
    label(panel, 'Scores, progression and supported Lua saves are temporary.');
    label(panel, 'Direct file writes by trusted scripts cannot be undone.');
    checkbox(panel, 'Suppress nonfatal Lua popups', session.suppressScriptPopups, value ->
    {
      if (value && !session.scripts.forceApproved)
        confirmExperimental(accepted -> session.suppressScriptPopups = accepted);
      else session.suppressScriptPopups = value;
    });
    button(panel, 'Force Scripts', () -> open('Scripts', scriptsPanel));
  }

  function scriptsPanel(panel:VBox):Void
  {
    var rows:Array<ModDebugScript> = [];
    var script = picker(panel, 'Discovered scripts', []);
    var info = label(panel, '');
    function selected() return rows[script.selectedIndex];
    function updateInfo()
    {
      var row = selected();
      info.text = row == null ? 'Start a preview to discover scripts.'
        : '${row.backend}: ${row.status}\n${row.path}\n'
        + (row.eligible ? 'Supports force discovery on the next song test.' : 'Force loading is unavailable for this source.')
        + (row.disabled ? '\nDisabled for the next preview.' : '') + (row.forced ? '\nSelected for force discovery.' : '');
    }
    function refresh()
    {
      #if FEATURE_PSYCH_LUA
      for (entry in funkin.modding.psychlua.PsychLuaHost.diagnosticCandidates())
        session.scripts.discover('Psych Lua', entry.root, entry.path, true);
      #end
      rows = session.scripts.snapshot();
      rows.sort((a, b) -> Reflect.compare(a.path, b.path));
      var previous = script.selectedIndex;
      populate(script, [for (row in rows) row.backend + ': ' + ModDebugDiagnostics.displayName(row.path)]);
      if (previous >= 0 && previous < rows.length) script.selectedIndex = previous;
      updateInfo();
    }
    script.onChange = _ -> updateInfo();
    button(panel, 'Refresh Scripts', refresh);
    button(panel, 'Toggle Enabled for Next Preview', () ->
    {
      var row = selected();
      if (row == null) return;
      session.scripts.setDisabled(row.backend, row.owner, row.path, !row.disabled);
      refresh();
    });
    button(panel, 'Toggle Force Discovery', () ->
    {
      var row = selected();
      if (row == null || !row.eligible || row.disabled)
      {
        status('Select an eligible, enabled Psych custom event or note-type script.');
        return;
      }
      function apply(accepted:Bool)
      {
        if (!accepted) return;
        session.scripts.setForced(row.backend, row.owner, row.path, !row.forced);
        refresh();
      }
      if (session.scripts.forceApproved) apply(true);
      else confirmExperimental(apply);
    });
    refresh();
  }

  function confirmExperimental(done:Bool->Void):Void
  {
    modal = Dialogs.messageBox(
      'Force-enabling scripts or suppressing script errors can cause instability or data loss. Reproduce a problem with these options off before reporting it.',
      'Experimental Script Execution', MessageBoxType.TYPE_YESNO, true, result ->
      {
        modal = null;
        var accepted = result == DialogButton.YES;
        if (accepted) session.scripts.forceApproved = true;
        done(accepted);
      });
  }

  function viewPanel(panel:VBox):Void
  {
    label(panel, 'Stage camera');
    var pan = new HBox();
    panel.addComponent(pan);
    button(pan, 'Left', () -> preview.panCamera(-100, 0));
    button(pan, 'Up', () -> preview.panCamera(0, -100));
    button(pan, 'Down', () -> preview.panCamera(0, 100));
    button(pan, 'Right', () -> preview.panCamera(100, 0));
    var zoom = new HBox();
    panel.addComponent(zoom);
    button(zoom, 'Zoom out', () -> preview.zoomCamera(-0.15));
    button(zoom, 'Zoom in', () -> preview.zoomCamera(0.15));
    button(panel, 'Edit Stage Objects', () -> open('Objects and Shaders', objectsPanel));
    checkbox(panel, 'Hide HUD on next song test', preview.hideHud, value -> preview.hideHud = value);
    button(panel, 'Focus Boyfriend', () -> preview.focusCharacter(0));
    button(panel, 'Focus Opponent', () -> preview.focusCharacter(1));
    button(panel, 'Focus Girlfriend', () -> preview.focusCharacter(2));
    button(panel, 'Reset window positions', windows.resetPositions);
  }

  function preparePlay():Void
  {
    if (detached) return;
    root.hidden = true;
    Cursor.hide();
    FlxG.cameras.remove(ui, false);
    FlxG.cameras.remove(world, false);
    detached = true;
    persistentUpdate = false;
    persistentDraw = false;
  }

  function onPreviewClosed(closed:FlxSubState):Void
  {
    if (Std.isOfType(closed, PlayState))
    {
      closedLoadGeneration = null;
      if (detached)
      {
        FlxG.cameras.reset(world);
        FlxG.cameras.add(ui, false);
        detached = false;
      }
      root.hidden = false;
      Cursor.show();
      FlxG.autoPause = originalAutoPause;
      persistentUpdate = true;
      persistentDraw = true;
      preview.returnFromTest();
      ModDebugWindows.redraw(root);
    }
    else if (!detached && Std.isOfType(closed, LoadingState))
      closedLoadGeneration = session?.previewGeneration();
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (closedLoadGeneration != null)
    {
      final generation = closedLoadGeneration;
      closedLoadGeneration = null;
      if (!detached && subState == null && preview?.testing == true && session?.ownsPreview(generation) == true)
      {
        preview.returnFromTest('Song load canceled. See Inspect → Timeline and Assets if loading failed.');
      }
    }
    if (subState != null) return;
    preview?.update(elapsed);
    #if FLX_KEYBOARD
    if (modal == null && haxe.ui.focus.FocusManager.instance.focus == null && preview?.stage != null)
    {
      var x = (FlxG.keys.pressed.D ? 1 : 0) - (FlxG.keys.pressed.A ? 1 : 0);
      var y = (FlxG.keys.pressed.S ? 1 : 0) - (FlxG.keys.pressed.W ? 1 : 0);
      if (x != 0 || y != 0) preview.panCamera(x * 450 * elapsed, y * 450 * elapsed);
    }
    #end
    var now = haxe.Timer.stamp();
    if (now - measuredAt >= 0.5)
    {
      if (fpsText != null && frames > 0)
        fpsText.text = 'Measured: ${Math.round(frames / (now - measuredAt))} FPS / ${Math.round(10000 * (now - measuredAt) / frames) / 10} ms per frame';
      frames = 0;
      measuredAt = now;
    }
    #if android
    if (FlxG.android.justPressed.BACK) back();
    #end
  }

  override function draw():Void
  {
    super.draw();
    if (subState == null) frames++;
  }

  function back():Void
  {
    if (preview?.testing == true) return;
    if (modal != null)
    {
      modal.hideDialog(DialogButton.CANCEL);
      return;
    }
    if (windows.closeTop()) return;
    leave();
  }

  function leave():Void
  {
    FlxG.switchState(() -> new MainMenuState());
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    if (root == null || detached) return;
    ui.setSize(FlxG.width, FlxG.height);
    root.width = FlxG.width;
    root.height = FlxG.height;
  }

  override public function destroy():Void
  {
    preview?.dispose();
    if (session != null)
    {
      FlxG.sound.volume = originalVolume;
      FlxG.sound.muted = originalMute;
    }
    session?.dispose();
    stopProfiler();
    modal?.hideDialog(DialogButton.CANCEL);
    if (detached)
    {
      ui.destroy();
      world.destroy();
    }
    Cursor.hide();
    FlxG.autoPause = originalAutoPause;
    super.destroy();
  }

  function status(message:String):Void
  {
    if (statusText != null) statusText.text = message;
  }

  static function button(panel:Component, text:String, action:Void->Void):Void
  {
    var control = new Button();
    control.text = text;
    control.height = #if android 40 #else 28 #end;
    control.onClick = _ -> action();
    panel.addComponent(control);
  }

  static function label(panel:Component, text:String):Label
  {
    var control = new Label();
    control.text = text;
    panel.addComponent(control);
    return control;
  }

  static function field(panel:Component, text:String):TextField
  {
    var control = new TextField();
    control.width = 230;
    control.text = text;
    panel.addComponent(control);
    return control;
  }

  static function checkbox(panel:Component, text:String, value:Bool, change:Bool->Void):Void
  {
    var control = new CheckBox();
    control.text = text;
    control.selected = value;
    control.onChange = _ -> change(control.selected);
    panel.addComponent(control);
  }

  function picker(panel:Component, title:String, values:Array<String>, allowBlank:Bool = false):DropDown
  {
    label(panel, title);
    var control = new DropDown();
    ModDebugWindows.bindDropDown(control, ui);
    control.width = 230;
    control.searchable = true;
    panel.addComponent(control);
    populate(control, allowBlank ? [''].concat(values) : values);
    return control;
  }

  static function populate(control:DropDown, values:Array<String>):Void
  {
    control.dataSource.clear();
    for (value in values) control.dataSource.add({text: value == '' ? '(none)' : value, id: value});
    control.selectedIndex = values.length > 0 ? 0 : -1;
  }

  static function selection(control:DropDown):String
  {
    return control.value?.id ?? '';
  }

  static function sortedIds(ids:Array<String>):Array<String>
  {
    var result = ids.copy();
    result.sort(Reflect.compare);
    return result;
  }

  static function selectIfPresent(control:DropDown, id:String):Void
  {
    for (i in 0...control.dataSource.size)
      if (control.dataSource.get(i)?.id == id)
      {
        control.selectedIndex = i;
        return;
      }
  }
}
#end
