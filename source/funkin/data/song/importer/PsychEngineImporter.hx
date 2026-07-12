package funkin.data.song.importer;

import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongCharacterData;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongData.SongTimeChange;
import haxe.Json;

using StringTools;

@:nullSafety(Off)
class PsychEngineImporter
{
  static final STRUMLINE_SIZE:Int = 4;

  public static function parseRaw(input:String, fileName:String = 'raw'):Dynamic
  {
    try
    {
      var parsed:Dynamic = Json.parse(input);
      return Reflect.field(parsed, 'song') ?? parsed;
    }
    catch (error)
    {
      trace('[PsychEngineImporter] Failed to parse ${fileName}: ${error}');
      return null;
    }
  }

  public static function inferDifficulty(fileName:String):String
  {
    var lower = fileName.toLowerCase();
    for (difficulty in ['nightmare', 'erect', 'hard', 'easy', 'normal'])
    {
      if (StringTools.endsWith(lower, '-${difficulty}')) return difficulty;
    }
    return 'normal';
  }

  public static function migrateMetadata(song:Dynamic, difficulty:String = 'normal'):SongMetadata
  {
    var metadata = new SongMetadata('Import', Constants.DEFAULT_ARTIST, Constants.DEFAULT_CHARTER, Constants.DEFAULT_VARIATION);
    metadata.generatedBy = 'Chart Editor Import (Psych Engine 1.0.4)';
    metadata.songName = stringValue(field(song, 'song'), 'Import');
    metadata.playData.stage = mapStage(stringValue(field(song, 'stage'), Constants.DEFAULT_STAGE));
    metadata.playData.difficulties = [difficulty];
    metadata.playData.songVariations = [];
    metadata.playData.characters = new SongCharacterData(stringValue(field(song, 'player1'), 'bf'),
      stringValue(field(song, 'gfVersion') ?? field(song, 'player3'), 'gf'), stringValue(field(song, 'player2'), 'dad'));
    metadata.timeChanges = migrateTimeChanges(song);
    return metadata;
  }

  public static function migrateChartData(song:Dynamic, difficulty:String = 'normal', ?externalEvents:Dynamic):SongChartData
  {
    var notes:Array<SongNoteData> = [];
    var events:Array<SongEventData> = [];
    var lastMustHit:Null<Bool> = null;

    for (section in arrayValue(field(song, 'notes')))
    {
      var mustHit = boolValue(field(section, 'mustHitSection'), false);
      var sectionNotes = arrayValue(field(section, 'sectionNotes'));

      if (sectionNotes.length > 0 && lastMustHit != mustHit)
      {
        lastMustHit = mustHit;
        events.push(new SongEventData(floatValue(sectionNotes[0][0], 0), 'FocusCamera', {char: mustHit ? 0 : 1}));
      }

      for (rawNote in sectionNotes)
      {
        var note = arrayValue(rawNote);
        if (note.length < 2) continue;

        var time = floatValue(note[0], 0);
        var noteData = intValue(note[1], 0);
        if (noteData < 0)
        {
          importSectionEvent(time, note, events);
          continue;
        }

        noteData %= STRUMLINE_SIZE * 2;
        if (!mustHit) noteData = noteData >= STRUMLINE_SIZE ? noteData - STRUMLINE_SIZE : noteData + STRUMLINE_SIZE;

        var length = note.length > 2 ? floatValue(note[2], 0) : 0;
        var kind = note.length > 3 ? psychNoteKind(note[3]) : '';
        notes.push(new SongNoteData(time, noteData, length, kind));
      }
    }

    importEventArray(field(song, 'events'), events);
    if (externalEvents != null) importEventArray(field(externalEvents, 'events') ?? field(field(externalEvents, 'song'), 'events'), events);
    deduplicateEvents(events);

    var speed = floatValue(field(song, 'speed'), 1);
    return new SongChartData([difficulty => speed], events, [difficulty => notes]);
  }

  static function migrateTimeChanges(song:Dynamic):Array<SongTimeChange>
  {
    var changes = [new SongTimeChange(0, floatValue(field(song, 'bpm'), Constants.DEFAULT_BPM))];
    for (section in arrayValue(field(song, 'notes')))
    {
      if (!boolValue(field(section, 'changeBPM'), false)) continue;
      var notes = arrayValue(field(section, 'sectionNotes'));
      if (notes.length == 0) continue;
      changes.push(new SongTimeChange(floatValue(arrayValue(notes[0])[0], 0), floatValue(field(section, 'bpm'), Constants.DEFAULT_BPM)));
    }
    return changes;
  }

  static function importSectionEvent(time:Float, note:Array<Dynamic>, output:Array<SongEventData>):Void
  {
    if (note.length < 3) return;
    if (Std.isOfType(note[2], Array))
    {
      for (event in arrayValue(note[2])) importEvent(time, arrayValue(event), output);
    }
    else
    {
      importEvent(time, [note[2], note.length > 3 ? note[3] : '', note.length > 4 ? note[4] : ''], output);
    }
  }

  static function importEventArray(rawEvents:Dynamic, output:Array<SongEventData>):Void
  {
    for (rawGroup in arrayValue(rawEvents))
    {
      var group = arrayValue(rawGroup);
      if (group.length < 2) continue;
      var time = floatValue(group[0], 0);
      for (rawEvent in arrayValue(group[1])) importEvent(time, arrayValue(rawEvent), output);
    }
  }

  static function importEvent(time:Float, event:Array<Dynamic>, output:Array<SongEventData>):Void
  {
    if (event.length == 0) return;
    var name = stringValue(event[0], '');
    var value1 = event.length > 1 ? stringValue(event[1], '') : '';
    var value2 = event.length > 2 ? stringValue(event[2], '') : '';

    switch (name.toLowerCase().trim())
    {
      case 'change character':
        output.push(new SongEventData(time, 'ChangeCharacter', {char: characterTarget(value1), id: value2}));
      case 'change stage':
        output.push(new SongEventData(time, 'ChangeStage', {stage: mapStage(value1)}));
      case 'play animation':
        output.push(new SongEventData(time, 'PlayAnimation', {anim: value1, target: animationTarget(value2), force: true}));
      case 'camera follow pos':
        output.push(new SongEventData(time, 'FocusCamera', {char: -1, x: floatValue(value1, 0), y: floatValue(value2, 0)}));
      default:
        output.push(new SongEventData(time, name, {value1: value1, value2: value2}));
    }
  }

  static function deduplicateEvents(events:Array<SongEventData>):Void
  {
    var seen:Map<String, Bool> = [];
    var index = events.length - 1;
    while (index >= 0)
    {
      var event = events[index];
      var key = '${event.time}|${event.eventKind}|${Json.stringify(event.value)}';
      if (seen.exists(key)) events.splice(index, 1);
      else seen.set(key, true);
      index--;
    }
    events.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
  }

  static function characterTarget(value:String):Int
  {
    return switch (value.toLowerCase().trim())
    {
      case 'dad' | 'opponent' | '1': 1;
      case 'gf' | 'girlfriend' | '2': 2;
      default: 0;
    }
  }

  static function animationTarget(value:String):String
  {
    return switch (value.toLowerCase().trim())
    {
      case 'dad' | 'opponent': 'dad';
      case 'gf' | 'girlfriend': 'girlfriend';
      case 'bf' | 'boyfriend' | 'player' | '': 'boyfriend';
      default: value;
    }
  }

  static function psychNoteKind(value:Dynamic):String
  {
    if (value == null || value == false || value == '') return '';
    if (value == true) return 'alt';
    return stringValue(value, '');
  }

  static function mapStage(stage:String):String
  {
    return switch (stage.toLowerCase())
    {
      case 'stage': 'mainStage';
      case 'spooky': 'spookyMansion';
      case 'philly': 'phillyTrain';
      case 'limo': 'limoRide';
      case 'mall': 'mallXmas';
      case 'tank': 'tankmanBattlefield';
      default: stage;
    }
  }

  static inline function field(value:Dynamic, name:String):Dynamic
  {
    return value == null ? null : Reflect.field(value, name);
  }

  static inline function arrayValue(value:Dynamic):Array<Dynamic>
  {
    return Std.isOfType(value, Array) ? cast value : [];
  }

  static function stringValue(value:Dynamic, fallback:String):String
  {
    return value == null ? fallback : Std.string(value);
  }

  static function floatValue(value:Dynamic, fallback:Float):Float
  {
    var result = Std.parseFloat(Std.string(value));
    return Math.isNaN(result) ? fallback : result;
  }

  static function intValue(value:Dynamic, fallback:Int):Int
  {
    var result = Std.parseInt(Std.string(value));
    return result == null ? fallback : result;
  }

  static function boolValue(value:Dynamic, fallback:Bool):Bool
  {
    if (value == null) return fallback;
    return value == true || Std.string(value).toLowerCase() == 'true';
  }
}
