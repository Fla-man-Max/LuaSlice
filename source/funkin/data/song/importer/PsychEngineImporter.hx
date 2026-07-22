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
      var cleanInput = input.trim();
      if (cleanInput.length > 0 && cleanInput.charCodeAt(0) == 0xFEFF) cleanInput = cleanInput.substr(1);
      var parsed:Dynamic = Json.parse(cleanInput);
      return Reflect.field(parsed, 'song') ?? parsed;
    }
    catch (error)
    {
      trace('[PsychEngineImporter] Failed to parse ${fileName}: ${error}');
      return null;
    }
  }

  public static function isChart(song:Dynamic):Bool
  {
    return song != null && field(song, 'song') != null && Std.isOfType(field(song, 'notes'), Array);
  }

  public static function inferDifficulty(fileName:String, songName:String = ''):String
  {
    var lower = fileName.toLowerCase();
    for (difficulty in ['nightmare', 'erect', 'hard', 'easy', 'normal'])
    {
      if (StringTools.endsWith(lower, '-${difficulty}')) return difficulty;
    }
    final songId = songName.toLowerCase().trim().replace(' ', '-');
    if (songId != '' && lower == songId) return 'normal';
    if (songId != '' && lower.startsWith('${songId}-'))
    {
      final custom = lower.substr(songId.length + 1).trim();
      if (custom != '') return custom;
    }
    return 'normal';
  }

  public static function migrateMetadata(song:Dynamic, difficulty:String = 'normal'):SongMetadata
  {
    var metadata = new SongMetadata('Import', Constants.DEFAULT_ARTIST, Constants.DEFAULT_CHARTER, Constants.DEFAULT_VARIATION);
    metadata.generatedBy = 'Chart Editor Import (Psych Engine 1.0.4)';
    metadata.songName = nonEmptyString(field(song, 'song'), 'Import');
    metadata.playData.stage = mapStage(psychStage(metadata.songName, nonEmptyString(field(song, 'stage'), '')));
    metadata.playData.difficulties = [difficulty];
    metadata.playData.songVariations = [];
    metadata.playData.characters = new SongCharacterData(nonEmptyString(field(song, 'player1'), 'bf'),
      nonEmptyString(field(song, 'gfVersion') ?? field(song, 'player3'), 'gf'), nonEmptyString(field(song, 'player2'), 'dad'));
    metadata.timeChanges = migrateTimeChanges(song);
    return metadata;
  }

  public static function migrateChartData(song:Dynamic, difficulty:String = 'normal', ?externalEvents:Dynamic):SongChartData
  {
    var notes:Array<SongNoteData> = [];
    var events:Array<SongEventData> = [];
    var lastCameraTarget:Null<Int> = null;
    var sectionStart:Float = 0;
    var currentBpm = validBpm(field(song, 'bpm'), Constants.DEFAULT_BPM);
    final psychV1 = stringValue(field(song, 'format'), '').toLowerCase().startsWith('psych_v1');

    for (section in arrayValue(field(song, 'notes')))
    {
      var mustHit = boolValue(field(section, 'mustHitSection'), false);
      var sectionNotes = arrayValue(field(section, 'sectionNotes'));
      if (boolValue(field(section, 'changeBPM'), false)) currentBpm = validBpm(field(section, 'bpm'), currentBpm);

      final cameraTarget = boolValue(field(section, 'gfSection'), false) ? 2 : (mustHit ? 0 : 1);
      if (lastCameraTarget != cameraTarget)
      {
        lastCameraTarget = cameraTarget;
        events.push(new SongEventData(sectionStart, 'FocusCamera', {char: cameraTarget}));
      }

      for (rawNote in sectionNotes)
      {
        var note = arrayValue(rawNote);
        if (note.length < 2) continue;

        var time = floatValue(note[0], 0);
        var noteData = intValue(note[1], 0);
        if (noteData < 0)
        {
          importSectionEvent(time, note, events, currentBpm);
          continue;
        }

        noteData %= STRUMLINE_SIZE * 2;
        if (!psychV1 && !mustHit) noteData = noteData >= STRUMLINE_SIZE ? noteData - STRUMLINE_SIZE : noteData + STRUMLINE_SIZE;

        var length = note.length > 2 ? floatValue(note[2], 0) : 0;
        var kind = note.length > 3 ? psychNoteKind(note[3]) : '';
        notes.push(new SongNoteData(time, noteData, length, kind));
      }

      final sectionBeats = getSectionBeats(section);
      sectionStart += sectionBeats * 60000 / currentBpm;
    }

    final baseBpm = floatValue(field(song, 'bpm'), Constants.DEFAULT_BPM);
    importEventArray(field(song, 'events'), events, baseBpm);
    if (externalEvents != null) importEventArray(field(externalEvents, 'events') ?? field(field(externalEvents, 'song'), 'events'), events, baseBpm);
    deduplicateEvents(events);

    var speed = floatValue(field(song, 'speed'), 1);
    return new SongChartData([difficulty => speed], events, [difficulty => notes]);
  }

  static function migrateTimeChanges(song:Dynamic):Array<SongTimeChange>
  {
    var currentBpm = validBpm(field(song, 'bpm'), Constants.DEFAULT_BPM);
    var sectionStart:Float = 0;
    var changes = [new SongTimeChange(0, currentBpm)];
    for (section in arrayValue(field(song, 'notes')))
    {
      if (boolValue(field(section, 'changeBPM'), false))
      {
        final nextBpm = validBpm(field(section, 'bpm'), currentBpm);
        if (nextBpm != currentBpm)
        {
          currentBpm = nextBpm;
          changes.push(new SongTimeChange(sectionStart, currentBpm));
        }
      }
      final sectionBeats = getSectionBeats(section);
      sectionStart += sectionBeats * 60000 / currentBpm;
    }
    return changes;
  }

  static function importSectionEvent(time:Float, note:Array<Dynamic>, output:Array<SongEventData>, bpm:Float):Void
  {
    if (note.length < 3) return;
    if (Std.isOfType(note[2], Array))
    {
      for (event in arrayValue(note[2])) importEvent(time, arrayValue(event), output, bpm);
    }
    else
    {
      importEvent(time, [note[2], note.length > 3 ? note[3] : '', note.length > 4 ? note[4] : ''], output, bpm);
    }
  }

  static function importEventArray(rawEvents:Dynamic, output:Array<SongEventData>, bpm:Float):Void
  {
    for (rawGroup in arrayValue(rawEvents))
    {
      var group = arrayValue(rawGroup);
      if (group.length < 2) continue;
      var time = floatValue(group[0], 0);
      for (rawEvent in arrayValue(group[1])) importEvent(time, arrayValue(rawEvent), output, bpm);
    }
  }

  static function importEvent(time:Float, event:Array<Dynamic>, output:Array<SongEventData>, bpm:Float):Void
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
        if (value1.trim() != '' || value2.trim() != '')
          output.push(new SongEventData(time, 'FocusCamera', {char: -1, x: floatValue(value1, 0), y: floatValue(value2, 0)}));
        else
          output.push(new SongEventData(time, 'FocusCamera', {char: cameraTargetAt(output, time)}));
      case 'screen shake':
        importScreenShake(time, value1, 'game', output);
        importScreenShake(time, value2, 'hud', output);
      case 'change scroll speed':
        output.push(new SongEventData(time, 'ScrollSpeed', {
          scroll: floatValue(value1, 1),
          duration: floatValue(value2, 0) * bpm / 15,
          ease: 'linear',
          strumline: 'both',
          absolute: false,
          returnToOriginal: false
        }));
      case 'play sound':
        output.push(new SongEventData(time, 'PlayAudio', {
          action: 'play',
          path: psychSoundPath(value1),
          tag: 'psych-${value1}',
          volume: floatValue(value2, 1),
          loop: false,
          fadeIn: 0,
          fadeOut: 0,
          duration: 0
        }));
      default:
        output.push(new SongEventData(time, name, {value1: value1, value2: value2}));
    }
  }

  static function importScreenShake(time:Float, value:String, camera:String, output:Array<SongEventData>):Void
  {
    if (value == null || value.trim() == '') return;
    final parts = value.split(',');
    output.push(new SongEventData(time, 'CameraShake', {
      duration: parts.length > 0 ? floatValue(parts[0], 0) : 0,
      intensity: parts.length > 1 ? floatValue(parts[1], 0) : 0,
      camera: camera,
      horizontal: 1,
      vertical: 1
    }));
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
      case 'bf' | 'boyfriend' | 'player' | '1': 'boyfriend';
      case 'gf' | 'girlfriend' | '2': 'girlfriend';
      case 'dad' | 'opponent' | '0' | '': 'dad';
      default: value;
    }
  }

  static function cameraTargetAt(events:Array<SongEventData>, time:Float):Int
  {
    var result = 0;
    for (event in events)
    {
      if (event.time > time || event.eventKind != 'FocusCamera') continue;
      final target = event.getInt('char');
      if (target != null && target >= 0) result = target;
    }
    return result;
  }

  static function getSectionBeats(section:Dynamic):Float
  {
    final beats = floatValue(field(section, 'sectionBeats'), Math.NaN);
    if (!Math.isNaN(beats) && beats > 0) return beats;
    final lengthInSteps = floatValue(field(section, 'lengthInSteps'), Math.NaN);
    return !Math.isNaN(lengthInSteps) && lengthInSteps > 0 ? lengthInSteps / 4 : 4;
  }

  static function psychNoteKind(value:Dynamic):String
  {
    if (value == null || value == false || value == '') return '';
    if (value == true) return 'alt';
    return stringValue(value, '');
  }

  static function mapStage(stage:String):String
  {
    final cleanStage = stage.trim();
    return switch (cleanStage.toLowerCase())
    {
      case 'stage': 'mainStage';
      case 'spooky': 'spookyMansion';
      case 'philly': 'phillyTrain';
      case 'limo': 'limoRide';
      case 'mall': 'mallXmas';
      case 'tank': 'tankmanBattlefield';
      default: cleanStage;
    }
  }

  static function psychStage(songName:String, stage:String):String
  {
    if (stage.trim() != '') return stage;
    final songId = songName.toLowerCase().trim().replace(' ', '-');
    return switch (songId)
    {
      case 'spookeez' | 'south' | 'monster': 'spooky';
      case 'pico' | 'blammed' | 'philly' | 'philly-nice': 'philly';
      case 'milf' | 'satin-panties' | 'high': 'limo';
      case 'cocoa' | 'eggnog': 'mall';
      case 'winter-horrorland': 'mallEvil';
      case 'senpai' | 'roses': 'school';
      case 'thorns': 'schoolEvil';
      case 'ugh' | 'guns' | 'stress': 'tank';
      default: 'stage';
    }
  }

  static function psychSoundPath(value:String):String
  {
    var path = value.trim().replace('\\', '/');
    if (path == '') return 'assets/';
    if (!path.toLowerCase().endsWith('.ogg') && !path.toLowerCase().endsWith('.mp3')) path += '.${Constants.EXT_SOUND}';
    if (path.startsWith('assets/') || path.startsWith('mods/')) return path;
    return path.startsWith('sounds/') ? 'assets/${path}' : 'assets/sounds/${path}';
  }

  static function validBpm(value:Dynamic, fallback:Float):Float
  {
    final bpm = floatValue(value, fallback);
    return bpm > 0 ? bpm : fallback;
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

  static function nonEmptyString(value:Dynamic, fallback:String):String
  {
    final result = stringValue(value, fallback).trim();
    return result == '' ? fallback : result;
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
