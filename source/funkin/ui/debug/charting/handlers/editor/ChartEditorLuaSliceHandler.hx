package funkin.ui.debug.charting.handlers.editor;

#if FEATURE_CHART_EDITOR
import flixel.util.FlxTimer;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongDataUtils;
import funkin.play.notes.StrumlineNote;
import funkin.save.Save;
import funkin.ui.debug.charting.commands.notes.RandomizeNotesCommand;
import funkin.ui.debug.charting.commands.items.CutItemsCommand;
import funkin.ui.debug.charting.commands.items.PasteItemsCommand;
import funkin.ui.debug.charting.commands.items.RemoveItemsCommand;
import funkin.ui.debug.charting.commands.selection.SetItemSelectionCommand;
import funkin.ui.debug.charting.commands.selection.SelectItemsCommand;
import funkin.ui.debug.charting.commands.selection.DeselectItemsCommand;
import funkin.ui.debug.charting.commands.selection.SelectAllItemsCommand;
import funkin.ui.debug.charting.commands.selection.DeselectAllItemsCommand;
import funkin.ui.debug.charting.handlers.ui.ChartEditorToolboxHandler;
import haxe.ui.core.Screen;
import haxe.ui.components.NumberStepper;
import haxe.ui.containers.menus.MenuCheckBox;

/** LuaSlice editor behavior, adapted to the preview's shared chart state and handlers. */
@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorLuaSliceHandler
{
  public static function buildVortexReceptors(state:ChartEditorState):Void
  {
    state.refreshVortexReceptors();
    state.vortexReceptors.visible = state.vortexEnabled;
    state.vortexReceptors.zIndex = 23;
    state.add(state.vortexReceptors);
  }

  public static function refreshVortexReceptors(state:ChartEditorState):Void
  {
    for (receptor in state.vortexReceptors.members)
    {
      receptor?.destroy();
    }
    state.vortexReceptors.clear();
    state.vortexConfirmUntil = [for (_ in 0...(ChartEditorState.STRUMLINE_SIZE * 2)) 0.0];
    state.vortexHoldUntil = [for (_ in 0...(ChartEditorState.STRUMLINE_SIZE * 2)) 0.0];

    state.vortexNoteStyleId = state.currentSongNoteStyle;
    final noteStyle = NoteStyleRegistry.instance.fetchEntry(state.vortexNoteStyleId) ?? NoteStyleRegistry.instance.fetchDefault();
    for (column in 0...(ChartEditorState.STRUMLINE_SIZE * 2))
    {
      final receptor = new StrumlineNote(noteStyle, column >= ChartEditorState.STRUMLINE_SIZE, column % ChartEditorState.STRUMLINE_SIZE);
      receptor.forceActive = true;
      receptor.alpha = 1;
      final visibleWidth:Float = receptor.frame?.frame.width ?? receptor.width;
      if (visibleWidth > 0)
      {
        final editorScale:Float = ChartEditorState.GRID_SIZE / visibleWidth;
        receptor.scale.set(editorScale, editorScale);
        receptor.updateHitbox();
      }
      state.vortexReceptors.add(receptor);
    }
  }

  public static function resetVortexReceptors(state:ChartEditorState):Void
  {
    for (column in 0...state.vortexReceptors.members.length)
    {
      state.vortexConfirmUntil[column] = 0;
      state.vortexHoldUntil[column] = 0;
      final receptor = state.vortexReceptors.members[column];
      if (receptor != null)
      {
        receptor.playStatic();
      }
    }
  }

  public static function handleVortex(state:ChartEditorState):Void
  {
    if (state.vortexNoteStyleId != state.currentSongNoteStyle) state.refreshVortexReceptors();
    if (!state.vortexEnabled || state.gridTiledSprite == null) return;

    final songPosition:Float = Conductor.instance.songPosition + Conductor.instance.instrumentalOffset;
    final lineY:Float = state.transformChartY(ChartEditorState.GRID_INITIAL_Y_POS + state.playheadPositionInPixels, 0);

    for (column in 0...state.vortexReceptors.members.length)
    {
      final receptor = state.vortexReceptors.members[column];
      if (receptor == null) continue;

      receptor.x = state.gridTiledSprite.x + column * ChartEditorState.GRID_SIZE + (ChartEditorState.GRID_SIZE - receptor.width) * 0.5;
      receptor.y = state.isViewDownscroll ? lineY - receptor.height : lineY;
      receptor.active = true;

      if (state.vortexHoldUntil[column] > songPosition)
      {
        receptor.holdConfirm();
        continue;
      }

      if (state.vortexConfirmUntil[column] > 0 && state.vortexConfirmUntil[column] <= songPosition)
      {
        state.vortexConfirmUntil[column] = 0;
        state.vortexHoldUntil[column] = 0;
        receptor.playStatic();
      }
    }
  }

  public static function playVortexNote(state:ChartEditorState, noteData:SongNoteData):Void
  {
    final column:Int = ChartEditorNoteUtil.noteDataToGridColumn(noteData.data);
    if (column < 0 || column >= state.vortexReceptors.members.length) return;

    final receptor = state.vortexReceptors.members[column];
    if (receptor == null) return;

    final tapDisplayTime:Float = Math.max(50.0, Conductor.instance.getTypeLengthAtMs(noteData.time, 'step') * 0.5);
    final noteEndTime:Float = noteData.length > 0 ? noteData.time + noteData.length : noteData.time + tapDisplayTime;
    state.vortexConfirmUntil[column] = Math.max(state.vortexConfirmUntil[column], noteEndTime);
    if (noteData.length > 0) state.vortexHoldUntil[column] = Math.max(state.vortexHoldUntil[column], noteEndTime);
    receptor.playConfirm();
  }

  public static function queuePreferenceSave(state:ChartEditorState):Void
  {
    if (!state.exists || state.criticalFailure) return;
    state.cancelPreferenceSaveTimer();
    state.preferenceSaveTimer = new FlxTimer().start(0.35, function(_)
    {
      state.preferenceSaveTimer = null;
      state.writePreferences(state.saveDataDirty);
    });
  }

  public static function cancelPreferenceSaveTimer(state:ChartEditorState):Void
  {
    if (state.preferenceSaveTimer == null) return;
    state.preferenceSaveTimer.cancel();
    state.preferenceSaveTimer.destroy();
    state.preferenceSaveTimer = null;
  }

  public static function randomizeChartNotes(state:ChartEditorState, includePlayer:Bool, includeOpponent:Bool):Void
  {
    final notes = state.currentSongChartNoteData.filter(function(note:SongNoteData):Bool
    {
      final playerNote = note.getStrumlineIndex(ChartEditorState.STRUMLINE_SIZE) == 0;
      return (playerNote && includePlayer) || (!playerNote && includeOpponent);
    });
    final label = includePlayer && includeOpponent ? 'Both' : includePlayer ? 'Player' : 'Opponent';
    state.performCommand(new RandomizeNotesCommand(notes, label));
  }

  public static function flushEditorPreferences(state:ChartEditorState):Void
  {
    cancelPreferenceSaveTimer(state);
    state.writePreferences(state.saveDataDirty);
  }

  #if FEATURE_TOUCH_CONTROLS
  public static function handleTouchShortcuts(state:ChartEditorState, elapsed:Float):Bool
  {
    state.touchCursorPress = false;
    state.touchCursorRelease = false;
    state.touchCursorActive = false;
    var finger:Null<flixel.input.touch.FlxTouch> = null;
    var count:Int = 0;
    for (touch in FlxG.touches.list)
    {
      if (!touch.pressed) continue;
      if (finger == null) finger = touch;
      count++;
    }
    if (state.isHaxeUIDialogOpen || state.isPlaytesting)
    {
      state.touchGesture.reset();
      return true;
    }
    var inGrid = finger != null && state.gridTiledSprite != null && finger.overlaps(state.gridTiledSprite);
    var inPreview = finger != null && ((state.notePreview != null && finger.overlaps(state.notePreview))
      || (state.healthIconBF != null && finger.overlaps(state.healthIconBF)) || (state.healthIconDad != null && finger.overlaps(state.healthIconDad)));
    var x = finger?.viewX ?? FlxG.mouse.viewX;
    var y = finger?.viewY ?? FlxG.mouse.viewY;
    var overUI = Screen.instance.hasSolidComponentUnderPoint(x, y);
    if (finger != null)
      state.touchPointer.setRawPositionUnsafe(finger.gameX * FlxG.scaleMode.scale.x, finger.gameY * FlxG.scaleMode.scale.y);
    if (finger?.justPressed == true)
    {
      state.touchPressPointer.setRawPositionUnsafe(finger.gameX * FlxG.scaleMode.scale.x, finger.gameY * FlxG.scaleMode.scale.y);
      state.touchScrollPosition = state.scrollPositionInPixels;
      state.touchPlayheadPosition = state.playheadPositionInPixels;
    }
    var eligible = (inGrid || inPreview) && !overUI && !state.playbarHeadDragging && !state.gridPlayheadScrollAreaPressed
      && state.scrollAnchorScreenPos == null && Math.abs((state.currentScrollEase ?? state.scrollPositionInPixels) - state.scrollPositionInPixels) < 1
      && Math.abs(state.touchScrollPosition - state.scrollPositionInPixels) < 1 && Math.abs(state.touchPlayheadPosition - state.playheadPositionInPixels) < 1;
    if (finger?.justPressed == true && eligible) ChartEditorToolboxHandler.clearHaxeUIFocus();
    var action = state.touchGesture.step(finger?.touchPointID, finger?.justPressed ?? false, x, y, count, elapsed, eligible, state.longPressDuration);
    switch (action)
    {
      case OpenMenu:
        state.lastGridClickTime = 0;
        state.lastGridClickTarget = null;
        state.openTouchContextMenu(finger, x, y);
        return true;
      case Waiting | Blocked:
        return true;
      case Press:
        state.touchCursorActive = true;
        state.touchCursorPress = true;
        // Replayed taps and the first drag frame start at the original press position.
        state.touchPointer.setRawPositionUnsafe(state.touchPressPointer.gameX * FlxG.scaleMode.scale.x, state.touchPressPointer.gameY * FlxG.scaleMode.scale.y);
      case Release:
        state.touchCursorActive = true;
        state.touchCursorRelease = true;
      case Drag:
        state.touchCursorActive = true;
      case Idle:
    }
    return false;
  }

  public static function openTouchContextMenu(state:ChartEditorState, finger:flixel.input.touch.FlxTouch, x:Float, y:Float):Void
  {
    if (finger == null || state.touchContextMenu != null) return;
    var note:Null<SongNoteData> = null;
    var songEvent:Null<SongEventData> = null;
    for (sprite in state.renderedNotes.members)
      if (sprite != null && sprite.alive && finger.overlaps(sprite)) { note = sprite.noteData; break; }
    if (note == null) for (sprite in state.renderedHoldNotes.members)
      if (sprite != null && sprite.alive && finger.overlaps(sprite)) { note = sprite.noteData; break; }
    if (note == null) for (sprite in state.renderedEvents.members)
      if (sprite != null && sprite.alive && finger.overlaps(sprite)) { songEvent = sprite.eventData; break; }

    var selected = (note != null && state.isNoteSelected(note)) || (songEvent != null && state.isEventSelected(songEvent));
    var notes = note != null && !selected ? [note] : state.currentNoteSelection.copy();
    var events = songEvent != null && !selected ? [songEvent] : state.currentEventSelection.copy();
    if (note != null && !selected) events = [];
    if (songEvent != null && !selected) notes = [];
    var hasItems = notes.length > 0 || events.length > 0;
    var atGrid = state.gridTiledSprite != null && finger.overlaps(state.gridTiledSprite);
    var time = state.scrollPositionInMs + state.playheadPositionInMs;
    if (atGrid)
    {
      var cursorY = state.gridYToChartY(y);
      var fractionalStep = ChartEditorTimeScale.pixelsToStep(cursorY) / state.noteSnapRatio;
      var step = (state.isViewDownscroll ? Math.ceil(fractionalStep) : Math.floor(fractionalStep)) * state.noteSnapRatio;
      time = Math.max(0, Conductor.instance.getStepTimeInMs(step));
    }
    var actions:Array<funkin.ui.debug.charting.dialogs.ChartEditorTouchContextMenu.ChartTouchMenuAction> = [];
    var add = (label:String, enabled:Bool, run:Void->Void) -> actions.push({text: label, enabled: enabled, run: run});
    add('Copy', hasItems, () ->
    {
      state.performCommand(new SetItemSelectionCommand(notes.copy(), events.copy()));
      state.copySelection();
    });
    add('Cut', hasItems, () -> state.performCommand(new CutItemsCommand(notes.copy(), events.copy())));
    add('Paste here', SongDataUtils.readItemsFromClipboard().valid == true, () -> state.performCommand(new PasteItemsCommand(time)));
    add('Delete', hasItems, () -> state.performCommand(new RemoveItemsCommand(notes.copy(), events.copy())));
    if (note != null || songEvent != null)
    {
      add(selected ? 'Deselect item' : 'Select item', true, () ->
      {
        if (selected) state.performCommand(new DeselectItemsCommand(note != null ? [note] : [], songEvent != null ? [songEvent] : []));
        else state.performCommand(new SelectItemsCommand(note != null ? [note] : [], songEvent != null ? [songEvent] : []));
      });
    }
    add('Select all notes', true, () -> state.performCommand(new SelectAllItemsCommand(true, false)));
    add('Select all events', true, () -> state.performCommand(new SelectAllItemsCommand(false, true)));
    add('Deselect all', state.currentNoteSelection.length + state.currentEventSelection.length > 0, () -> state.performCommand(new DeselectAllItemsCommand()));
    add('Note Properties', notes.length > 0 || !hasItems, () ->
    {
      if (hasItems) state.performCommand(new SetItemSelectionCommand(notes.copy(), events.copy()));
      state.showToolbox(ChartEditorState.CHART_EDITOR_TOOLBOX_NOTE_DATA_LAYOUT);
    });
    add('Event Properties', events.length > 0 || !hasItems, () ->
    {
      if (hasItems) state.performCommand(new SetItemSelectionCommand(notes.copy(), events.copy()));
      state.showToolbox(ChartEditorState.CHART_EDITOR_TOOLBOX_EVENT_DATA_LAYOUT);
    });
    add('Playtest Properties', true, () -> state.showToolbox(ChartEditorState.CHART_EDITOR_TOOLBOX_PREFERENCES_LAYOUT));
    add('Toggle Player Preview', true, () ->
      state.setToolboxState(ChartEditorState.CHART_EDITOR_TOOLBOX_PLAYER_PREVIEW_LAYOUT, !state.menubarItemToggleToolboxPlayerPreview.selected));
    add('Toggle Opponent Preview', true, () ->
      state.setToolboxState(ChartEditorState.CHART_EDITOR_TOOLBOX_OPPONENT_PREVIEW_LAYOUT, !state.menubarItemToggleToolboxOpponentPreview.selected));
    add('Undo', state.undoHistory.length > 0, state.undoLastCommand);
    add('Redo', state.redoHistory.length > 0, state.redoLastCommand);
    var heading = selected ? 'Selection' : note != null ? 'Note' : songEvent != null ? 'Song event' : atGrid ? 'Chart grid' : 'Preview';
    state.touchContextMenu = new funkin.ui.debug.charting.dialogs.ChartEditorTouchContextMenu(state, heading, actions);
    state.touchContextMenu.onDialogClosed = _ ->
    {
      state.isHaxeUIDialogOpen = false;
      state.touchContextMenu = null;
      ChartEditorToolboxHandler.clearHaxeUIFocus();
    };
    state.touchContextMenu.showDialog(true);
  }
  #end

  public static function setupLuaSliceEditorUI(state:ChartEditorState):Void
  {
    var vortex = state.root.findComponent('menubarItemVortex', MenuCheckBox);
    if (vortex != null)
    {
      vortex.selected = state.vortexEnabled;
      vortex.onChange = event ->
      {
        state.vortexEnabled = event.value;
        state.vortexReceptors.visible = state.vortexEnabled;
        state.resetVortexReceptors();
        state.queuePreferenceSave();
      };
    }
    var doubleDelete = state.root.findComponent('menubarPreferenceDoubleClickDelete', MenuCheckBox);
    if (doubleDelete != null)
    {
      doubleDelete.selected = state.doubleClickDeleteEnabled;
      doubleDelete.onChange = event ->
      {
        state.doubleClickDeleteEnabled = event.value;
        state.lastGridClickTarget = null;
        state.queuePreferenceSave();
      };
    }
    var autoSaveMinutes = state.root.findComponent('menubarPreferenceAutoSaveMinutes', NumberStepper);
    if (autoSaveMinutes != null)
    {
      autoSaveMinutes.pos = Save.instance.chartEditorAutoSaveMinutes.value;
      autoSaveMinutes.onChange = _ ->
      {
        Save.instance.chartEditorAutoSaveMinutes.value = Std.int(Math.max(1, autoSaveMinutes.pos));
        if (state.saveDataDirty) state.queueAutoSave();
      };
    }
    #if FEATURE_TOUCH_CONTROLS
    var duration = state.root.findComponent('menubarPreferenceLongPressDuration', NumberStepper);
    if (duration != null)
    {
      duration.pos = state.longPressDuration;
      duration.onChange = _ ->
      {
        state.longPressDuration = luaslice.ui.ChartEditorTouchGesture.normalizeDuration(duration.pos ?? 1.5);
        state.queuePreferenceSave();
      };
    }
    #else
    var durationRow = state.root.findComponent('menubarLongPressDurationRow');
    if (durationRow != null) durationRow.hidden = true;
    #end
    for (side in ['Player', 'Opponent', 'Both'])
    {
      var randomize = state.root.findComponent('menubarItemRandomize' + side, haxe.ui.containers.menus.MenuItem);
      if (randomize != null) randomize.onClick = _ -> state.randomizeChartNotes(side != 'Opponent', side != 'Player');
    }
    state.menubarItemToggleToolboxOffsets = state.root.findComponent('menubarItemToggleToolboxOffsets', MenuCheckBox);
    state.menubarItemToggleToolboxFreeplay = state.root.findComponent('menubarItemToggleToolboxFreeplay', MenuCheckBox);
    bindToolboxMenu(state, state.menubarItemToggleToolboxOffsets, ChartEditorState.CHART_EDITOR_TOOLBOX_OFFSETS_LAYOUT);
    bindToolboxMenu(state, state.menubarItemToggleToolboxFreeplay, ChartEditorState.CHART_EDITOR_TOOLBOX_FREEPLAY_LAYOUT);

    // Target preferences live in one panel. Observe it once instead of writing saves every frame.
    state.root.registerEvent(haxe.ui.events.UIEvent.CHANGE, _ -> state.queuePreferenceSave());
    var preferences = state.getToolboxUnCast(ChartEditorState.CHART_EDITOR_TOOLBOX_PREFERENCES_LAYOUT);
    if (preferences != null) preferences.registerEvent(haxe.ui.events.UIEvent.CHANGE, _ -> state.queuePreferenceSave());
  }

  static function bindToolboxMenu(state:ChartEditorState, menu:Null<MenuCheckBox>, layout:String):Void
  {
    if (menu == null) return;
    menu.onChange = event -> state.setToolboxStateFromMenu(layout, menu, event.value);
  }

  public static function resetLuaSliceTouch(state:ChartEditorState):Void
  {
    #if FEATURE_TOUCH_CONTROLS
    state.touchGesture.reset();
    state.touchCursorActive = false;
    state.touchCursorPress = false;
    state.touchCursorRelease = false;
    state.touchContextMenu?.hideDialog(haxe.ui.containers.dialogs.Dialog.DialogButton.CANCEL);
    state.touchContextMenu = null;
    #end
  }
}
#end
