package funkin.modding.psychlua;

#if FEATURE_PSYCH_LUA
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.FlxSave;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.addons.display.FlxRuntimeShader;
import flixel.input.keyboard.FlxKey;
import funkin.Paths;
import funkin.Conductor;
import funkin.play.stage.Bopper;
import funkin.play.notes.NoteSprite;
import funkin.play.PlayState;
import funkin.data.event.SongEventRegistry;
import funkin.data.song.SongData.SongEventData;
import funkin.modding.events.ScriptEvent.SongEventScriptEvent;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import openfl.display.BitmapData;
using StringTools;

@:access(funkin.play.PlayState)
@:access(funkin.play.character.BaseCharacter)
class PsychLuaAPI
{
  public static final names:Map<String, Bool> = [];
  final script:PsychLuaScript;
  final host:PsychLuaHost;
  final saves:Map<String, FlxSave> = [];
  final shaderSources:Map<String, Array<String>> = [];
  final assetPaths:Map<String, String> = [];
  static var nextSoundId:Int = 0;
  var hscript:PsychLuaHScript;

  public static function register(script:PsychLuaScript):Void
  {
    script.api = new PsychLuaAPI(script);
    script.api.install();
  }
  public function destroy():Void
  {
    for (save in saves) { save.flush(); save.destroy(); }
    saves.clear();
    shaderSources.clear();
    hscript?.destroy();
    hscript = null;
  }
  function new(script:PsychLuaScript) { this.script = script; host = script.host; }
  function add(name:String, callback:Dynamic):Void { names.set(name, true); script.register(name, callback); }

  function install():Void
  {
    add('debugPrint', Reflect.makeVarArgs(args -> { trace('[Psych Lua][' + script.path + '] ' + args.join(' ')); }));
    add('getProperty', (path:String, maps:Bool = false) -> get(path, null, maps));
    add('setProperty', (path:String, value:Dynamic, maps:Bool = false, instances:Bool = false) -> set(path, instances ? parseInstance(value) : value, null, maps));
    add('getPropertyFromClass', (name:String, path:String, maps:Bool = false) -> get(path, classFor(name), maps));
    add('setPropertyFromClass', (name:String, path:String, value:Dynamic, maps:Bool = false, instances:Bool = false) -> set(path, instances ? parseInstance(value) : value, classFor(name), maps));
    add('getPropertyFromGroup', (group:String, index:Int, path:Dynamic, maps:Bool = false) -> get(Std.string(path), member(group, index), maps));
    add('setPropertyFromGroup', (group:String, index:Int, path:Dynamic, value:Dynamic, maps:Bool = false, instances:Bool = false) -> set(Std.string(path), instances ? parseInstance(value) : value, member(group, index), maps));
    add('getVar', (name:String) -> host.variables.get(name));
    add('setVar', (name:String, value:Dynamic) -> { host.variables.set(name, value); return value; });
    add('callMethod', (path:String, args:Array<Dynamic> = null) -> invoke(path, args));
    add('callMethodFromClass', (name:String, path:String, args:Array<Dynamic> = null) -> invoke(path, args, classFor(name)));
    add('instanceArg', (path:String, className:String = null) -> '##PSYCHLUA_STRINGTOOBJ' + (className == null ? '' : className + '::') + path);
    add('createInstance', (tag:String, name:String, args:Array<Dynamic> = null) -> {
      if (host.objects.exists(tag)) return false;
      var obj = Type.createInstance(classFor(name), [for (arg in args ?? []) parseInstance(arg)]);
      host.own(tag, obj, script);
      return true;
    });
    add('addInstance', (tag:String, inFront:Bool = false) -> addObject(tag, inFront));
    add('makeLuaSprite', (tag:String, image:String = null, x:Float = 0, y:Float = 0) -> makeSprite(tag, image, x, y, false));
    add('makeAnimatedLuaSprite', (tag:String, image:String = null, x:Float = 0, y:Float = 0, type:String = 'sparrow') -> makeSprite(tag, image, x, y, true, type));
    add('addLuaSprite', (tag:String, front:Bool = false) -> addObject(tag, front));
    add('removeLuaSprite', (tag:String, destroy:Bool = true) -> host.removeObject(tag, destroy));
    add('luaSpriteExists', (tag:String) -> Std.isOfType(host.objects.get(tag), FlxSprite));
    add('luaTextExists', (tag:String) -> Std.isOfType(host.objects.get(tag), FlxText));
    add('luaSoundExists', (tag:String) -> host.sounds.exists(tag));
    add('loadGraphic', (tag:String, image:String, gridX:Int = 0, gridY:Int = 0) -> {
      sprite(tag).loadGraphic(imageAsset(image), gridX > 0 || gridY > 0, gridX, gridY); return true;
    });
    add('loadFrames', (tag:String, image:String, type:String = 'auto') -> { loadFrames(sprite(tag), image, type); return true; });
    add('makeGraphic', (tag:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') -> {
      if (width <= 0 || height <= 0) throw 'Graphic dimensions must be positive';
      sprite(tag).makeGraphic(width, height, parseColor(color)); return true;
    });
    add('setObjectCamera', (tag:String, camera:String = 'game') -> { sprite(tag).cameras = [host.camera(camera)]; return true; });
    add('setBlendMode', (tag:String, blend:String) -> { sprite(tag).blend = cast blend.toLowerCase(); return true; });
    add('setScrollFactor', (tag:String, x:Float, y:Float) -> { sprite(tag).scrollFactor.set(x, y); return true; });
    add('scaleObject', (tag:String, x:Float, y:Float, update:Bool = true) -> { var obj = sprite(tag); obj.scale.set(x, y); if (update) obj.updateHitbox(); });
    add('setGraphicSize', (tag:String, width:Int, height:Int = 0, update:Bool = true) -> { var obj = sprite(tag); obj.setGraphicSize(width, height); if (update) obj.updateHitbox(); });
    add('updateHitbox', (tag:String) -> sprite(tag).updateHitbox());
    add('updateHitboxFromGroup', (group:String, index:Int) -> cast(member(group, index), FlxSprite).updateHitbox());
    add('screenCenter', (tag:String, axes:String = 'xy') -> sprite(tag).screenCenter(axes.toLowerCase() == 'x' ? X : axes.toLowerCase() == 'y' ? Y : XY));
    add('objectsOverlap', (one:String, two:String) -> sprite(one).overlaps(sprite(two)));
    add('getPixelColor', (tag:String, x:Int, y:Int) -> sprite(tag).pixels.getPixel32(x, y));
    add('addAnimationByPrefix', (tag:String, name:String, prefix:String, fps:Float = 24, loop:Bool = true) -> {
      var object = sprite(tag);
      var existing = object.animation.getByName(prefix);
      if (existing != null) object.animation.add(name, existing.frames.copy(), fps, loop);
      else object.animation.addByPrefix(name, prefix, fps, loop);
    });
    add('addAnimation', (tag:String, name:String, frames:Array<Int>, fps:Float = 24, loop:Bool = true) -> sprite(tag).animation.add(name, frames, fps, loop));
    add('addAnimationByIndices', (tag:String, name:String, prefix:String, indices:String, fps:Float = 24, loop:Bool = false) -> addIndices(tag, name, prefix, indices, fps, loop));
    add('addAnimationByIndicesLoop', (tag:String, name:String, prefix:String, indices:String, fps:Float = 24) -> addIndices(tag, name, prefix, indices, fps, true));
    add('addOffset', (tag:String, name:String, x:Float = 0, y:Float = 0) -> {
      var obj = sprite(tag);
      if (!Std.isOfType(obj, PsychLuaSprite)) throw 'addOffset requires a Lua-created sprite; native character offsets belong to its animation data';
      cast(obj, PsychLuaSprite).addOffset(name, x, y);
    });
    add('playAnim', (tag:String, name:String, forced:Bool = false, reverse:Bool = false, frame:Int = 0) -> playAnim(tag, name, forced, reverse, frame));
    add('getObjectOrder', (tag:String, group:String = null) -> group == null ? host.game.members.indexOf(cast get(tag)) : groupMembers(get(group)).indexOf(get(tag)));
    add('setObjectOrder', (tag:String, index:Int, group:String = null) -> {
      var target:Dynamic = group == null ? host.game : get(group);
      var obj = get(tag);
      if (obj == null) throw 'Unknown object: $tag';
      target.remove(obj, true);
      target.insert(Std.int(Math.max(0, Math.min(index, target.members.length))), obj);
    });
    for (field in ['X', 'Y', 'Angle', 'Alpha', 'Zoom'])
    {
      final property = field.toLowerCase();
      add('doTween' + field, (tag:String, target:String, value:Float, duration:Float, ease:String = 'linear') -> {
        var values:Dynamic = {}; Reflect.setField(values, property, value); tween(tag, target, values, duration, {ease: ease});
      });
    }
    for (field in ['X', 'Y', 'Angle', 'Alpha'])
    {
      final property = field.toLowerCase();
      add('noteTween' + field, (tag:String, index:Int, value:Float, duration:Float, ease:String = 'linear') -> {
        var receptors = host.receptors();
        if (index < 0 || index >= receptors.length) throw 'Invalid strumline index: $index';
        var values:Dynamic = {}; Reflect.setField(values, property, value); tweenObject(tag, receptors[index], values, duration, {ease: ease}, 'strumLineNotes.members.' + index);
      });
    }
    add('startTween', (tag:String, target:String, values:Dynamic, duration:Float, options:Dynamic = null) -> tween(tag, target, values, duration, options));
    add('cancelTween', (tag:String) -> { host.tweens.get(tag)?.cancel(); host.tweens.remove(tag); host.tweenOwners.remove(tag); });
    add('doTweenColor', (tag:String, target:String, color:String, duration:Float, ease:String = 'linear') -> {
      host.tweens.get(tag)?.cancel();
      var obj = sprite(target);
      host.tweenOwners.set(tag, script);
      host.tweens.set(tag, FlxTween.color(obj, duration, obj.color, parseColor(color), {ease: easeFor(ease), onComplete: tween -> finishTween(tag, target)}));
    });
    add('runTimer', (tag:String, time:Float = 1, loops:Int = 1) -> {
      host.timers.get(tag)?.cancel();
      if (time <= 0) throw 'Timer interval must be positive';
      var timer = new FlxTimer();
      host.timers.set(tag, timer); host.timerOwners.set(tag, script);
      timer.start(time, timer -> {
        if (timer.finished) { host.timers.remove(tag); host.timerOwners.remove(tag); }
        host.call('onTimerCompleted', [tag, timer.loops, timer.loopsLeft]);
      }, loops);
    });
    add('cancelTimer', (tag:String) -> { host.timers.get(tag)?.cancel(); host.timers.remove(tag); host.timerOwners.remove(tag); });
    installText();
    installAudio();
    installInput();
    installFiles();
    installShaders();
    installScripts();
    add('getHealth', () -> host.game.health);
    add('openCustomSubstate', (name:String, pauseGame:Bool = false) -> {
      if (host.game.subState != null) return false;
      var substate = new PsychLuaSubState(host, name, pauseGame);
      host.game.shouldSubstatePause = pauseGame;
      host.game.openSubState(substate);
      return true;
    });
    add('closeCustomSubstate', () -> {
      if (!Std.isOfType(host.game.subState, PsychLuaSubState)) return false;
      host.game.closeSubState();
      return true;
    });
    add('addToCustomSubstate', (tag:String, position:Int = -1) -> {
      var substate = host.game.subState;
      if (!Std.isOfType(substate, PsychLuaSubState)) return false;
      var object = get(tag);
      if (!Std.isOfType(object, FlxBasic)) throw 'Object is not a Flixel object: $tag';
      host.game.remove(cast object, true);
      var previous = host.containers.get(tag);
      if (previous != null) previous.remove(cast object, true);
      if (position < 0) substate.add(cast object);
      else substate.insert(position, cast object);
      host.containers.set(tag, substate);
      return true;
    });
    add('addMisses', (value:Int = 0) -> funkin.Highscore.tallies.missed += value);
    add('setMisses', (value:Int = 0) -> funkin.Highscore.tallies.missed = value);
    add('addHits', (value:Int = 0) -> funkin.Highscore.tallies.totalNotesHit += value);
    add('setHits', (value:Int = 0) -> funkin.Highscore.tallies.totalNotesHit = value);
    add('setHealth', (value:Float) -> host.game.health = value);
    add('addHealth', (value:Float) -> host.game.health += value);
    add('setScore', (value:Int = 0) -> host.game.songScore = value);
    add('addScore', (value:Int = 0) -> host.game.songScore += value);
    add('getSongPosition', () -> Conductor.instance.songPosition);
    add('startCountdown', () -> { host.game.startCountdown(); return true; });
    add('endSong', () -> { host.game.endSong(); return true; });
    add('restartSong', (skipTransition:Bool = false) -> { host.game.needsReset = true; return true; });
    add('addCharacterToList', (id:String, character:String) -> host.precacheCharacter(id, characterName(character)));
    add('getCharacterX', (character:String) -> sprite(characterName(character)).x);
    add('getCharacterY', (character:String) -> sprite(characterName(character)).y);
    add('setCharacterX', (character:String, x:Float) -> sprite(characterName(character)).x = x);
    add('setCharacterY', (character:String, y:Float) -> sprite(characterName(character)).y = y);
    add('characterDance', (character:String) -> invoke(characterName(character) + '.dance', []));
    add('characterPlayAnim', (character:String, name:String, forced:Bool = false) -> playAnim(characterName(character), name, forced, false, 0));
    add('cameraShake', (camera:String, intensity:Float, duration:Float) -> host.camera(camera).shake(intensity, duration));
    add('cameraFlash', (camera:String, color:String, duration:Float, forced:Bool = false) -> host.camera(camera).flash(parseColor(color), duration, null, forced));
    add('cameraFade', (camera:String, color:String, duration:Float, forced:Bool = false, fadeOut:Bool = true) -> host.camera(camera).fade(parseColor(color), duration, !fadeOut, null, forced));
    add('setCameraFollowPoint', (x:Float, y:Float) -> host.game.cameraFollowPoint.setPosition(x, y));
    add('addCameraFollowPoint', (x:Float, y:Float) -> host.game.cameraFollowPoint.setPosition(host.game.cameraFollowPoint.x + x, host.game.cameraFollowPoint.y + y));
    add('getCameraFollowX', () -> host.game.cameraFollowPoint.x);
    add('getCameraFollowY', () -> host.game.cameraFollowPoint.y);
    add('setCameraScroll', (x:Float, y:Float) -> host.game.camGame.scroll.set(x, y));
    add('addCameraScroll', (x:Float, y:Float) -> host.game.camGame.scroll.add(x, y));
    add('getCameraScrollX', () -> host.game.camGame.scroll.x);
    add('getCameraScrollY', () -> host.game.camGame.scroll.y);
    add('cameraSetTarget', (character:String) -> {
      var obj = host.rootObject(characterName(character));
      if (obj == null) return false;
      var point:Dynamic = Reflect.getProperty(obj, 'cameraFocusPoint');
      if (point != null) host.game.cameraFollowPoint.setPosition(point.x, point.y);
      host.cameraTarget = characterName(character);
      return characterName(character) == 'dad';
    });
    add('triggerEvent', (name:String, one:Dynamic = '', two:Dynamic = '') -> {
      var data = new SongEventData(Conductor.instance.songPosition, name, {value1: one, value2: two});
      var event = new SongEventScriptEvent(data);
      host.game.dispatchEvent(event);
      if (!event.eventCanceled && name == 'Change Character') return host.changeCharacter(Std.string(two), characterName(Std.string(one)));
      if (!event.eventCanceled) SongEventRegistry.handleEvent(data);
      return !event.eventCanceled;
    });
    add('triggerVSliceEvent', (name:String, values:Dynamic) -> {
      var data = new SongEventData(Conductor.instance.songPosition, name, values);
      var event = new SongEventScriptEvent(data);
      host.game.dispatchEvent(event);
      if (!event.eventCanceled) SongEventRegistry.handleEvent(data);
      return !event.eventCanceled;
    });
    add('getColorFromHex', parseColor);
    add('getColorFromString', parseColor);
    add('getColorFromName', parseColor);
    add('getRandomInt', (min:Int = 0, max:Int = 2147483647, exclude:String = '') -> FlxG.random.int(min, max, [for (part in exclude.split(',')) if (Std.parseInt(part) != null) Std.parseInt(part)]));
    add('getRandomFloat', (min:Float = 0, max:Float = 1, exclude:String = '') -> FlxG.random.float(min, max, [for (part in exclude.split(',')) if (!Math.isNaN(Std.parseFloat(part))) Std.parseFloat(part)]));
    add('getRandomBool', (chance:Float = 50) -> FlxG.random.bool(chance));
    add('stringStartsWith', (str:String, start:String) -> str.startsWith(start));
    add('stringEndsWith', (str:String, end:String) -> str.endsWith(end));
    add('stringSplit', (str:String, separator:String) -> str.split(separator));
    add('stringTrim', (str:String) -> str.trim());
    for (axis in ['X', 'Y'])
    {
      final x = axis == 'X';
      add('getMidpoint' + axis, (tag:String) -> pointComponent(sprite(tag).getMidpoint(), x));
      add('getGraphicMidpoint' + axis, (tag:String) -> pointComponent(sprite(tag).getGraphicMidpoint(), x));
      add('getScreenPosition' + axis, (tag:String, camera:String = 'game') -> pointComponent(sprite(tag).getScreenPosition(null, host.camera(camera)), x));
    }
    for (alias => target in [
      'objectPlayAnimation' => 'playAnim', 'luaSpritePlayAnimation' => 'playAnim',
      'luaSpriteMakeGraphic' => 'makeGraphic', 'setLuaSpriteCamera' => 'setObjectCamera',
      'setLuaSpriteScrollFactor' => 'setScrollFactor', 'scaleLuaSprite' => 'scaleObject',
      'luaSpriteAddAnimationByPrefix' => 'addAnimationByPrefix', 'luaSpriteAddAnimationByIndices' => 'addAnimationByIndices'])
    {
      script.execute(alias + ' = ' + target, 'compatibility-alias'); names.set(alias, true);
    }
    add('getPropertyLuaSprite', (tag:String, property:String) -> get(tag + '.' + property));
    add('setPropertyLuaSprite', (tag:String, property:String, value:Dynamic) -> set(tag + '.' + property, value));
  }

  function installText():Void
  {
    add('makeLuaText', (tag:String, text:String = '', width:Float = 0, x:Float = 0, y:Float = 0) -> {
      var obj = new FlxText(x, y, width, text, 16); obj.font = Paths.font('vcr.ttf'); obj.cameras = [host.game.camHUD]; host.own(tag, obj, script);
    });
    add('addLuaText', (tag:String) -> addObject(tag, true));
    add('removeLuaText', (tag:String, destroy:Bool = true) -> host.removeObject(tag, destroy));
    for (name => field in ['String' => 'text', 'Size' => 'size', 'Width' => 'fieldWidth', 'Height' => 'fieldHeight', 'Italic' => 'italic', 'AutoSize' => 'autoSize'])
    {
      final property = field;
      add('setText' + name, (tag:String, value:Dynamic) -> { Reflect.setProperty(text(tag), property, value); return true; });
      if (['String', 'Size', 'Width'].contains(name)) add('getText' + name, (tag:String) -> Reflect.getProperty(text(tag), property));
    }
    add('getTextFont', (tag:String) -> text(tag).font);
    add('setTextFont', (tag:String, font:String) -> { var local = localPath('fonts/' + font); text(tag).font = FileSystem.exists(local) ? local : Paths.font(font); return true; });
    add('setTextColor', (tag:String, color:String) -> { text(tag).color = parseColor(color); return true; });
    add('setTextAlignment', (tag:String, alignment:String = 'left') -> { text(tag).alignment = cast alignment.toLowerCase(); return true; });
    add('setTextBorder', (tag:String, size:Float, color:String, style:String = 'outline') -> {
      var obj = text(tag); obj.borderSize = size; obj.borderColor = parseColor(color);
      obj.borderStyle = size <= 0 ? NONE : switch (style.toLowerCase()) { case 'shadow': SHADOW; case 'outline_fast': OUTLINE_FAST; default: OUTLINE; };
      return true;
    });
  }

  function installAudio():Void
  {
    add('playSound', (name:String, volume:Float = 1, tag:String = null) -> {
      var key = tag == null || tag == '' ? '__sound_' + script.id + '_' + (++nextSoundId) : tag;
      var old = host.sounds.get(key); if (old != null) { FlxG.sound.list.remove(old, true); old.destroy(); }
      var sound = new FlxSound().loadEmbedded(soundAsset(name, false));
      sound.volume = volume; host.sounds.set(key, sound); host.soundOwners.set(key, script); FlxG.sound.list.add(sound);
      sound.onComplete = () -> {
        if (host.sounds.get(key) == sound) { host.sounds.remove(key); host.soundOwners.remove(key); }
        FlxG.sound.list.remove(sound, true);
        sound.destroy();
        if (tag != null && tag != '') host.call('onSoundFinished', [tag]);
      };
      sound.play();
    });
    add('playMusic', (name:String, volume:Float = 1, loop:Bool = false) -> FlxG.sound.playMusic(soundAsset(name, true), volume, loop));
    add('stopSound', (tag:String) -> sound(tag).stop());
    add('pauseSound', (tag:String) -> sound(tag).pause());
    add('resumeSound', (tag:String) -> sound(tag).resume());
    for (name in ['Volume', 'Time', 'Pitch'])
    {
      final property = name.toLowerCase();
      add('getSound' + name, (tag:String = null) -> Reflect.getProperty(sound(tag), property));
      add('setSound' + name, (tag:String, value:Float) -> Reflect.setProperty(sound(tag), property, value));
    }
    add('soundFadeIn', (tag:String, duration:Float, from:Float = 0, to:Float = 1) -> sound(tag).fadeIn(duration, from, to));
    add('soundFadeOut', (tag:String, duration:Float, to:Float = 0) -> sound(tag).fadeOut(duration, to));
    add('soundFadeCancel', (tag:String) -> sound(tag).fadeTween?.cancel());
    add('musicFadeIn', (duration:Float, from:Float = 0, to:Float = 1) -> sound(null).fadeIn(duration, from, to));
    add('musicFadeOut', (duration:Float, to:Float = 0) -> sound(null).fadeOut(duration, to));
    add('precacheImage', (name:String) -> { FlxG.bitmap.add(imageAsset(name)); });
    add('precacheSound', (name:String) -> { FlxG.sound.cache(soundAsset(name, false)); });
    add('precacheMusic', (name:String) -> { FlxG.sound.cache(soundAsset(name, true)); });
  }

  function installInput():Void
  {
    for (kind in ['Pressed', 'JustPressed', 'Released'])
    {
      final field = kind == 'Pressed' ? 'pressed' : kind == 'JustPressed' ? 'justPressed' : 'justReleased';
      add('gamepad' + kind, (id:Int, button:String) -> {
        var pad = FlxG.gamepads.getByID(id);
        return pad != null && Reflect.getProperty(Reflect.getProperty(pad, field), button.toUpperCase()) == true;
      });
    }
    add('anyGamepadPressed', (button:String) -> FlxG.gamepads.anyPressed(button));
    add('anyGamepadJustPressed', (button:String) -> FlxG.gamepads.anyJustPressed(button));
    add('anyGamepadReleased', (button:String) -> FlxG.gamepads.anyJustReleased(button));
    add('gamepadAnalogX', (id:Int, leftStick:Bool = true) -> {
      var pad = FlxG.gamepads.getByID(id);
      return pad == null ? 0.0 : pad.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
    });
    add('gamepadAnalogY', (id:Int, leftStick:Bool = true) -> {
      var pad = FlxG.gamepads.getByID(id);
      return pad == null ? 0.0 : pad.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
    });
    for (kind in ['Pressed', 'JustPressed', 'Released'])
    {
      final state:flixel.input.FlxInput.FlxInputState = kind == 'Pressed' ? PRESSED : kind == 'JustPressed' ? JUST_PRESSED : JUST_RELEASED;
      add('keyboard' + kind, (key:String) -> FlxG.keys.checkStatus(FlxKey.fromString(key.toUpperCase()), state));
      add('key' + kind, (key:String) -> {
        var name = key.toUpperCase();
        var suffix = state == JUST_PRESSED ? '_P' : state == JUST_RELEASED ? '_R' : '';
        if (['LEFT', 'DOWN', 'UP', 'RIGHT'].contains(name)) name = 'NOTE_' + name;
        return Reflect.getProperty(host.game.controls, name + suffix) == true;
      });
    }
    add('mousePressed', (button:String = 'left') -> mouse(button, 'pressed'));
    add('mouseClicked', (button:String = 'left') -> mouse(button, 'justPressed'));
    add('mouseReleased', (button:String = 'left') -> mouse(button, 'justReleased'));
    add('getMouseX', (camera:String = 'game') -> pointComponent(FlxG.mouse.getWorldPosition(host.camera(camera)), true));
    add('getMouseY', (camera:String = 'game') -> pointComponent(FlxG.mouse.getWorldPosition(host.camera(camera)), false));
  }

  function installFiles():Void
  {
    add('checkFileExists', (name:String, absolute:Bool = false) -> FileSystem.exists(localPath(name)));
    add('getTextFromFile', (name:String, ignoreMods:Bool = false) -> ignoreMods ? funkin.Assets.getText(Paths.file(name)) : File.getContent(localPath(name)));
    add('saveFile', (name:String, content:String, absolute:Bool = false) -> { var path = localPath(name); FileSystem.createDirectory(Path.directory(path)); File.saveContent(path, content); return true; });
    add('deleteFile', (name:String, ignoreMods:Bool = false) -> { var path = localPath(name); if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return false; FileSystem.deleteFile(path); return true; });
    add('directoryFileList', (name:String) -> FileSystem.readDirectory(localPath(name)));
    add('initSaveData', (name:String, folder:String = 'psychenginemods') -> {
      if (saves.exists(name)) return;
      var save = new FlxSave();
      var namespace = haxe.crypto.Sha256.encode(script.root).substr(0, 16);
      if (!save.bind(name.replace('/', '_').replace('\\', '_'), 'psychlua/' + namespace + '/' + folder.replace('/', '_').replace('\\', '_'))) throw 'Could not open save $name';
      saves.set(name, save);
    });
    add('getDataFromSave', (name:String, field:String, fallback:Dynamic = null) -> { var value = Reflect.getProperty(save(name).data, field); return value == null ? fallback : value; });
    add('setDataFromSave', (name:String, field:String, value:Dynamic) -> { Reflect.setProperty(save(name).data, field, value); return save(name).flush(); });
    add('flushSaveData', (name:String) -> save(name).flush());
    add('eraseSaveData', (name:String) -> save(name).erase());
  }

  function installShaders():Void
  {
    add('initLuaShader', initShader);
    add('setSpriteShader', (tag:String, name:String) -> {
      if (!shaderSources.exists(name) && !initShader(name)) return false;
      var sources = shaderSources.get(name); sprite(tag).shader = new FlxRuntimeShader(sources[0], sources[1]); return true;
    });
    add('removeSpriteShader', (tag:String) -> { sprite(tag).shader = null; return true; });
    for (kind in ['Float', 'Int', 'Bool', 'FloatArray', 'IntArray', 'BoolArray'])
    {
      final type = kind;
      add('setShader' + type, (tag:String, property:String, value:Dynamic) -> {
        var shader = runtimeShader(tag); var method = Reflect.field(shader, 'set' + type);
        Reflect.callMethod(shader, method, [property, value]); return true;
      });
      add('getShader' + type, (tag:String, property:String) -> {
        var shader = runtimeShader(tag); return Reflect.callMethod(shader, Reflect.field(shader, 'get' + type), [property]);
      });
    }
    add('setShaderSampler2D', (tag:String, property:String, image:String) -> runtimeShader(tag).setBitmapData(property, FlxG.bitmap.add(imageAsset(image)).bitmap));
  }

  function installScripts():Void
  {
    add('runHaxeCode', (code:String, variables:Dynamic = null, func:String = null, args:Array<Dynamic> = null) -> {
      if (hscript == null) hscript = new PsychLuaHScript(script);
      var result = hscript.run(code, variables);
      if (func != null && func != '') return hscript.call(func, args ?? [])?.returnValue;
      return result;
    });
    add('runHaxeFunction', (name:String, args:Array<Dynamic> = null) -> {
      if (hscript == null) throw 'Call runHaxeCode first';
      return hscript.call(name, args ?? [])?.returnValue;
    });
    add('addHaxeLibrary', (name:String, packageName:String = '') -> {
      if (hscript == null) hscript = new PsychLuaHScript(script);
      var path = packageName == '' ? name : packageName + '.' + name;
      var value:Dynamic = Type.resolveClass(path);
      if (value == null) value = Type.resolveEnum(path);
      if (value == null) throw 'Haxe type is not present in this build: $path';
      hscript.set(name, value);
    });
    add('getGlobalFromScript', (name:String, field:String) -> {
      var target = findScript(name);
      if (target == null) throw 'Script is not loaded: $name';
      return target.get(field);
    });
    add('setGlobalFromScript', (name:String, field:String, value:Dynamic) -> {
      var target = findScript(name);
      if (target == null) throw 'Script is not loaded: $name';
      target.set(field, value);
    });
    add('close', () -> { script.closed = true; return true; });
    add('getRunningScripts', () -> [for (entry in host.scripts) if (!entry.closed) entry.path]);
    add('isRunning', (name:String) -> findScript(name) != null);
    add('addLuaScript', (name:String, allowDuplicate:Bool = false) -> { var path = scriptPath(name); return host.load(path, script.root); });
    add('removeLuaScript', (name:String) -> { var entry = findScript(name); if (entry == null) return false; entry.closed = true; return true; });
    add('callScript', (name:String, hook:String, args:Array<Dynamic> = null) -> { var entry = findScript(name); if (entry == null) throw 'Script is not loaded: $name'; return entry.call(hook, args ?? []); });
    for (name in ['callOnLuas', 'callOnScripts']) add(name, (hook:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, ignoreSelf:Bool = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null) -> {
      var result:Dynamic = PsychLuaScript.CONTINUE;
      for (entry in host.scripts.copy())
      {
        if (entry.closed || (ignoreSelf && entry == script) || (exclusions != null && exclusions.contains(entry.path))) continue;
        var value = entry.call(hook, args ?? []);
        if (excludeValues != null && excludeValues.contains(value)) continue;
        if (value != PsychLuaScript.CONTINUE) result = value;
        if (!ignoreStops && (value == PsychLuaScript.STOP_LUA || value == PsychLuaScript.STOP_ALL)) break;
      }
      return result;
    });
    for (name in ['setOnLuas', 'setOnScripts']) add(name, (field:String, value:Dynamic, ignoreSelf:Bool = false, exclusions:Array<String> = null) -> {
      for (entry in host.scripts) if ((!ignoreSelf || entry != script) && (exclusions == null || !exclusions.contains(entry.path))) entry.set(field, value);
    });
    add('reloadLuaScripts', () -> { host.reloadRequested = true; return true; });
    add('setLuaAutoReload', (enabled:Bool) -> host.autoReload = enabled);
    add('isLuaFunctionSupported', (name:String) -> names.exists(name));
  }

  function localPath(relative:String):String
  {
    if (relative == null || Path.isAbsolute(relative)) throw 'Expected a path relative to this mod';
    var root = Path.normalize(script.root).replace('\\', '/');
    var path = Path.normalize(root + '/' + relative).replace('\\', '/');
    if (path != root && !path.startsWith(root + '/')) throw 'Path is outside this mod: $relative';
    return path;
  }

  function scriptPath(name:String):String
  {
    if (!name.toLowerCase().endsWith('.luap') && !name.toLowerCase().endsWith('.luapg')) name += '.luap';
    return localPath(name);
  }

  function findScript(name:String):PsychLuaScript
  {
    var path = Path.isAbsolute(name) ? Path.normalize(name).replace('\\', '/') : scriptPath(name);
    for (entry in host.scripts) if (!entry.closed && entry.path == path) return entry;
    return null;
  }

  function assetPath(relative:String):String
  {
    if (assetPaths.exists(relative)) return assetPaths.get(relative);
    var exact = localPath(relative);
    if (FileSystem.exists(exact)) { assetPaths.set(relative, exact); return exact; }
    var current = Path.normalize(script.root).replace('\\', '/');
    for (part in relative.replace('\\', '/').split('/'))
    {
      if (!FileSystem.exists(current) || !FileSystem.isDirectory(current)) return exact;
      var next = current + '/' + part;
      if (!FileSystem.exists(next))
      {
        var matches = [for (entry in FileSystem.readDirectory(current)) if (entry.toLowerCase() == part.toLowerCase()) entry];
        if (matches.length != 1) return exact;
        next = current + '/' + matches[0];
      }
      current = next;
    }
    assetPaths.set(relative, current);
    return current;
  }

  function imageAsset(name:String):Dynamic
  {
    var local = assetPath('images/' + name + '.png');
    if (!FileSystem.exists(local)) return Paths.image(name);
    var graphic = FlxG.bitmap.get(local);
    if (graphic != null) return graphic;
    var bitmap = BitmapData.fromFile(local);
    if (bitmap == null) throw 'Could not decode image: $local';
    return FlxG.bitmap.add(bitmap, false, local);
  }

  function soundAsset(name:String, music:Bool):flixel.system.FlxAssets.FlxSoundAsset
  {
    var local = assetPath((music ? 'music/' : 'sounds/') + name + '.ogg');
    return FileSystem.exists(local) ? openfl.media.Sound.fromFile(local) : music ? Paths.music(name) : Paths.sound(name);
  }

  function loadFrames(obj:FlxSprite, image:String, type:String):Void
  {
    var xml = assetPath('images/' + image + '.xml');
    var txt = assetPath('images/' + image + '.txt');
    if (type == 'packer' || (type == 'auto' && FileSystem.exists(txt))) obj.frames = FlxAtlasFrames.fromSpriteSheetPacker(imageAsset(image), File.getContent(txt));
    else obj.frames = FileSystem.exists(xml) ? FlxAtlasFrames.fromSparrow(imageAsset(image), File.getContent(xml)) : Paths.getSparrowAtlas(image);
  }

  function makeSprite(tag:String, image:String, x:Float, y:Float, animated:Bool, type:String = 'sparrow'):Void
  {
    var obj = new PsychLuaSprite(x, y);
    host.own(tag, obj, script);
    if (animated && host.game.currentStage != null)
    {
      for (character in [host.game.currentStage.getBoyfriend(), host.game.currentStage.getDad(), host.game.currentStage.getGirlfriend()])
      {
        if (Std.isOfType(character, funkin.play.character.SparrowCharacter) && character._data.assetPath == image)
        {
          obj.frames = character.frames;
          obj.animation.copyFrom(character.animation);
          obj.antialiasing = character.antialiasing;
          return;
        }
      }
    }
    if (image != null && image != '') { if (animated) loadFrames(obj, image, type); else obj.loadGraphic(imageAsset(image)); }
  }

  function addObject(tag:String, front:Bool):Bool
  {
    var obj = get(tag);
    if (!Std.isOfType(obj, FlxBasic)) throw 'Object is not a Flixel object: $tag';
    if (host.game.members.contains(obj)) return false;
    var previous = host.containers.get(tag);
    if (previous != null) previous.remove(cast obj, true);
    host.containers.remove(tag);
    cast(obj, FlxBasic).zIndex = front ? 2000 : (host.game.currentStage?.zIndex ?? 0) - 1;
    if (front) host.game.add(cast obj);
    else host.game.insert(Std.int(Math.max(0, host.game.members.indexOf(host.game.currentStage))), cast obj);
    return true;
  }

  function sprite(tag:String):FlxSprite
  {
    var obj = get(tag); if (!Std.isOfType(obj, FlxSprite)) throw 'Sprite not found: $tag'; return cast obj;
  }

  function text(tag:String):FlxText
  {
    var obj = get(tag); if (!Std.isOfType(obj, FlxText)) throw 'Text not found: $tag'; return cast obj;
  }

  function sound(tag:String):FlxSound
  {
    var obj = tag == null || tag == '' ? FlxG.sound.music : host.sounds.get(tag);
    if (obj == null) throw 'Sound not found: $tag'; return obj;
  }

  function save(name:String):FlxSave
  {
    var result = saves.get(name); if (result == null) throw 'Call initSaveData first: $name'; return result;
  }

  function runtimeShader(tag:String):FlxRuntimeShader
  {
    var shader = sprite(tag).shader; if (!Std.isOfType(shader, FlxRuntimeShader)) throw 'No runtime shader on $tag'; return cast shader;
  }

  function initShader(name:String):Bool
  {
    var frag = localPath('shaders/' + name + '.frag'); var vert = localPath('shaders/' + name + '.vert');
    if (!FileSystem.exists(frag) && !FileSystem.exists(vert)) return false;
    shaderSources.set(name, [FileSystem.exists(frag) ? File.getContent(frag) : null, FileSystem.exists(vert) ? File.getContent(vert) : null]);
    return true;
  }

  function playAnim(tag:String, name:String, forced:Bool, reverse:Bool, frame:Int):Bool
  {
    var obj = sprite(tag);
    if (Std.isOfType(obj, PsychLuaSprite)) cast(obj, PsychLuaSprite).playAnim(name, forced, reverse, frame);
    else if (Std.isOfType(obj, Bopper)) cast(obj, Bopper).playAnimation(name, forced, false, reverse);
    else obj.animation.play(name, forced, reverse, frame);
    return true;
  }

  function addIndices(tag:String, name:String, prefix:String, indices:String, fps:Float, loop:Bool):Void
  {
    var frames:Array<Int> = [];
    for (part in indices.split(',')) { var value = Std.parseInt(part.trim()); if (value == null) throw 'Invalid animation index: $part'; frames.push(value); }
    sprite(tag).animation.addByIndices(name, prefix, frames, '', fps, loop);
  }

  function tween(tag:String, target:String, values:Dynamic, duration:Float, options:Dynamic):Void
  { tweenObject(tag, get(target), values, duration, options, target); }

  function tweenObject(tag:String, object:Dynamic, values:Dynamic, duration:Float, options:Dynamic, target:String):Void
  {
    if (object == null) throw 'Tween target not found: $target';
    if (values == null || duration < 0) throw 'Invalid tween parameters';
    host.tweens.get(tag)?.cancel(); host.tweenOwners.set(tag, script);
    var kind:flixel.tweens.FlxTween.FlxTweenType = switch (Std.string(options?.type).toLowerCase())
    { case 'looping': LOOPING; case 'pingpong': PINGPONG; case 'backward': BACKWARD; case 'persist': PERSIST; default: ONESHOT; };
    host.tweens.set(tag, FlxTween.tween(object, values, duration, {
      type: kind, ease: easeFor(options?.ease ?? 'linear'), startDelay: options?.startDelay ?? 0, loopDelay: options?.loopDelay ?? 0,
      onStart: tween -> { if (options?.onStart != null) script.call(options.onStart, [tag, target]); },
      onUpdate: tween -> { if (options?.onUpdate != null) script.call(options.onUpdate, [tag, target]); },
      onComplete: tween -> {
        if (kind != LOOPING && kind != PINGPONG) { host.tweens.remove(tag); host.tweenOwners.remove(tag); }
        if (options?.onComplete != null) script.call(options.onComplete, [tag, target]);
        else host.call('onTweenCompleted', [tag, target]);
      }
    }));
  }

  function finishTween(tag:String, target:String):Void
  { host.tweens.remove(tag); host.tweenOwners.remove(tag); host.call('onTweenCompleted', [tag, target]); }

  static function easeFor(name:String):Float->Float
  {
    var method:Dynamic = Reflect.field(FlxEase, name);
    if (method == null) throw 'Unknown easing: $name'; return cast method;
  }

  static function parseColor(value:String):FlxColor
  {
    var color = FlxColor.fromString(value.startsWith('#') || value.startsWith('0x') ? value : '#' + value);
    if (color == null) color = FlxColor.fromString(value);
    if (color == null) throw 'Invalid color: $value'; return color;
  }

  static function characterName(name:String):String
  { return switch (name.toLowerCase()) { case 'bf', 'boyfriend', '0': 'boyfriend'; case 'gf', 'girlfriend', '2': 'gf'; default: 'dad'; }; }

  static function pointComponent(point:FlxPoint, x:Bool):Float
  { var value = x ? point.x : point.y; point.put(); return value; }

  function mouse(button:String, property:String):Bool
  { return Reflect.getProperty(FlxG.mouse, property + (button == 'right' ? 'Right' : button == 'middle' ? 'Middle' : '')) == true; }

  function tokens(path:String):Array<String>
  {
    var parts = path.replace('[', '.').replace(']', '').split('.');
    return [for (part in parts) if (part != '') part.replace('"', '').replace("'", '')];
  }

  function read(object:Dynamic, field:String, maps:Bool):Dynamic
  {
    if (object == null) throw 'Cannot read $field from a missing object';
    if (Std.isOfType(object, funkin.play.character.BaseCharacter))
    {
      var character:funkin.play.character.BaseCharacter = cast object;
      switch (field)
      {
        case 'imageFile': return character._data.assetPath;
        case 'curCharacter': return character.characterId;
        case 'healthColorArray': return host.healthColor(character);
        default:
      }
    }
    if (host.noteOptions.supports(field) && host.noteOptions.data(object) != null) return host.noteOptions.read(object, field);
    if (Std.isOfType(object, Array))
    {
      if (field == 'length') return cast(object, Array<Dynamic>).length;
      var index = Std.parseInt(field); if (index == null) throw 'Invalid array index: $field'; return cast(object, Array<Dynamic>)[index];
    }
    if (Std.isOfType(object, NoteSprite))
    {
      var note:NoteSprite = cast object;
      switch (field) { case 'noteData': return cast(note.direction, Int); case 'noteType': return note.kind; case 'mustPress': return note.noteData.getMustHitNote(); case 'isSustainNote': return false; case 'sustainLength': return note.length; default: }
    }
    if (Std.isOfType(object, funkin.play.notes.SustainTrail))
    {
      var hold:funkin.play.notes.SustainTrail = cast object;
      switch (field) { case 'noteData': return cast(hold.noteDirection, Int); case 'noteType': return hold.noteData?.kind ?? ''; case 'mustPress': return hold.noteData?.getMustHitNote() ?? false; case 'isSustainNote': return true; default: }
    }
    if (Std.isOfType(object, funkin.data.song.SongData.SongNoteDataRaw))
    {
      var data:funkin.data.song.SongData.SongNoteDataRaw = cast object;
      switch (field) { case 'strumTime': return data.time; case 'noteData': return data.data % 4; case 'mustPress': return data.data < 4; case 'noteType': return data.kind; case 'sustainLength': return data.length; case 'isSustainNote': return false; default: }
    }
    if (maps && Std.isOfType(object, haxe.ds.StringMap)) return cast(object, Map<String, Dynamic>).get(field);
    return Reflect.getProperty(object, field);
  }

  function write(object:Dynamic, field:String, value:Dynamic, maps:Bool):Void
  {
    if (object == null) throw 'Cannot write $field on a missing object';
    if (object == host.game && field == 'isCameraOnForcedPos') { host.cameraForced = value == true; return; }
    if (Std.isOfType(object, funkin.play.character.BaseCharacter) && field == 'healthColorArray')
    {
      host.setHealthColor(cast object, value);
      return;
    }
    if (host.noteOptions.supports(field) && host.noteOptions.data(object) != null)
    {
      host.noteOptions.write(object, field, value, script.root);
      return;
    }
    if (Std.isOfType(object, Array))
    {
      var index = Std.parseInt(field); var array:Array<Dynamic> = cast object;
      if (index == null || index < 0 || index >= array.length) throw 'Invalid array index: $field'; array[index] = value; return;
    }
    if (Std.isOfType(object, NoteSprite)) field = switch (field) { case 'noteData': 'direction'; case 'noteType': 'kind'; case 'sustainLength': 'length'; default: field; };
    if (Std.isOfType(object, funkin.data.song.SongData.SongNoteDataRaw))
    {
      var data:funkin.data.song.SongData.SongNoteDataRaw = cast object;
      switch (field)
      {
        case 'noteData': data.data = Std.int(data.data / 4) * 4 + Std.int(value) % 4; return;
        case 'mustPress': data.data = data.data % 4 + (value == true ? 0 : 4); return;
        default:
      }
      field = switch (field) { case 'strumTime': 'time'; case 'noteType': 'kind'; case 'sustainLength': 'length'; default: field; };
    }
    if (maps && Std.isOfType(object, haxe.ds.StringMap)) cast(object, Map<String, Dynamic>).set(field, value);
    else Reflect.setProperty(object, field, value);
  }

  function get(path:String, parent:Dynamic = null, maps:Bool = false):Dynamic
  {
    var parts = tokens(path);
    if (parts.length == 0)
    {
      if (parent != null) return parent;
      return host.game;
    }
    var obj = parent == null ? host.rootObject(parts.shift()) : parent;
    for (part in parts) obj = read(obj, part, maps); return obj;
  }

  function set(path:String, value:Dynamic, parent:Dynamic = null, maps:Bool = false):Dynamic
  {
    var parts = tokens(path); if (parts.length == 0) throw 'Empty property path';
    var field = parts.pop(); var obj:Dynamic = parent;
    if (obj == null) obj = host.game;
    if (parent == null && parts.length > 0) obj = host.rootObject(parts.shift());
    for (part in parts) obj = read(obj, part, maps);
    write(obj, field, value, maps); return value;
  }

  function classFor(name:String):Class<Dynamic>
  {
    name = switch (name) { case 'states.PlayState', 'PlayState': 'funkin.play.PlayState'; case 'backend.Conductor', 'Conductor': 'funkin.Conductor'; case 'backend.ClientPrefs', 'ClientPrefs': 'funkin.Preferences'; default: name; };
    var cls = Type.resolveClass(name); if (cls == null) throw 'Class not available in V-Slice: $name'; return cls;
  }

  function invoke(path:String, args:Array<Dynamic>, parent:Dynamic = null):Dynamic
  {
    var parts = tokens(path); var name = parts.pop(); var obj:Dynamic = parent;
    if (parts.length > 0) obj = get(parts.join('.'), parent);
    else if (obj == null) obj = host.game;
    if (obj == null) throw 'Method target not found: $path';
    var method = Reflect.field(obj, name); if (!Reflect.isFunction(method)) throw 'Method not available: $path';
    return Reflect.callMethod(obj, method, [for (arg in args ?? []) parseInstance(arg)]);
  }

  function parseInstance(value:Dynamic):Dynamic
  {
    if (Std.isOfType(value, String) && cast(value, String).startsWith('##PSYCHLUA_STRINGTOOBJ'))
    {
      var path = cast(value, String).substr('##PSYCHLUA_STRINGTOOBJ'.length); var split = path.split('::');
      return split.length == 2 ? get(split[1], classFor(split[0])) : get(path);
    }
    if (Std.isOfType(value, Array)) return [for (entry in cast(value, Array<Dynamic>)) parseInstance(entry)];
    return value;
  }

  function groupMembers(group:Dynamic):Array<Dynamic>
  { if (group == null) throw 'Group not found'; return Std.isOfType(group, Array) ? cast group : cast Reflect.getProperty(group, 'members'); }

  function member(group:String, index:Int):Dynamic
  {
    var members = groupMembers(get(group)); if (members == null || index < 0 || index >= members.length || members[index] == null) throw 'Missing member $index of $group';
    return members[index];
  }
}
#end
