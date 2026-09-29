package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.data.song.SongData.SongNoteDataRaw;
import funkin.modding.events.ScriptEvent;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.SustainTrail;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
using StringTools;

@:access(funkin.play.PlayState)
@:access(funkin.play.notes.NoteSprite)
@:access(funkin.play.notes.SustainTrail)
class PsychLuaNotes
{
  final host:PsychLuaHost;
  final settings:Map<SongNoteDataRaw, Map<String, Dynamic>> = [];
  final roots:Map<SongNoteDataRaw, String> = [];
  final warned:Map<String, Bool> = [];
  final splashes:Array<FlxSprite> = [];
  final atlases:Map<String, FlxAtlasFrames> = [];
  var hurtMiss:Bool = false;

  public function new(host:PsychLuaHost) { this.host = host; }

  public function data(object:Dynamic):SongNoteDataRaw
  {
    if (Std.isOfType(object, NoteSprite)) return cast cast(object, NoteSprite).noteData;
    if (Std.isOfType(object, SustainTrail)) return cast cast(object, SustainTrail).noteData;
    return Std.isOfType(object, SongNoteDataRaw) ? cast object : null;
  }

  public function supports(field:String):Bool
  {
    return switch (field)
    {
      case 'texture', 'noteSplashTexture', 'ignoreNote', 'hitCausesMiss', 'missHealth', 'hitHealth', 'antialiasing', 'noteSplashDisabled': true;
      default: false;
    };
  }

  public function read(object:Dynamic, field:String):Dynamic
  {
    var options = settings.get(data(object));
    if (options != null && options.exists(field)) return options.get(field);
    return switch (field)
    {
      case 'texture', 'noteSplashTexture': '';
      case 'missHealth': 0.1;
      case 'hitHealth': 0.023;
      case 'antialiasing': Std.isOfType(object, FlxSprite) ? cast(object, FlxSprite).antialiasing : host.game.currentChart?.noteStyle != 'pixel';
      default: false;
    };
  }

  public function write(object:Dynamic, field:String, value:Dynamic, root:String):Void
  {
    var key = data(object);
    var options = settings.get(key);
    if (options == null) { options = []; settings.set(key, options); }
    options.set(field, value);
    if (field == 'texture' || field == 'noteSplashTexture') roots.set(key, root);
    if (field != 'texture' && field != 'antialiasing') return;
    for (sprite in host.notes())
    {
      if (data(sprite) != key) continue;
      if (Std.isOfType(sprite, NoteSprite)) apply(cast sprite);
      else if (field == 'antialiasing') sprite.antialiasing = value == true;
    }
  }

  function file(key:SongNoteDataRaw, name:String, pixel:Bool):String
  {
    var root = roots.get(key);
    if (root == null || name == null || name == '' || Path.isAbsolute(name)) return null;
    root = Path.normalize(root).replace('\\', '/');
    var path = Path.normalize(root + '/images/' + (pixel ? 'pixelUI/' : '') + name + '.png');
    if (!path.replace('\\', '/').startsWith(root + '/images/')) return null;
    return FileSystem.exists(path) && !FileSystem.isDirectory(path) ? path : null;
  }

  function graphic(path:String):FlxGraphic
  {
    var result = FlxG.bitmap.get(path);
    if (result != null) return result;
    var bitmap = BitmapData.fromFile(path);
    if (bitmap == null) throw 'Could not decode note texture: $path';
    result = FlxG.bitmap.add(bitmap, false, path);
    result.destroyOnNoUse = false;
    return result;
  }

  function warn(message:String):Void
  {
    if (warned.exists(message)) return;
    warned.set(message, true);
    trace('[Psych Lua notes] ' + message);
  }

  function atlas(path:String):FlxAtlasFrames
  {
    var result = atlases.get(path);
    if (result == null)
    {
      result = FlxAtlasFrames.fromSparrow(graphic(path), File.getContent(Path.withExtension(path, 'xml')));
      atlases.set(path, result);
    }
    return result;
  }

  public function apply(note:NoteSprite):Void
  {
    var key:SongNoteDataRaw = cast note.noteData;
    var options = settings.get(key);
    if (options == null) return;
    var texture:String = options.get('texture');
    if (texture != null && texture != '')
    {
      var pixel = host.game.currentChart?.noteStyle == 'pixel';
      var path = file(key, texture, pixel);
      if (path == null && pixel) { path = file(key, texture, false); pixel = false; }
      if (path == null) warn('Missing note texture "$texture"; keeping the native note style.');
      else
      {
        var width = note.width;
        var center = note.x + width / 2;
        var source = graphic(path);
        var color = NoteSprite.DIRECTION_COLORS[cast(note.direction, Int)];
        if (pixel)
        {
          note.loadGraphic(source, true, Std.int(source.width / 4), Std.int(source.height / 5));
          note.animation.add(color + 'Scroll', [cast(note.direction, Int) + 4], 0, false);
        }
        else
        {
          var xml = Path.withExtension(path, 'xml');
          if (!FileSystem.exists(xml)) { warn('Missing note atlas: $xml'); return; }
          note.frames = atlas(path);
          note.animation.addByPrefix(color + 'Scroll', color + '0', 24, true);
        }
        note.animation.play(color + 'Scroll', true);
        note.setGraphicSize(width);
        note.updateHitbox();
        note.x = center - note.width / 2;
        note.antialiasing = !pixel;
        note.active = !pixel;
        if (pixel && note.holdNoteSprite != null) applyPixelHold(note.holdNoteSprite, key, texture, note.scale.x);
      }
    }
    if (options.exists('antialiasing'))
    {
      note.antialiasing = options.get('antialiasing') == true;
      if (note.holdNoteSprite != null) note.holdNoteSprite.antialiasing = note.antialiasing;
    }
  }

  function applyPixelHold(hold:SustainTrail, key:SongNoteDataRaw, texture:String, scale:Float):Void
  {
    var path = file(key, texture + 'ENDS', true);
    if (path == null) { warn('Missing pixel hold texture "' + texture + 'ENDS"; keeping the native hold.'); return; }
    var cacheKey = path + ':psych-trail';
    var packed = FlxG.bitmap.get(cacheKey);
    if (packed == null)
    {
      var source = graphic(path).bitmap;
      var width = Std.int(source.width / 4);
      var height = Std.int(source.height / 2);
      var bitmap = new BitmapData(width * 8, height, true, 0);
      for (direction in 0...4)
      {
        bitmap.copyPixels(source, new Rectangle(direction * width, 0, width, height), new Point(direction * width * 2, 0));
        bitmap.copyPixels(source, new Rectangle(direction * width, height, width, height), new Point((direction * 2 + 1) * width, 0));
      }
      packed = FlxG.bitmap.add(bitmap, false, cacheKey);
      packed.destroyOnNoUse = false;
    }
    var center = hold.x + hold.width / 2;
    hold.loadGraphic(packed);
    hold.isPixel = true;
    hold.antialiasing = false;
    hold.zoom = scale;
    hold.endOffset = hold.bottomClip = 1;
    hold.graphicWidth = packed.width / 8 * scale;
    hold.updateClipping();
    hold.updateHitbox();
    hold.x = center - hold.width / 2;
  }

  public function beforeEvent(event:ScriptEvent):Bool
  {
    if (event.type == NOTE_INCOMING) apply(cast(event, NoteScriptEvent).note);
    if (event.type == NOTE_MISS)
    {
      var miss:NoteScriptEvent = cast event;
      if (!hurtMiss && read(miss.note, 'ignoreNote') == true)
      {
        miss.note.handledMiss = true;
        event.cancelEvent();
        return false;
      }
      var options = settings.get(data(miss.note));
      if (options != null && options.exists('missHealth')) miss.healthChange = -Math.abs(options.get('missHealth'));
    }
    if (event.type == NOTE_HOLD_DROP)
    {
      var drop:HoldNoteScriptEvent = cast event;
      if (read(drop.holdNote, 'ignoreNote') == true)
      {
        drop.holdNote.handledMiss = true;
        event.cancelEvent();
        return false;
      }
    }
    if (event.type == NOTE_HIT)
    {
      var hit:HitNoteScriptEvent = cast event;
      var options = settings.get(data(hit.note));
      if (hit.note.noteData.getMustHitNote() && options != null && options.exists('hitHealth')) hit.healthChange = options.get('hitHealth');
      if (read(hit.note, 'noteSplashDisabled') == true) hit.doesNotesplash = false;
    }
    return true;
  }

  public function interceptHit(note:NoteSprite):Bool
  {
    if (host.game.isBotPlayMode && read(note, 'ignoreNote') == true) return true;
    if (read(note, 'hitCausesMiss') != true) return false;
    var miss = new NoteScriptEvent(NOTE_MISS, note, -Math.abs(read(note, 'missHealth')), 0, true);
    hurtMiss = true;
    try host.game.dispatchEvent(miss) catch (error:Dynamic) { hurtMiss = false; throw error; }
    hurtMiss = false;
    if (miss.eventCanceled) return true;
    host.game.onNoteMiss(note, miss.playSound, miss.healthChange);
    host.call('goodNoteHit', [host.notes().indexOf(note), cast(note.direction, Int), note.kind, false]);
    note.hasBeenHit = true;
    if (note.holdNoteSprite != null) note.holdNoteSprite.kill();
    note.kill();
    return true;
  }

  public function playSplash(note:NoteSprite):Bool
  {
    if (!host.game.playerStrumline.showNotesplash) return true;
    if (read(note, 'noteSplashDisabled') == true) return true;
    var name:String = read(note, 'noteSplashTexture');
    if (name == '') return false;
    var path = file(data(note), name, false);
    if (path == null || !FileSystem.exists(Path.withExtension(path, 'xml')))
    {
      warn('Missing splash atlas "$name"; using the native note splash.');
      return false;
    }
    var splash:FlxSprite = null;
    for (entry in splashes) if (!entry.alive) { splash = entry; break; }
    if (splash == null)
    {
      splash = new FlxSprite();
      var owned = splash;
      splash.animation.onFinish.add(_ -> owned.kill());
      splash.cameras = [host.game.camHUD];
      host.game.add(splash);
      splashes.push(splash);
    }
    splash.revive();
    splash.frames = atlas(path);
    var prefix = 'note splash ' + NoteSprite.DIRECTION_COLORS[cast(note.direction, Int)] + FlxG.random.int(1, 2);
    splash.animation.addByPrefix('splash', prefix, 24, false);
    splash.animation.play('splash', true);
    if (splash.animation.curAnim == null) { splash.kill(); return false; }
    splash.antialiasing = read(note, 'antialiasing') == true;
    var receptor = host.game.playerStrumline.strumlineNotes.members[cast(note.direction, Int)];
    splash.setPosition(receptor.x + receptor.width / 2 - splash.width / 2, receptor.y + receptor.height / 2 - splash.height / 2);
    return true;
  }

  public function clear():Void
  {
    settings.clear();
    roots.clear();
    warned.clear();
    atlases.clear();
    splashes.resize(0);
  }
}
#end
