package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;

@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class RandomizeNotesCommand implements ChartEditorCommand
{
  var notes:Array<SongNoteData>;
  var randomizedNotes:Array<SongNoteData> = [];
  var sideName:String;

  public function new(notes:Array<SongNoteData>, sideName:String)
  {
    this.notes = notes.copy();
    this.sideName = sideName;

    final orderedNotes = this.notes.copy();
    orderedNotes.sort(function(a:SongNoteData, b:SongNoteData):Int
    {
      final aStrumline = a.getStrumlineIndex(ChartEditorState.STRUMLINE_SIZE);
      final bStrumline = b.getStrumlineIndex(ChartEditorState.STRUMLINE_SIZE);
      if (aStrumline != bStrumline) return aStrumline - bStrumline;
      if (a.time < b.time) return -1;
      if (a.time > b.time) return 1;
      return a.getDirection() - b.getDirection();
    });

    final currentTimeByStrumline:Map<Int, Int> = [];
    final currentGroupLanes:Map<Int, Array<Int>> = [];
    final previousGroupLanes:Map<Int, Array<Int>> = [];
    final holdBlockedUntil:Map<String, Float> = [];

    for (note in orderedNotes)
    {
      final randomized = note.clone();
      final strumline = note.getStrumlineIndex(ChartEditorState.STRUMLINE_SIZE);
      final timeKey = Math.round(note.time * 1000);
      final currentTime = currentTimeByStrumline.get(strumline);

      if (currentTime == null || currentTime != timeKey)
      {
        previousGroupLanes.set(strumline, currentGroupLanes.get(strumline)?.copy() ?? []);
        currentGroupLanes.set(strumline, []);
        currentTimeByStrumline.set(strumline, timeKey);
      }

      final usedNow = currentGroupLanes.get(strumline) ?? [];
      final usedPreviously = previousGroupLanes.get(strumline) ?? [];
      final available:Array<Int> = [];
      for (lane in 0...ChartEditorState.STRUMLINE_SIZE)
      {
        if (!usedNow.contains(lane)) available.push(lane);
      }

      final originalLane = note.getDirection();
      var candidates:Array<Int> = [];

      function collectCandidates(avoidPrevious:Bool, avoidHeldLane:Bool, avoidOriginal:Bool):Array<Int>
      {
        return available.filter(function(lane:Int):Bool
        {
          if (avoidPrevious && usedPreviously.contains(lane)) return false;
          if (avoidOriginal && lane == originalLane) return false;

          if (avoidHeldLane)
          {
            final blockedUntil = holdBlockedUntil.get('${strumline}:${lane}');
            if (blockedUntil != null && note.time <= blockedUntil + 1) return false;
          }

          return true;
        });
      }

      final selectionRules = [
        [true, true, true],
        [true, true, false],
        [false, true, true],
        [false, true, false],
        [true, false, true],
        [true, false, false],
        [false, false, true],
        [false, false, false]
      ];

      for (rule in selectionRules)
      {
        candidates = collectCandidates(rule[0], rule[1], rule[2]);
        if (candidates.length > 0) break;
      }

      FlxG.random.shuffle(candidates);
      final lane:Int = candidates[0] ?? originalLane;
      randomized.data = strumline * ChartEditorState.STRUMLINE_SIZE + lane;
      randomizedNotes.push(randomized);
      usedNow.push(lane);

      if (note.length > 0)
      {
        final holdKey = '${strumline}:${lane}';
        final holdEnd = note.time + note.length;
        final previousHoldEnd = holdBlockedUntil.get(holdKey);
        if (previousHoldEnd == null || holdEnd > previousHoldEnd) holdBlockedUntil.set(holdKey, holdEnd);
      }
    }
  }

  public function execute(state:ChartEditorState):Void
  {
    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, notes).concat(randomizedNotes);
    state.currentNoteSelection = randomizedNotes;
    state.currentEventSelection = [];
    refresh(state);
  }

  public function undo(state:ChartEditorState):Void
  {
    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, randomizedNotes).concat(notes);
    state.currentNoteSelection = notes;
    state.currentEventSelection = [];
    refresh(state);
  }

  function refresh(state:ChartEditorState):Void
  {
    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.sortChartData();
  }

  public function shouldAddToHistory(state:ChartEditorState):Bool return notes.length > 0;

  public function toString():String return 'Randomize ${sideName} Notes';
}
#end
