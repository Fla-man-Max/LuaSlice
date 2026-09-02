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
class CodenameEngineImporter
{
  static final STRUMLINE_SIZE:Int = 4;

  public static function parseRaw(input:String, fileName:String = 'raw'):Dynamic
  {
    try
    {
      var cleanInput = input.trim();
      if (cleanInput.length > 0 && cleanInput.charCodeAt(0) == 0xFEFF) cleanInput = cleanInput.substr(1);
      final parsed:Dynamic = Json.parse(cleanInput);
      final wrappedSong:Dynamic = field(parsed, 'song');
      return arrayValue(field(wrappedSong, 'strumLines')).length > 0 ? wrappedSong : parsed;
    }
    catch (error)
    {
      trace('[CodenameEngineImporter] Failed to parse ${fileName}: ${error}');
      return null;
    }
  }

  public static function isChart(chart:Dynamic):Bool
  {
    return chart != null && arrayValue(field(chart, 'strumLines')).length > 0;
  }

  public static function inferDifficulty(fileName:String):String
  {
    final cleanName = fileName.toLowerCase().trim();
    return cleanName == '' ? 'normal' : cleanName;
  }

  public static function migrateMetadata(chart:Dynamic, difficulty:String = 'normal', ?externalMetadata:Dynamic, ?externalEvents:Dynamic):SongMetadata
  {
    final embeddedMetadata = field(chart, 'meta');
    final sourceMetadata = externalMetadata ?? embeddedMetadata;
    final name = nonEmptyString(field(sourceMetadata, 'displayName') ?? field(sourceMetadata, 'name'), 'Imported Song');
    final metadata = new SongMetadata(name, nonEmptyString(field(sourceMetadata, 'artist'), Constants.DEFAULT_ARTIST),
      nonEmptyString(field(sourceMetadata, 'charter'), Constants.DEFAULT_CHARTER), Constants.DEFAULT_VARIATION);

    metadata.generatedBy = 'Chart Editor Import (Codename Engine)';
    metadata.playData.difficulties = [difficulty];
    metadata.playData.songVariations = [];
    metadata.playData.stage = mapStage(nonEmptyString(field(chart, 'stage') ?? field(sourceMetadata, 'stage'), 'stage'));
    metadata.playData.characters = migrateCharacters(chart);
    metadata.timeChanges = migrateTimeChanges(chart, validBpm(field(sourceMetadata, 'bpm') ?? field(chart, 'bpm'), Constants.DEFAULT_BPM), externalEvents);
    return metadata;
  }

  public static function migrateChartData(chart:Dynamic, difficulty:String = 'normal', ?externalEvents:Dynamic):SongChartData
  {
    final notes:Array<SongNoteData> = [];
    final events:Array<SongEventData> = [];
    final noteTypes = stringArray(field(chart, 'noteTypes'));
    final strumLines = arrayValue(field(chart, 'strumLines'));
    var additionalIndex = 2;

    for (lineIndex in 0...strumLines.length)
    {
      final line = strumLines[lineIndex];
      final lineType = intValue(field(line, 'type'), lineIndex == 0 ? 0 : 1);
      final targetIndex = switch (lineType)
      {
        case 1: 0;
        case 0: 1;
        default: additionalIndex++;
      };

      for (rawNote in arrayValue(field(line, 'notes')))
      {
        final direction = positiveModulo(intValue(field(rawNote, 'id'), 0), STRUMLINE_SIZE);
        final typeIndex = intValue(field(rawNote, 'type'), 0);
        final kind = typeIndex > 0 && typeIndex <= noteTypes.length ? normalizeNoteKind(noteTypes[typeIndex - 1]) : '';
        notes.push(new SongNoteData(floatValue(field(rawNote, 'time'), 0), direction + targetIndex * STRUMLINE_SIZE,
          Math.max(0, floatValue(field(rawNote, 'sLen'), 0)), kind));
      }
    }

    importEvents(arrayValue(field(chart, 'events')), strumLines, events);
    if (externalEvents != null) importEvents(arrayValue(field(externalEvents, 'events')), strumLines, events);
    deduplicateEvents(events);
    notes.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

    final speed = Math.max(0.01, floatValue(field(chart, 'scrollSpeed'), 1));
    return new SongChartData([difficulty => speed], events, [difficulty => notes]);
  }

  static function migrateCharacters(chart:Dynamic):SongCharacterData
  {
    var player = 'bf';
    var girlfriend = 'gf';
    var opponent = 'dad';

    for (line in arrayValue(field(chart, 'strumLines')))
    {
      final characters = stringArray(field(line, 'characters'));
      if (characters.length == 0) continue;
      final character = characters[0];
      final position = stringValue(field(line, 'position'), '').toLowerCase();
      final lineType = intValue(field(line, 'type'), -1);

      if (position == 'girlfriend' || position == 'gf') girlfriend = character;
      else if (lineType == 1) player = character;
      else if (lineType == 0) opponent = character;
    }

    return new SongCharacterData(player, girlfriend, opponent);
  }

  static function migrateTimeChanges(chart:Dynamic, baseBpm:Float, ?externalEvents:Dynamic):Array<SongTimeChange>
  {
    final result = [new SongTimeChange(0, baseBpm)];
    final sources = [arrayValue(field(chart, 'events'))];
    if (externalEvents != null) sources.push(arrayValue(field(externalEvents, 'events')));

    for (source in sources)
    {
      for (event in source)
      {
        if (eventName(event) != 'bpm change') continue;
        final params = paramsValue(field(event, 'params'));
        if (params.length == 0) continue;
        final bpm = validBpm(params[0], baseBpm);
        final time = Math.max(0, floatValue(field(event, 'time'), 0));
        if (time == 0) result[0] = new SongTimeChange(0, bpm);
        else result.push(new SongTimeChange(time, bpm));
      }
    }
    result.sort((a, b) -> a.timeStamp < b.timeStamp ? -1 : (a.timeStamp > b.timeStamp ? 1 : 0));
    return result;
  }

  static function importEvents(source:Array<Dynamic>, strumLines:Array<Dynamic>, output:Array<SongEventData>):Void
  {
    for (rawEvent in source)
    {
      final name = eventName(rawEvent);
      if (name == '' || name == 'bpm change') continue;
      final time = floatValue(field(rawEvent, 'time'), 0);
      final params = paramsValue(field(rawEvent, 'params'));

      switch (name)
      {
        case 'camera movement':
          output.push(new SongEventData(time, 'FocusCamera', {char: mapCameraTarget(params.length > 0 ? intValue(params[0], 0) : 0, strumLines)}));
        case 'play animation':
          final target = params.length > 0 ? mapAnimationTarget(intValue(params[0], 0), strumLines) : 'dad';
          output.push(new SongEventData(time, 'PlayAnimation', {
            target: target,
            anim: params.length > 1 ? stringValue(params[1], '') : '',
            force: params.length > 2 ? boolValue(params[2], false) : false
          }));
        case 'change character':
          output.push(new SongEventData(time, 'ChangeCharacter', {
            char: params.length > 0 ? mapCameraTarget(intValue(params[0], 0), strumLines) : 0,
            id: params.length > 1 ? stringValue(params[1], '') : ''
          }));
        default:
          output.push(new SongEventData(time, stringValue(field(rawEvent, 'name'), name).trim(), {params: params}));
      }
    }
  }

  static function mapCameraTarget(index:Int, strumLines:Array<Dynamic>):Int
  {
    if (index < 0 || index >= strumLines.length) return 0;
    final line = strumLines[index];
    final position = stringValue(field(line, 'position'), '').toLowerCase();
    if (position == 'girlfriend' || position == 'gf') return 2;
    return intValue(field(line, 'type'), 0) == 1 ? 0 : 1;
  }

  static function mapAnimationTarget(index:Int, strumLines:Array<Dynamic>):String
  {
    return switch (mapCameraTarget(index, strumLines))
    {
      case 0: 'boyfriend';
      case 2: 'girlfriend';
      default: 'dad';
    };
  }

  static function normalizeNoteKind(kind:String):String
  {
    return switch (kind.toLowerCase().trim())
    {
      case 'default note' | '': '';
      case 'hurt note': 'hurt';
      case 'death note': 'death';
      case 'play animation note': 'play_animation';
      case 'no animation' | 'no anim' | 'no anim note': 'noanim';
      default: kind;
    };
  }

  static function deduplicateEvents(events:Array<SongEventData>):Void
  {
    final seen:Map<String, Bool> = [];
    var index = events.length - 1;
    while (index >= 0)
    {
      final event = events[index];
      final key = '${event.time}|${event.eventKind}|${Json.stringify(event.value)}';
      if (seen.exists(key)) events.splice(index, 1);
      else seen.set(key, true);
      index--;
    }
    events.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
  }

  static function mapStage(stage:String):String
  {
    return switch (stage.toLowerCase().trim())
    {
      case 'stage': 'mainStage';
      case 'spooky': 'spookyMansion';
      case 'philly': 'phillyTrain';
      case 'limo': 'limoRide';
      case 'mall': 'mallXmas';
      case 'tank': 'tankmanBattlefield';
      case 'school-evil' | 'schoolevil': 'schoolEvil';
      default: stage;
    };
  }

  static function eventName(event:Dynamic):String
  {
    final name = stringValue(field(event, 'name'), '').trim();
    if (name != '') return name.toLowerCase();

    return switch (intValue(field(event, 'type'), 0))
    {
      case -1: 'hscript call';
      case 1: 'camera movement';
      case 2: 'bpm change';
      case 3: 'alt animation toggle';
      default: '';
    };
  }

  static function positiveModulo(value:Int, divisor:Int):Int
  {
    final result = value % divisor;
    return result < 0 ? result + divisor : result;
  }

  static inline function field(value:Dynamic, name:String):Dynamic
  {
    return value == null ? null : Reflect.field(value, name);
  }

  static inline function arrayValue(value:Dynamic):Array<Dynamic>
  {
    return Std.isOfType(value, Array) ? cast value : [];
  }

  static function paramsValue(value:Dynamic):Array<Dynamic>
  {
    if (Std.isOfType(value, Array)) return cast value;
    return value == null ? [] : [value];
  }

  static function stringArray(value:Dynamic):Array<String>
  {
    return [for (entry in arrayValue(value)) stringValue(entry, '')];
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
    final result = Std.parseFloat(Std.string(value));
    return Math.isNaN(result) ? fallback : result;
  }

  static function intValue(value:Dynamic, fallback:Int):Int
  {
    final result = Std.parseInt(Std.string(value));
    return result == null ? fallback : result;
  }

  static function boolValue(value:Dynamic, fallback:Bool):Bool
  {
    if (value == null) return fallback;
    return value == true || Std.string(value).toLowerCase() == 'true';
  }

  static function validBpm(value:Dynamic, fallback:Float):Float
  {
    final bpm = floatValue(value, fallback);
    return bpm > 0 ? bpm : fallback;
  }
}
