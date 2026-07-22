package funkin.play.event;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;
import funkin.Paths;
import funkin.Conductor;
import funkin.Preferences;
import funkin.util.Constants;
import funkin.audio.FunkinSound;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.dialogue.ConversationRegistry;
import funkin.data.dialogue.DialogueBoxRegistry;
import funkin.data.dialogue.SpeakerRegistry;
import funkin.data.song.SongData.SongEventData;
import funkin.data.stage.StageRegistry;
#if hxvlc
import funkin.graphics.video.FunkinVideoSprite;
#end
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.Countdown;
import funkin.play.Countdown.CountdownStep;
import LuaShaderManager;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import sys.FileSystem;
import haxe.io.Path;

class LuaSliceSongEventRuntime
{
  static final EVENT_PRELOAD_LOOKAHEAD_MS:Float = 8000;

  final preloaded:Map<String, Bool> = [];
  final sounds:Map<String, FlxSound> = [];
#if hxvlc
  final videoAudio:Map<String, FunkinVideoSprite> = [];
#end
  final soundTweens:Map<String, FlxTween> = [];
  final overlays:Map<String, FlxSprite> = [];
  final overlayTweens:Map<String, FlxTween> = [];
  final overlayAtlases:Map<String, FlxAtlasFrames> = [];
  final shaderTweens:Map<String, FlxTween> = [];
  final shaderValues:Map<String, Float> = [];
  final shaderPositions:Map<String, Array<Float>> = [];
  final shaderColors:Map<String, Array<Float>> = [];
  final hudFadeValues:Map<String, Float> = [];
  final hudFadeTweens:Map<String, FlxTween> = [];
  final timers:Array<FlxTimer> = [];
  final visualTweens:Array<FlxTween> = [];
  final pausedEventTweens:Array<FlxTween> = [];
  final pausedEventTimers:Array<FlxTimer> = [];
  var dialogueOriginalMusicVolume:Null<Float> = null;
  var dialogueOriginalHudVisible:Null<Bool> = null;
  var dialoguePausedGameplay:Bool = false;
  var dialogueTween:Null<FlxTween> = null;
  var countdownTimer:Null<FlxTimer> = null;
  var blackoutTimer:Null<FlxTimer> = null;
  var healthDrainAmount:Float = 0;
  var healthDrainDirection:Int = -1;
  var healthDrainCanDie:Bool = true;
  var chartEvents:Array<SongEventData> = [];
  var nextPreloadEventIndex:Int = 0;
  var lastPreloadPosition:Float = Math.NEGATIVE_INFINITY;
  var destroyed:Bool = false;
  public final shaders:LuaShaderManager = new LuaShaderManager();

  public function new() {}

  public function preloadChartEvents(events:Array<SongEventData>):Void
  {
    chartEvents = events ?? [];
    nextPreloadEventIndex = 0;
    lastPreloadPosition = Math.NEGATIVE_INFINITY;
    preloadUpcomingEvents(Conductor.instance.songPosition);
  }

  function preloadUpcomingEvents(songPosition:Float):Void
  {
    if (destroyed || chartEvents.length == 0 || !Math.isFinite(songPosition)) return;

    if (songPosition < lastPreloadPosition)
    {
      nextPreloadEventIndex = 0;
      while (nextPreloadEventIndex < chartEvents.length && chartEvents[nextPreloadEventIndex].time < songPosition)
        nextPreloadEventIndex++;
    }

    final preloadUntil = songPosition + EVENT_PRELOAD_LOOKAHEAD_MS;
    while (nextPreloadEventIndex < chartEvents.length)
    {
      final event = chartEvents[nextPreloadEventIndex];
      if (event.time > preloadUntil) break;
      nextPreloadEventIndex++;

      switch (event.eventKind)
      {
        case 'ChangeCharacter' if (event.getBool('preload') ?? false):
          preload('character', event.getString('id') ?? '');
        case 'ChangeStage' if (event.getBool('preload') ?? false):
          preload('stage', event.getString('stage') ?? '');
        case 'PlayDialogue':
          preload('dialogue', event.getString('conversation') ?? '');
        case 'Overlay' if ((event.getString('action') ?? 'create') == 'create'):
          final kind = event.getString('kind') ?? 'solid';
          if (kind == 'image' || kind == 'animated') preloadOverlay(kind, event.getString('resource') ?? '', event.getString('atlasType') ?? 'sparrow');
        default:
      }
    }
    lastPreloadPosition = songPosition;
  }

  public function preload(type:String, resource:String):Bool
  {
    type = type == null ? '' : type.toLowerCase();
    resource = resource == null ? '' : resource.trim();
    if (type == '' || resource == '') return warn('Preload Resource requires a type and resource.');
    final key:String = '${type}:${resource}';
    if (preloaded.exists(key)) return true;

    try
    {
      switch (type)
      {
        case 'image':
          final path = resolveImageAsset(resource);
          if (path == null) return warn('Image not found: ${resource}');
          FlxG.bitmap.add(path);
        case 'sound':
          final path = resolveAudioAsset(resource);
          if (path == null) return warn('Sound not found: ${resource}');
          FlxG.sound.cache(path);
        case 'music':
          final path = resolveMusicAsset(resource);
          if (path == null) return warn('Music not found: ${resource}');
          FlxG.sound.cache(path);
        case 'character':
          final character = CharacterDataParser.fetchCharacter(resource, false, false);
          if (character == null) return warn('Character not found: ${resource}');
          character.destroy();
        case 'stage':
          final stage = StageRegistry.instance.createFreshEntry(resource);
          if (stage == null) return warn('Stage not found: ${resource}');
          for (path in stage.fetchAssetPaths())
            if (Assets.exists(path) || FileSystem.exists(path)) FlxG.bitmap.add(path);
          ScriptEventDispatcher.callEvent(stage, new ScriptEvent(DESTROY, false));
          stage.destroy();
        case 'stageobject', 'stage object':
          final prop = PlayState.instance?.currentStage?.getNamedProp(resource);
          if (prop == null) return warn('Stage object not found: ${resource}');
          if (prop.graphic != null) FlxG.bitmap.add(prop.graphic);
        case 'shader':
          final fragment = resource.startsWith('frag:') ? resource.substr(5) : resource;
          final isFragment = resource.startsWith('frag:') || ShaderSongEvent.listFragmentShaders().contains(fragment);
          if (isFragment)
          {
            if (!shaders.initShader(fragment, fragment)) return warn('Shader fragment not found: ${resource}');
          }
          else
          {
            final className = shaderClassName(resource);
            if (!shaders.initScriptedShader(className, className)) return warn('Shader HXC not found: ${resource}');
          }
        case 'dialogue', 'dialogue data':
          if (!preloadDialogue(resource)) return false;
        default:
          return warn('Unknown preload resource type: ${type}');
      }
      preloaded.set(key, true);
      return true;
    }
    catch (e)
    {
      return warn('Could not preload ${type} "${resource}": ${e}');
    }
  }

  function preloadDialogue(id:String):Bool
  {
    final conversation = ConversationRegistry.instance.fetchEntry(id);
    final data = conversation?._data;
    if (conversation == null || data == null) return warn('Dialogue not found: ${id}');

    if (data.music != null && data.music.asset != null && data.music.asset != '')
    {
      var musicPath = Paths.music(data.music.asset);
      if (!Assets.exists(musicPath)) musicPath = Paths.music(data.music.asset, 'week6');
      if (Assets.exists(musicPath)) FlxG.sound.cache(musicPath);
    }

    final speakers:Map<String, Bool> = [];
    final boxes:Map<String, Bool> = [];
    for (entry in data.dialogue)
    {
      if (entry.speaker != null && entry.speaker != '' && !speakers.exists(entry.speaker))
      {
        final speaker = SpeakerRegistry.instance.fetchEntry(entry.speaker);
        if (speaker == null) return warn('Dialogue speaker not found: ${entry.speaker}');
        Paths.getSparrowAtlas(speaker._data.assetPath);
        speakers.set(entry.speaker, true);
      }

      if (entry.box != null && entry.box != '' && !boxes.exists(entry.box))
      {
        final box = DialogueBoxRegistry.instance.fetchEntry(entry.box);
        if (box == null) return warn('Dialogue box not found: ${entry.box}');
        Paths.getSparrowAtlas(box._data.assetPath);
        boxes.set(entry.box, true);
      }
    }
    return true;
  }

  function preloadOverlay(kind:String, resource:String, atlasType:String):Bool
  {
    final imagePath = resolveImageAsset(resource);
    if (imagePath == null) return warn('Overlay image not found: ${resource}');
    FlxG.bitmap.add(imagePath);
    if (kind != 'animated') return true;
    final normalizedAtlasType = atlasType == 'packer' ? 'packer' : 'sparrow';
    final atlasPath = Path.withoutExtension(imagePath) + (normalizedAtlasType == 'packer' ? '.txt' : '.xml');
    if (!Assets.exists(atlasPath) && !FileSystem.exists(atlasPath)) return warn('Animated overlay ${normalizedAtlasType} atlas not found: ${atlasPath}');
    final key = '${normalizedAtlasType}:${imagePath}';
    if (!overlayAtlases.exists(key))
      overlayAtlases.set(key,
        normalizedAtlasType == 'packer' ? FlxAtlasFrames.fromSpriteSheetPacker(imagePath, atlasPath) : FlxAtlasFrames.fromSparrow(imagePath, atlasPath));
    return true;
  }

  public function getSound(tag:String):Null<FlxSound>
  {
    return sounds.get(tag);
  }

  public function controlSound(action:String, tag:String, value:Float = 1, duration:Float = 0):Bool
  {
    final sound = sounds.get(tag);
    #if hxvlc
    final video = videoAudio.get(tag);
    #end
    if (sound == null #if hxvlc && video == null #end) return warn('Audio tag not found: ${tag}');
    switch (action)
    {
      case 'pause':
        if (sound != null) sound.pause();
        #if hxvlc
        else video.pause();
        #end
      case 'resume':
        if (sound != null) sound.resume();
        #if hxvlc
        else video.resume();
        #end
      case 'volume':
        final target = Math.max(0, Math.min(1, value));
        if (sound != null) sound.volume = target;
        #if hxvlc
        else if (video.bitmap != null) video.bitmap.volumeAdjust = target;
        #end
      case 'fadein':
        if (sound != null)
        {
          sound.volume = 0;
          sound.play();
        }
        #if hxvlc
        else
        {
          if (video.bitmap != null) video.bitmap.volumeAdjust = 0;
          video.resume();
        }
        #end
        return tweenSound(tag, Math.max(0, Math.min(1, value)), duration, false);
      case 'fadeout': return tweenSound(tag, Math.max(0, Math.min(1, value)), duration, value <= 0);
      default: return warn('Unknown audio action: ${action}');
    }
    return true;
  }

  public function createOverlay(tag:String, kind:String, resource:String, color:Dynamic, secondColor:Dynamic, alpha:Float, x:Float, y:Float, scale:Float,
      angle:Float, blend:String, cameraName:String, fadeIn:Float, atlasType:String = 'sparrow', prefix:String = ''):Bool
  {
    if (tag == null || tag.trim() == '') return warn('Overlay requires a tag.');
    removeOverlay(tag, 0);
    var sprite:FlxSprite = null;
    try
    {
      switch (kind)
      {
        case 'solid':
          final bitmap = new BitmapData(FlxG.width, FlxG.height, true, parseColor(color, FlxColor.BLACK));
          sprite = new FlxSprite().loadGraphic(bitmap, false, 0, 0, true);
        case 'gradient':
          final bitmap = FlxGradient.createGradientBitmapData(FlxG.width, FlxG.height,
            [parseColor(color, FlxColor.BLACK), parseColor(secondColor, FlxColor.TRANSPARENT)], 1, 90, true);
          sprite = new FlxSprite().loadGraphic(bitmap, false, 0, 0, true);
        case 'image':
          final path = resolveImageAsset(resource);
          if (path == null) return warn('Overlay image not found: ${resource}');
          final graphic = FlxG.bitmap.add(path);
          if (graphic == null) return warn('Could not load overlay image: ${resource}');
          sprite = new FlxSprite().loadGraphic(graphic);
        case 'animated':
          final imagePath = resolveImageAsset(resource);
          if (imagePath == null) return warn('Animated overlay image not found: ${resource}');
          final normalizedAtlasType = atlasType == 'packer' ? 'packer' : 'sparrow';
          final atlasPath = Path.withoutExtension(imagePath) + (normalizedAtlasType == 'packer' ? '.txt' : '.xml');
          if (!Assets.exists(atlasPath) && !FileSystem.exists(atlasPath)) return warn('Animated overlay ${atlasType} atlas not found: ${atlasPath}');
          sprite = new FlxSprite();
          final atlasKey = '${normalizedAtlasType}:${imagePath}';
          sprite.frames = overlayAtlases.get(atlasKey);
          if (sprite.frames == null)
          {
            preloadOverlay('animated', resource, normalizedAtlasType);
            sprite.frames = overlayAtlases.get(atlasKey);
          }
          if (sprite.frames == null) return warn('Could not load animated overlay atlas: ${atlasPath}');
          if (prefix.trim() == '')
            sprite.animation.add('overlay', [for (i in 0...sprite.frames.frames.length) i], 24, true);
          else
            sprite.animation.addByPrefix('overlay', prefix, 24, true);
          if (sprite.animation.getByName('overlay') == null) return warn('Animated overlay prefix not found: ${prefix}');
          sprite.animation.play('overlay');
        default:
          return warn('Unknown overlay type: ${kind}');
      }
      sprite.scale.set(scale, scale);
      sprite.updateHitbox();
      sprite.setPosition(x, y);
      sprite.angle = angle;
      sprite.scrollFactor.set();
      sprite.blend = parseBlendMode(blend);
      sprite.cameras = [resolveCamera(cameraName) ?? PlayState.instance?.camHUD];
      sprite.zIndex = 2000;
      sprite.alpha = fadeIn > 0 ? 0 : Math.max(0, Math.min(1, alpha));
      PlayState.instance?.add(sprite);
      PlayState.instance?.refresh();
      overlays.set(tag, sprite);
      if (fadeIn > 0) tweenOverlay(tag, alpha, fadeIn, false);
      return true;
    }
    catch (e)
    {
      sprite?.destroy();
      return warn('Could not create overlay "${tag}": ${e}');
    }
  }

  public function getOverlay(tag:String):Null<FlxSprite>
  {
    return overlays.get(tag);
  }

  public function tweenOverlay(tag:String, alpha:Float, duration:Float, removeAfter:Bool):Bool
  {
    final overlay = overlays.get(tag);
    if (overlay == null) return warn('Overlay not found: ${tag}');
    overlayTweens.get(tag)?.cancel();
    final tween = FlxTween.tween(overlay, {alpha: Math.max(0, Math.min(1, alpha))}, Math.max(0, duration), {
      onComplete: function(_)
      {
        overlayTweens.remove(tag);
        if (removeAfter) removeOverlay(tag, 0);
      }
    });
    overlayTweens.set(tag, tween);
    return true;
  }

  public function removeOverlay(tag:String, fadeOut:Float):Bool
  {
    final overlay = overlays.get(tag);
    if (overlay == null) return false;
    if (fadeOut > 0) return tweenOverlay(tag, 0, fadeOut, true);
    overlayTweens.get(tag)?.cancel();
    overlayTweens.remove(tag);
    PlayState.instance?.remove(overlay, true);
    overlay.destroy();
    overlays.remove(tag);
    return true;
  }

  public function blackout(fadeIn:Float, hold:Float, fadeOut:Float, camera:String, keepHud:Bool, instant:Bool, color:Dynamic):Bool
  {
    final targetCamera = resolveCamera(keepHud ? 'game' : camera);
    if (targetCamera == null) return warn('Blackout camera not found: ${camera}');
    final fadeColor = parseColor(color, FlxColor.BLACK);
    blackoutTimer?.cancel();
    if (blackoutTimer != null) timers.remove(blackoutTimer);
    targetCamera.stopFade();
    targetCamera.fade(fadeColor, instant ? 0 : Math.max(0, fadeIn), false, null, true);
    final delay = (instant ? 0 : fadeIn) + Math.max(0, hold);
    blackoutTimer = new FlxTimer().start(delay, function(timer)
    {
      timers.remove(timer);
      if (blackoutTimer == timer) blackoutTimer = null;
      targetCamera.fade(fadeColor, instant ? 0 : Math.max(0, fadeOut), true, null, true);
    });
    timers.push(blackoutTimer);
    return true;
  }

  public function applyShader(shaderId:String, tag:String, targetType:String, targetName:String, fadeProperty:String = 'amount', fadeIn:Float = 0,
      fadeOut:Float = 0, ignoreTransparentPixels:Bool = false, includeTransparentPixels:Bool = false):Bool
  {
    if (!Preferences.allowSongShaders()) return warn('Song shaders are disabled in Performance options.');
    if (shaders.hasShader(tag)
      && (shaders.usesTransparentPixelGuard(tag) != ignoreTransparentPixels || shaders.includesTransparentPixels(tag) != includeTransparentPixels))
      shaders.destroyShader(tag);
    if (!shaders.hasShader(tag) && !(shaders.hasShader(shaderId) && shaders.usesTransparentPixelGuard(shaderId) == ignoreTransparentPixels
      && shaders.includesTransparentPixels(shaderId) == includeTransparentPixels && shaders.aliasShader(shaderId, tag))
      && !shaders.initShader(shaderId, tag, ignoreTransparentPixels, includeTransparentPixels))
      return warn('Shader not found: ${shaderId}');
    final applied = applyShaderToTargets(tag, targetType, targetName);
    if (applied) applyShaderFades(tag, fadeProperty, fadeIn, fadeOut);
    return applied;
  }

  public function applyScriptedShader(className:String, tag:String, targetType:String, targetName:String, fadeProperty:String = 'amount', fadeIn:Float = 0,
      fadeOut:Float = 0):Bool
  {
    if (!Preferences.allowSongShaders()) return warn('Song shaders are disabled in Performance options.');
    final sourceTag = shaderClassName(className);
    if (!shaders.hasShader(tag) && !(shaders.hasShader(sourceTag) && shaders.aliasShader(sourceTag, tag)) && !shaders.initScriptedShader(sourceTag, tag))
      return warn('Shader HXC not found: ${className}');
    final applied = applyShaderToTargets(tag, targetType, targetName);
    if (applied) applyShaderFades(tag, fadeProperty, fadeIn, fadeOut);
    return applied;
  }

  public function applyBuiltInShader(name:String, tag:String, targetType:String, targetName:String):Bool
  {
    if (!Preferences.allowSongShaders()) return warn('Song shaders are disabled in Performance options.');
    if (!shaders.hasShader(tag) && !shaders.initBuiltInShader(name, tag)) return warn('Built-in shader not found: ${name}');
    return applyShaderToTargets(tag, targetType, targetName);
  }

  function applyShaderToTargets(tag:String, targetType:String, targetName:String):Bool
  {
    if (targetType == 'camera' && targetName == 'screen')
    {
      var applied = false;
      for (name in ['game', 'hud'])
      {
        final camera = resolveCamera(name);
        if (camera != null) applied = shaders.applyToCamera(tag, camera) || applied;
      }
      if (!applied) warn('Could not apply shader "${tag}" to the screen.');
      return applied;
    }
    final camera = targetType == 'camera' ? resolveCamera(targetName) : null;
    if (camera != null)
    {
      final applied = shaders.applyToCamera(tag, camera);
      if (!applied) warn('Could not apply shader "${tag}" to camera "${targetName}".');
      return applied;
    }
    if (targetType == 'character' && targetName == 'all')
    {
      var applied = false;
      for (name in ['bf', 'dad', 'gf'])
      {
        final character = resolveTarget('character', name);
        if (character != null) applied = shaders.applyToTarget(tag, character) || applied;
      }
      if (!applied) warn('No characters were available for the shader.');
      return applied;
    }
    final target = resolveTarget(targetType, targetName);
    if (target == null) return warn('Shader target not found: ${targetType}:${targetName}');
    final applied = targetType == 'object' || targetType == 'stageobject' || targetType == 'stage object' ? shaders.applyToObject(tag, target) : shaders.applyToTarget(tag, target);
    if (!applied) warn('Could not apply shader "${tag}" to ${targetType} "${targetName}".');
    return applied;
  }

  function applyShaderFades(tag:String, property:String, fadeIn:Float, fadeOut:Float):Void
  {
    if (fadeIn > 0) tweenShaderProperty(tag, property, 0, 1, fadeIn, 'linear');
    if (fadeOut > 0) schedule(Math.max(0, fadeIn), function() tweenShaderProperty(tag, property, null, 0, fadeOut, 'linear'));
  }

  public function removeShader(targetType:String, targetName:String, tag:String, fadeOut:Float = 0, property:String = 'amount'):Bool
  {
    if (fadeOut > 0)
    {
      if (!tweenShaderProperty(tag, property, null, 0, fadeOut, 'linear')) return false;
      schedule(fadeOut, function() removeShader(targetType, targetName, tag, 0, property));
      return true;
    }
    for (key in shaderTweens.keys().array())
    {
      if (!key.startsWith('${tag}:')) continue;
      shaderTweens.get(key)?.cancel();
      shaderTweens.remove(key);
    }
    var result = false;
    if (targetType == 'camera' && targetName == 'screen')
    {
      for (name in ['game', 'hud'])
      {
        final camera = resolveCamera(name);
        if (camera != null) result = shaders.clearCameraTag(camera, tag) || result;
      }
    }
    else
    {
      final camera = targetType == 'camera' ? resolveCamera(targetName) : null;
      if (camera != null)
        result = shaders.clearCameraTag(camera, tag);
      else if (targetType == 'character' && targetName == 'all')
      {
        for (name in ['bf', 'dad', 'gf'])
        {
          final character = resolveTarget('character', name);
          if (character != null) result = shaders.clearTargetTag(character, tag) || result;
        }
      }
      else
      {
        final target = resolveTarget(targetType, targetName);
        if (target != null) result = shaders.clearTargetTag(target, tag);
      }
    }
    shaders.destroyShader(tag);
    for (key in shaderValues.keys().array())
      if (key.startsWith('${tag}:')) shaderValues.remove(key);
    for (key in shaderPositions.keys().array())
      if (key.startsWith('${tag}:')) shaderPositions.remove(key);
    for (key in shaderColors.keys().array())
      if (key.startsWith('${tag}:')) shaderColors.remove(key);
    if (!result) warn('Shader target not found: ${targetType}:${targetName}');
    return result;
  }

  /**
   * Temporarily removes existing shaders from the selected event target.
   */
  public function clearShadersForTarget(targetType:String, targetName:String):Void
  {
    if (targetType == 'camera' && targetName == 'screen')
    {
      for (name in ['game', 'hud'])
      {
        final camera = resolveCamera(name);
        if (camera != null) shaders.suppressCameraShaders(camera);
      }
    }
    else if (targetType == 'camera')
    {
      final camera = resolveCamera(targetName);
      if (camera != null) shaders.suppressCameraShaders(camera);
    }
    else if (targetType == 'character' && targetName == 'all')
    {
      for (name in ['bf', 'dad', 'gf'])
      {
        final character = resolveTarget('character', name);
        if (character != null) shaders.suppressTargetShaders(character);
      }
    }
    else
    {
      final target = resolveTarget(targetType, targetName);
      if (target != null) shaders.suppressTargetShaders(target);
    }
  }

  public function setShaderProperty(tag:String, property:String, value:Float):Bool
  {
    if (!shaders.setFloat(tag, property, value)) return warn('Could not set shader property ${tag}.${property}.');
    shaderValues.set('${tag}:${property}', value);
    return true;
  }

  public function setShaderPosition(tag:String, property:String, x:Float, y:Float):Bool
  {
    if (!shaders.setFloatArray(tag, property, [x, y])) return warn('Could not set shader position ${tag}.${property}.');
    shaderPositions.set('${tag}:${property}', [x, y]);
    return true;
  }

  public function setShaderInteger(tag:String, property:String, value:Int):Bool
  {
    if (!shaders.setInt(tag, property, value)) return warn('Could not set shader property ${tag}.${property}.');
    shaderValues.set('${tag}:${property}', value);
    return true;
  }

  public function setShaderBool(tag:String, property:String, value:Bool):Bool
  {
    if (!shaders.setBool(tag, property, value)) return warn('Could not set shader property ${tag}.${property}.');
    return true;
  }

  public function setShaderColor(tag:String, property:String, value:Dynamic):Bool
  {
    final parsedColor = parseColor(value, FlxColor.WHITE);
    final channels = colorChannels(parsedColor);
    var applied = false;
    if (shaders.setColor(tag, property, parsedColor))
    {
      applied = true;
    }
    else if (property == 'color')
    {
      applied = shaders.setFloat(tag, 'colorRed', channels[0]);
      applied = shaders.setFloat(tag, 'colorGreen', channels[1]) || applied;
      applied = shaders.setFloat(tag, 'colorBlue', channels[2]) || applied;
      applied = shaders.setFloat(tag, 'colorAlpha', channels[3]) || applied;
    }
    else
      applied = shaders.setFloatArray(tag, property, channels.slice(0, 3));
    if (!applied) return warn('Could not set shader color ${tag}.${property}.');
    shaderColors.set('${tag}:${property}', channels);
    return true;
  }

  public function tweenShaderProperty(tag:String, property:String, from:Null<Float>, to:Float, duration:Float, ease:String):Bool
  {
    if (!shaders.hasShader(tag)) return warn('Shader tag not found: ${tag}');
    final valueKey = '${tag}:${property}';
    final tweenKey = valueKey;
    final holder:Dynamic = {value: from ?? shaderValues.get(valueKey) ?? 1.0};
    if (from != null && !setShaderProperty(tag, property, from)) return false;
    shaderTweens.get(tweenKey)?.cancel();
    final tween = FlxTween.tween(holder, {value: to}, Math.max(0, duration), {
      ease: resolveEase(ease),
      onUpdate: function(_)
      {
        shaders.setFloat(tag, property, holder.value);
        shaderValues.set(valueKey, holder.value);
      },
      onComplete: function(_)
      {
        shaderValues.set(valueKey, to);
        shaderTweens.remove(tweenKey);
      }
    });
    shaderTweens.set(tweenKey, tween);
    return true;
  }

  public function tweenShaderPosition(tag:String, property:String, fromX:Null<Float>, fromY:Null<Float>, toX:Float, toY:Float, duration:Float,
      ease:String):Bool
  {
    if (!shaders.hasShader(tag)) return warn('Shader tag not found: ${tag}');
    final valueKey = '${tag}:${property}';
    final tweenKey = valueKey;
    final previous = shaderPositions.get(valueKey) ?? [0.0, 0.0];
    final holder:Dynamic = {x: fromX ?? previous[0], y: fromY ?? previous[1]};
    if ((fromX != null || fromY != null) && !setShaderPosition(tag, property, holder.x, holder.y)) return false;
    shaderTweens.get(tweenKey)?.cancel();
    final tween = FlxTween.tween(holder, {x: toX, y: toY}, Math.max(0, duration), {
      ease: resolveEase(ease),
      onUpdate: function(_)
      {
        shaders.setFloatArray(tag, property, [holder.x, holder.y]);
        shaderPositions.set(valueKey, [holder.x, holder.y]);
      },
      onComplete: function(_)
      {
        shaderPositions.set(valueKey, [toX, toY]);
        shaderTweens.remove(tweenKey);
      }
    });
    shaderTweens.set(tweenKey, tween);
    return true;
  }

  public function tweenShaderInteger(tag:String, property:String, from:Null<Float>, to:Int, duration:Float, ease:String):Bool
  {
    if (!shaders.hasShader(tag)) return warn('Shader tag not found: ${tag}');
    final valueKey = '${tag}:${property}';
    final tweenKey = valueKey;
    final holder:Dynamic = {value: from ?? shaderValues.get(valueKey) ?? 0};
    if (from != null && !setShaderInteger(tag, property, Math.round(from))) return false;
    shaderTweens.get(tweenKey)?.cancel();
    final tween = FlxTween.tween(holder, {value: to}, Math.max(0, duration), {
      ease: resolveEase(ease),
      onUpdate: function(_)
      {
        final rounded = Math.round(holder.value);
        shaders.setInt(tag, property, rounded);
        shaderValues.set(valueKey, rounded);
      },
      onComplete: function(_)
      {
        shaderValues.set(valueKey, to);
        shaderTweens.remove(tweenKey);
      }
    });
    shaderTweens.set(tweenKey, tween);
    return true;
  }

  public function tweenShaderColor(tag:String, property:String, from:Dynamic, to:Dynamic, duration:Float, ease:String):Bool
  {
    if (!shaders.hasShader(tag)) return warn('Shader tag not found: ${tag}');
    final valueKey = '${tag}:${property}';
    final tweenKey = valueKey;
    final previous = shaderColors.get(valueKey) ?? colorChannels(FlxColor.WHITE);
    final start = from == null ? previous : colorChannels(parseColor(from, FlxColor.WHITE));
    final finish = colorChannels(parseColor(to, FlxColor.WHITE));
    final holder:Dynamic = {r: start[0], g: start[1], b: start[2], a: start[3]};
    if (from != null && !setShaderColor(tag, property, from)) return false;
    shaderTweens.get(tweenKey)?.cancel();
    final tween = FlxTween.tween(holder, {r: finish[0], g: finish[1], b: finish[2], a: finish[3]}, Math.max(0, duration), {
      ease: resolveEase(ease),
      onUpdate: function(_)
      {
        final channels = [holder.r, holder.g, holder.b, holder.a];
        final color = FlxColor.fromRGBFloat(channels[0], channels[1], channels[2], channels[3]);
        final builtInColorApplied = shaders.setColor(tag, property, color);
        if (!builtInColorApplied && property == 'color')
        {
          shaders.setFloat(tag, 'colorRed', channels[0]);
          shaders.setFloat(tag, 'colorGreen', channels[1]);
          shaders.setFloat(tag, 'colorBlue', channels[2]);
          shaders.setFloat(tag, 'colorAlpha', channels[3]);
        }
        else if (!builtInColorApplied)
          shaders.setFloatArray(tag, property, channels.slice(0, 3));
        shaderColors.set(valueKey, channels);
      },
      onComplete: function(_)
      {
        shaderColors.set(valueKey, finish);
        shaderTweens.remove(tweenKey);
      }
    });
    shaderTweens.set(tweenKey, tween);
    return true;
  }

  public function showDialogue(id:String, fadeOut:Float, dialogueVolume:Float, fadeIn:Float, pauseGameplay:Bool, keepHud:Bool):Bool
  {
    final state = PlayState.instance;
    if (destroyed || state == null) return false;
    if (!preload('dialogue', id)) return false;
    if (state.currentConversation != null) return warn('A dialogue is already playing.');
    final music = FlxG.sound.music;
    final oldVolume = music?.volume ?? 1;
    final oldHudVisible = state.camHUD.visible;
    dialogueOriginalMusicVolume = oldVolume;
    dialogueOriginalHudVisible = oldHudVisible;
    dialoguePausedGameplay = pauseGameplay;
    if (!keepHud) state.camHUD.visible = false;

    final begin = function()
    {
      dialogueTween = null;
      if (destroyed || PlayState.instance != state) return;
      if (pauseGameplay)
      {
        music?.pause();
        state.vocals?.pause();
      }
      state.startConversation(id, function()
      {
        if (destroyed || PlayState.instance != state) return;
        if (!keepHud) state.camHUD.visible = oldHudVisible;
        if (pauseGameplay)
        {
          music?.resume();
          state.vocals?.resume();
        }
        if (music != null)
        {
          tweenDialogueVolume(music, oldVolume, fadeIn);
        }
        dialogueOriginalMusicVolume = null;
        dialogueOriginalHudVisible = null;
        dialoguePausedGameplay = false;
        preloaded.remove('dialogue:${id}');
      });
    };

    if (music != null && fadeOut > 0)
      tweenDialogueVolume(music, Math.max(0, Math.min(1, dialogueVolume)), fadeOut, begin);
    else
    {
      if (music != null) music.volume = Math.max(0, Math.min(1, dialogueVolume));
      begin();
    }
    return true;
  }

  function tweenDialogueVolume(music:FlxSound, volume:Float, duration:Float, ?onComplete:Void->Void):Void
  {
    dialogueTween?.cancel();
    if (duration <= 0)
    {
      music.volume = volume;
      dialogueTween = null;
      if (onComplete != null) onComplete();
      return;
    }
    dialogueTween = FlxTween.num(music.volume, volume, duration, {
      onComplete: function(_)
      {
        dialogueTween = null;
        if (onComplete != null) onComplete();
      }
    }, function(value)
    {
      if (!destroyed) music.volume = value;
    });
  }

  public function playCountdown():Bool
  {
    if (destroyed || PlayState.instance == null) return false;
    countdownTimer?.cancel();
    if (countdownTimer != null) timers.remove(countdownTimer);
    final steps = [CountdownStep.THREE, CountdownStep.TWO, CountdownStep.ONE, CountdownStep.GO];
    var index = 0;
    Countdown.showCountdownGraphic(steps[index]);
    Countdown.playCountdownSound(steps[index]);
    countdownTimer = new FlxTimer().start(Conductor.instance.beatLengthMs / 1000, function(timer)
    {
      index++;
      if (destroyed || PlayState.instance == null || index >= steps.length)
      {
        timer.cancel();
        timers.remove(timer);
        if (countdownTimer == timer) countdownTimer = null;
        return;
      }
      Countdown.showCountdownGraphic(steps[index]);
      Countdown.playCountdownSound(steps[index]);
      if (index == steps.length - 1)
      {
        timers.remove(timer);
        if (countdownTimer == timer) countdownTimer = null;
      }
    }, steps.length - 1);
    timers.push(countdownTimer);
    return true;
  }

  public function fadeHud(targetName:String, opacity:Float, duration:Float, ease:String):Bool
  {
    final state = PlayState.instance;
    if (state == null) return false;
    final target = normalizeHudFadeTarget(targetName);
    if (!isHudFadeTarget(target)) return warn('HUD target not found: ${targetName}');
    final splitTargets = switch (target)
    {
      case 'icons': ['playericons', 'opponenticons'];
      case 'notes': ['playernotes', 'opponentnotes'];
      case 'receptors': ['playerreceptors', 'opponentreceptors'];
      default: null;
    };
    if (splitTargets != null)
    {
      var result = true;
      for (splitTarget in splitTargets)
        if (!fadeHud(splitTarget, opacity, duration, ease)) result = false;
      return result;
    }
    final targetOpacity = Math.max(0, Math.min(1, opacity));
    hudFadeTweens.get(target)?.cancel();
    hudFadeTweens.remove(target);
    if (duration <= 0)
    {
      hudFadeValues.set(target, targetOpacity);
      applyHudFadeValue(target, targetOpacity);
      return true;
    }
    final value = {alpha: hudFadeValues.get(target) ?? 1.0};
    final tween = FlxTween.tween(value, {alpha: targetOpacity}, duration, {
      ease: resolveEase(ease),
      onUpdate: function(_) {
        hudFadeValues.set(target, value.alpha);
        applyHudFadeValue(target, value.alpha);
      },
      onComplete: function(_) {
        hudFadeValues.set(target, targetOpacity);
        hudFadeTweens.remove(target);
        applyHudFadeValue(target, targetOpacity);
      }
    });
    hudFadeTweens.set(target, tween);
    visualTweens.push(tween);
    return true;
  }

  function normalizeHudFadeTarget(target:String):String
  {
    final normalized = target == null ? '' : target.toLowerCase();
    return normalized == 'entirehud' ? 'hud' : normalized;
  }

  function isHudFadeTarget(target:String):Bool
  {
    return ['hud', 'healthbar', 'icons', 'playericons', 'opponenticons', 'notes', 'playernotes', 'opponentnotes', 'receptors', 'playerreceptors',
      'opponentreceptors'].contains(target);
  }

  function applyHudFadeValue(target:String, opacity:Float):Void
  {
    final state = PlayState.instance;
    if (state == null) return;
    switch (target)
    {
      case 'hud': state.camHUD.alpha = opacity;
      case 'healthbar':
        state.healthBar.alpha = opacity;
        state.healthBarBG.alpha = opacity;
        final scoreText:Dynamic = Reflect.field(state, 'scoreText');
        if (scoreText != null) Reflect.setProperty(scoreText, 'alpha', opacity);
      case 'icons':
        if (state.iconP1 != null) state.iconP1.alpha = opacity;
        if (state.iconP2 != null) state.iconP2.alpha = opacity;
      case 'playericons': if (state.iconP1 != null) state.iconP1.alpha = opacity;
      case 'opponenticons': if (state.iconP2 != null) state.iconP2.alpha = opacity;
      case 'notes':
        applyStrumlineNotesAlpha(state.playerStrumline, opacity);
        applyStrumlineNotesAlpha(state.opponentStrumline, opacity);
      case 'playernotes': applyStrumlineNotesAlpha(state.playerStrumline, opacity);
      case 'opponentnotes': applyStrumlineNotesAlpha(state.opponentStrumline, opacity);
      case 'receptors':
        applyGroupAlpha(state.playerStrumline.strumlineNotes, opacity);
        applyGroupAlpha(state.opponentStrumline.strumlineNotes, opacity);
      case 'playerreceptors': applyGroupAlpha(state.playerStrumline.strumlineNotes, opacity);
      case 'opponentreceptors': applyGroupAlpha(state.opponentStrumline.strumlineNotes, opacity);
      default:
    }
  }

  function applyStrumlineNotesAlpha(strumline:funkin.play.notes.Strumline, opacity:Float):Void
  {
    applyGroupAlpha(strumline.notes, opacity);
    applyGroupAlpha(strumline.holdNotes, opacity);
    applyGroupAlpha(strumline.noteHoldCovers, opacity);
    applyGroupAlpha(Reflect.field(strumline, 'notesVwoosh'), opacity);
    applyGroupAlpha(Reflect.field(strumline, 'holdNotesVwoosh'), opacity);
  }

  function applyGroupAlpha(group:Dynamic, opacity:Float):Void
  {
    if (group == null) return;
    Reflect.setProperty(group, 'alpha', 1.0);
    final members:Array<Dynamic> = Reflect.getProperty(group, 'members');
    if (members == null) return;
    for (member in members)
      if (member != null) Reflect.setProperty(member, 'alpha', opacity);
  }

  public function controlStageObject(name:String, action:String, value:Float, value2:Float, text:String, duration:Float, ease:String):Bool
  {
    final state = PlayState.instance;
    final prop = state?.currentStage?.getNamedProp(name);
    if (prop == null) return warn('Stage object not found: ${name}');
    try
    {
      switch (action)
      {
        case 'show': prop.visible = true;
        case 'hide': prop.visible = false;
        case 'move':
          if (duration > 0) visualTweens.push(FlxTween.tween(prop, {x: value, y: value2}, duration, {ease: resolveEase(ease)}));
          else prop.setPosition(value, value2);
        case 'rotate':
          if (duration > 0) visualTweens.push(FlxTween.tween(prop, {angle: value}, duration, {ease: resolveEase(ease)}));
          else prop.angle = value;
        case 'scale':
          if (duration > 0) visualTweens.push(FlxTween.tween(prop.scale, {x: value, y: value2}, duration, {ease: resolveEase(ease)}));
          else prop.scale.set(value, value2);
        case 'opacity':
          if (duration > 0) visualTweens.push(FlxTween.tween(prop, {alpha: value}, duration, {ease: resolveEase(ease)}));
          else prop.alpha = value;
        case 'color': prop.color = parseColor(text, FlxColor.WHITE);
        case 'animation':
          if (prop.animation == null || prop.animation.getByName(text) == null) return warn('Animation not found on ${name}: ${text}');
          prop.animation.play(text, true);
        case 'scrollfactor': prop.scrollFactor.set(value, value2);
        case 'layer':
          prop.zIndex = Std.int(value);
          state.currentStage?.refresh();
        default: return warn('Unknown stage object action: ${action}');
      }
      return true;
    }
    catch (e)
    {
      return warn('Could not control stage object "${name}": ${e}');
    }
  }

  public function schedule(seconds:Float, callback:Void->Void):Void
  {
    final timer = new FlxTimer().start(Math.max(0, seconds), function(timer)
    {
      timers.remove(timer);
      callback();
    });
    timers.push(timer);
  }

  public function setHealthDrain(target:String, amount:Float, canDie:Bool, changeScore:Bool, scoreChange:Int):Bool
  {
    healthDrainAmount = Math.max(0, amount);
    healthDrainDirection = target == 'opponent' ? 1 : -1;
    healthDrainCanDie = canDie;
    final state = PlayState.instance;
    if (changeScore && state != null) state.songScore += scoreChange;
    return true;
  }

  public function updatePersistentEffects(elapsed:Float):Void
  {
    preloadUpcomingEvents(Conductor.instance.songPosition);
    shaders.update(elapsed);
    for (target in hudFadeValues.keys()) applyHudFadeValue(target, hudFadeValues.get(target));
    final state = PlayState.instance;
    if (state != null && !state.isInCutscene && healthDrainAmount > 0 && elapsed > 0)
    {
      var newHealth = state.health + healthDrainAmount * healthDrainDirection * elapsed;
      if (healthDrainDirection < 0 && !healthDrainCanDie)
      {
        newHealth = Math.max(0.001, newHealth);
      }
      state.health = FlxMath.bound(newHealth, Constants.HEALTH_MIN, Constants.HEALTH_MAX);
    }
  }
  public function callLuaEvent(event:ScriptEvent):Void {}

  public function playSound(path:String, tag:String, volume:Float, looped:Bool, fadeIn:Float = 0, fadeOut:Float = 0):Bool
  {
    if (tag == null || tag.trim() == '') return warn('Play Audio requires an audio tag.');
    if (isVideoOrCutscenePath(path))
    {
      warn('Play Audio cannot display a cutscene or video. Only its audio will play.');
      #if hxvlc
      return playVideoAudio(path, tag, volume, looped, fadeIn, fadeOut);
      #else
      return warn('This build cannot read audio from video files.');
      #end
    }
    final extension = Path.extension(path).toLowerCase();
    if (extension != '' && !['ogg', 'mp3', 'wav'].contains(extension))
      return warn('Play Audio only supports OGG, MP3, and WAV audio files.');
    final resolved = resolveAudioAsset(path);
    if (resolved == null) return warn('Audio not found: ${path}');
    removeSound(tag);
    final targetVolume = Math.max(0, Math.min(1, volume));
    final sound = FunkinSound.load(resolved, fadeIn > 0 ? 0 : targetVolume, looped, false, true);
    if (sound == null) return warn('Could not load audio: ${path}');
    sounds.set(tag, sound);
    if (fadeIn > 0) tweenSound(tag, targetVolume, fadeIn, false);
    if (!looped && fadeOut > 0)
    {
      final delay = Math.max(0, sound.length / 1000 - fadeOut);
      schedule(delay, function()
      {
        if (sounds.get(tag) == sound) tweenSound(tag, 0, fadeOut, true);
      });
    }
    return true;
  }

  #if hxvlc
  function playVideoAudio(path:String, tag:String, volume:Float, looped:Bool, fadeIn:Float, fadeOut:Float):Bool
  {
    final resolved = resolveVideoAsset(path);
    if (resolved == null) return warn('Cutscene or video not found: ${path}');
    removeSound(tag);
    final targetVolume = Math.max(0, Math.min(1, volume));
    final video = new FunkinVideoSprite();
    video.visible = false;
    video.active = false;
    if (video.bitmap == null)
    {
      video.destroy();
      return warn('Could not create video audio player for: ${path}');
    }
    video.bitmap.volumeAdjust = fadeIn > 0 ? 0 : targetVolume;
    videoAudio.set(tag, video);
    video.bitmap.onEncounteredError.add(function(message)
    {
      if (videoAudio.get(tag) != video) return;
      warn('Could not play audio from video "${path}": ${message}');
      schedule(0, function()
      {
        if (videoAudio.get(tag) == video) removeSound(tag);
      });
    });
    video.bitmap.onEndReached.add(function()
    {
      if (videoAudio.get(tag) == video) removeSound(tag);
    });
    var fadeScheduled = false;
    video.bitmap.onPlaying.add(function()
    {
      if (fadeScheduled || looped || fadeOut <= 0 || video.bitmap == null) return;
      fadeScheduled = true;
      final length = Std.parseFloat(Std.string(video.bitmap.length)) / 1000;
      if (Math.isFinite(length)) schedule(Math.max(0, length - fadeOut), function()
      {
        if (videoAudio.get(tag) == video) tweenSound(tag, 0, fadeOut, true);
      });
    });
    final options = [':no-video'];
    if (looped) options.push(':input-repeat=-1');
    if (!video.load(resolved, options) || !video.play())
    {
      removeSound(tag);
      return warn('Could not load audio from video: ${path}');
    }
    if (fadeIn > 0) tweenSound(tag, targetVolume, fadeIn, false);
    return true;
  }
  #end

  public function removeSound(tag:String):Bool
  {
    soundTweens.get(tag)?.cancel();
    soundTweens.remove(tag);
    var removed = false;
    final sound = sounds.get(tag);
    if (sound != null)
    {
      sound.stop();
      sound.destroy();
      sounds.remove(tag);
      removed = true;
    }
    #if hxvlc
    final video = videoAudio.get(tag);
    if (video != null)
    {
      videoAudio.remove(tag);
      video.stop();
      video.destroy();
      removed = true;
    }
    #end
    return removed;
  }

  public function tweenSound(tag:String, volume:Float, duration:Float, stopAfter:Bool):Bool
  {
    final sound = sounds.get(tag);
    #if hxvlc
    final video = videoAudio.get(tag);
    #end
    if (sound == null #if hxvlc && video == null #end) return warn('Audio tag not found: ${tag}');
    soundTweens.get(tag)?.cancel();
    final startVolume = sound != null ? sound.volume : #if hxvlc (video.bitmap?.volumeAdjust ?? 0) #else 0 #end;
    final tween = FlxTween.num(startVolume, volume, Math.max(0, duration), {
      onComplete: function(_)
      {
        soundTweens.remove(tag);
        if (stopAfter) removeSound(tag);
      }
    }, function(value)
    {
      if (destroyed) return;
      if (sound != null) sound.volume = value;
      #if hxvlc
      else if (video.bitmap != null) video.bitmap.volumeAdjust = value;
      #end
    });
    soundTweens.set(tag, tween);
    return true;
  }

  public function pauseTimedEffects():Void
  {
    for (tween in soundTweens) pauseEventTween(tween);
    for (tween in overlayTweens) pauseEventTween(tween);
    for (tween in shaderTweens) pauseEventTween(tween);
    for (tween in visualTweens) pauseEventTween(tween);
    pauseEventTween(dialogueTween);
    for (timer in timers) pauseEventTimer(timer);
    pauseEventTimer(countdownTimer);
    pauseEventTimer(blackoutTimer);
  }

  public function resumeTimedEffects():Void
  {
    for (tween in pausedEventTweens)
      if (tween != null && !tween.finished) tween.active = true;
    for (timer in pausedEventTimers)
      if (timer != null && !timer.finished) timer.active = true;
    pausedEventTweens.resize(0);
    pausedEventTimers.resize(0);
  }

  function pauseEventTween(tween:Null<FlxTween>):Void
  {
    if (tween == null || tween.finished || !tween.active || pausedEventTweens.contains(tween)) return;
    tween.active = false;
    pausedEventTweens.push(tween);
  }

  function pauseEventTimer(timer:Null<FlxTimer>):Void
  {
    if (timer == null || timer.finished || !timer.active || pausedEventTimers.contains(timer)) return;
    timer.active = false;
    pausedEventTimers.push(timer);
  }

  public function destroy():Void
  {
    destroyed = true;
    dialogueTween?.cancel();
    dialogueTween = null;
    countdownTimer?.cancel();
    countdownTimer = null;
    blackoutTimer?.cancel();
    blackoutTimer = null;
    for (tag in sounds.keys().array()) removeSound(tag);
    for (tween in overlayTweens) tween?.cancel();
    overlayTweens.clear();
    for (overlay in overlays)
    {
      PlayState.instance?.remove(overlay, true);
      overlay.destroy();
    }
    overlays.clear();
    overlayAtlases.clear();
    for (tween in shaderTweens) tween?.cancel();
    shaderTweens.clear();
    shaderValues.clear();
    shaderPositions.clear();
    shaderColors.clear();
    for (tween in hudFadeTweens) tween?.cancel();
    hudFadeTweens.clear();
    hudFadeValues.clear();
    healthDrainAmount = 0;
    healthDrainDirection = -1;
    healthDrainCanDie = true;
    for (timer in timers) timer?.cancel();
    timers.resize(0);
    for (tween in visualTweens) tween?.cancel();
    visualTweens.resize(0);
    pausedEventTweens.resize(0);
    pausedEventTimers.resize(0);
    shaders.clear();
    preloaded.clear();
    chartEvents = [];
    nextPreloadEventIndex = 0;
    lastPreloadPosition = Math.NEGATIVE_INFINITY;
  }

  public function resetEffects():Void
  {
    final state = PlayState.instance;
    final oldMusicVolume = dialogueOriginalMusicVolume;
    final oldHudVisible = dialogueOriginalHudVisible;
    final resumeGameplay = dialoguePausedGameplay;
    destroy();
    if (state == null) return;

    if (oldMusicVolume != null && FlxG.sound.music != null) FlxG.sound.music.volume = oldMusicVolume;
    if (oldHudVisible != null) state.camHUD.visible = oldHudVisible;
    if (resumeGameplay)
    {
      FlxG.sound.music?.resume();
      state.vocals?.resume();
    }
    dialogueOriginalMusicVolume = null;
    dialogueOriginalHudVisible = null;
    dialoguePausedGameplay = false;

    if (state.currentConversation != null)
    {
      final conversation = state.currentConversation;
      ScriptEventDispatcher.callEvent(conversation, new ScriptEvent(DESTROY, false));
      if (state.currentConversation == conversation)
      {
        conversation.kill();
        state.remove(conversation);
        state.currentConversation = null;
        state.isInCutscene = false;
      }
    }

    state.camGame.stopFX();
    state.camHUD.stopFX();
    state.camCutscene.stopFX();
    state.playerStrumline.alpha = 1;
    state.opponentStrumline.alpha = 1;
    for (target in ['hud', 'healthbar', 'playericons', 'opponenticons', 'playernotes', 'opponentnotes', 'playerreceptors', 'opponentreceptors'])
      applyHudFadeValue(target, 1);
    state.cancelScrollSpeedTweens();
    state.playerStrumline.resetScrollSpeed();
    state.opponentStrumline.resetScrollSpeed();
  }

  static function resolveAsset(resource:String, fallback:String):Null<String>
  {
    if (assetFileExists(resource)) return resource;
    return assetFileExists(fallback) ? fallback : null;
  }

  static function resolveImageAsset(resource:String):Null<String>
  {
    if (resource == null || resource.trim() == '') return null;
    final normalized = resource.trim().replace('\\', '/');
    final candidates:Array<String> = [];
    if (normalized.toLowerCase().endsWith('.png')) addImageCandidate(candidates, normalized);
    else addImageCandidate(candidates, '${normalized}.png');

    var key = normalized;
    if (key.startsWith('assets/images/')) key = key.substr('assets/images/'.length);
    else if (key.startsWith('assets/shared/images/')) key = key.substr('assets/shared/images/'.length);
    else if (key.startsWith('assets/')) key = key.substr('assets/'.length);
    else if (key.startsWith('images/')) key = key.substr('images/'.length);
    if (key.toLowerCase().endsWith('.png')) key = key.substr(0, key.length - 4);
    addImageCandidate(candidates, Paths.image(key));
    addImageCandidate(candidates, 'assets/images/${key}.png');
    addImageCandidate(candidates, 'assets/shared/images/${key}.png');
    for (candidate in candidates)
      if (assetFileExists(candidate)) return candidate;
    return null;
  }

  static function addImageCandidate(candidates:Array<String>, candidate:String):Void
  {
    if (candidate != null && candidate != '' && !candidates.contains(candidate)) candidates.push(candidate);
  }

  static function resolveAudioAsset(resource:String):Null<String>
  {
    if (resource == null || resource.trim() == '') return null;
    final normalized = resource.trim().replace('\\', '/');
    final extension = Path.extension(normalized).toLowerCase();
    final suffixes = extension == '' ? ['.ogg', '.mp3', '.wav'] : [''];
    final bases:Array<String> = [normalized];
    if (normalized.startsWith('assets/') && !normalized.startsWith('assets/sounds/') && !normalized.startsWith('assets/music/'))
      bases.push('assets/sounds/' + normalized.substr('assets/'.length));
    else if (!normalized.startsWith('assets/') && !normalized.contains(':'))
      bases.push('assets/sounds/' + normalized);
    for (base in bases)
      for (suffix in suffixes)
      {
        final candidate = base + suffix;
        if (assetFileExists(candidate)) return candidate;
      }
    return null;
  }

  static function resolveMusicAsset(resource:String):Null<String>
  {
    if (resource == null || resource.trim() == '') return null;
    final normalized = resource.trim().replace('\\', '/');
    final extension = Path.extension(normalized).toLowerCase();
    final suffixes = extension == '' ? ['.ogg', '.mp3', '.wav'] : [''];
    final candidates:Array<String> = [];
    for (suffix in suffixes)
    {
      final direct = normalized + suffix;
      if (!candidates.contains(direct)) candidates.push(direct);
    }
    var key = normalized;
    if (key.startsWith('assets/music/')) key = key.substr('assets/music/'.length);
    else if (key.startsWith('music/')) key = key.substr('music/'.length);
    if (Path.extension(key) != '') key = Path.withoutExtension(key);
    for (candidate in [Paths.music(key), 'assets/music/${key}.ogg', 'assets/shared/music/${key}.ogg'])
      if (!candidates.contains(candidate)) candidates.push(candidate);
    for (candidate in candidates)
      if (assetFileExists(candidate)) return candidate;
    return null;
  }

  static function assetFileExists(path:String):Bool
  {
    if (path == null || path.trim() == '') return false;
    try
    {
      if (FileSystem.exists(path)) return !FileSystem.isDirectory(path);
    }
    catch (_) {}
    try
    {
      return Assets.exists(path);
    }
    catch (_) {}
    return false;
  }

  static function resolveVideoAsset(resource:String):Null<String>
  {
    if (resource == null || resource.trim() == '') return null;
    final normalized = resource.trim().replace('\\', '/');
    final extension = Path.extension(normalized).toLowerCase();
    final suffixes = extension == '' ? ['.mp4', '.mkv', '.webm', '.mov', '.avi'] : [''];
    final bases:Array<String> = [normalized];
    var videoKey = normalized;
    if (videoKey.startsWith('assets/videos/')) videoKey = videoKey.substr('assets/videos/'.length);
    if (videoKey.startsWith('videos/')) videoKey = videoKey.substr('videos/'.length);
    for (suffix in suffixes)
    {
      final direct = normalized + suffix;
      if (FileSystem.exists(direct) || Assets.exists(direct)) return direct;
      final libraryPath = Paths.videos(videoKey + suffix);
      if (FileSystem.exists(libraryPath) || Assets.exists(libraryPath)) return libraryPath;
    }
    return null;
  }

  static function isVideoOrCutscenePath(resource:String):Bool
  {
    if (resource == null) return false;
    final normalized = resource.toLowerCase().replace('\\', '/');
    final extension = Path.extension(normalized);
    return normalized.contains('/videos/') || normalized.contains('/cutscenes/') || ['mp4', 'webm', 'mov', 'mkv', 'avi'].contains(extension);
  }

  static function shaderClassName(value:String):String
  {
    if (value == null) return '';
    return Path.withoutExtension(Path.withoutDirectory(value));
  }

  public static function resolveCamera(name:String):Null<FlxCamera>
  {
    final state = PlayState.instance;
    return switch (name == null ? '' : name.toLowerCase())
    {
      case 'game': state?.camGame;
      case 'hud': state?.camHUD;
      case 'cutscene': state?.camCutscene;
      default: null;
    };
  }

  public function resolveTarget(type:String, name:String):Dynamic
  {
    final state = PlayState.instance;
    return switch (type == null ? '' : type.toLowerCase())
    {
      case 'character':
        switch (name == null ? '' : name.toLowerCase())
        {
          case 'player', 'boyfriend', 'bf': state?.currentStage?.getBoyfriend();
          case 'opponent', 'dad': state?.currentStage?.getDad();
          case 'girlfriend', 'gf': state?.currentStage?.getGirlfriend();
          default: state?.currentStage?.getCharacter(name);
        };
      case 'stageobject', 'stage object', 'object': state?.currentStage?.getNamedProp(name);
      case 'overlay': overlays.get(name);
      default: null;
    };
  }

  public static function parseColor(value:Dynamic, fallback:FlxColor):FlxColor
  {
    if (value == null) return fallback;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
    {
      var numeric:FlxColor = Std.int(value);
      if (numeric.alpha == 0) numeric.alpha = 255;
      return numeric;
    }
    var normalized = Std.string(value).trim();
    if (normalized == '') return fallback;
    if (!normalized.startsWith('#') && !normalized.toLowerCase().startsWith('0x'))
    {
      final decimal = Std.parseInt(normalized);
      if (decimal != null)
      {
        var parsedDecimal:FlxColor = decimal;
        if (parsedDecimal.alpha == 0) parsedDecimal.alpha = 255;
        return parsedDecimal;
      }
    }
    final parsed = FlxColor.fromString(normalized);
    return parsed ?? fallback;
  }

  static function colorChannels(color:FlxColor):Array<Float>
  {
    return [color.red / 255, color.green / 255, color.blue / 255, color.alpha / 255];
  }

  static function parseBlendMode(value:String):BlendMode
  {
    return switch (value == null ? '' : value.toLowerCase())
    {
      case 'add': BlendMode.ADD;
      case 'multiply': BlendMode.MULTIPLY;
      case 'screen': BlendMode.SCREEN;
      case 'overlay': BlendMode.OVERLAY;
      case 'darken': BlendMode.DARKEN;
      case 'lighten': BlendMode.LIGHTEN;
      case 'difference': BlendMode.DIFFERENCE;
      case 'subtract': BlendMode.SUBTRACT;
      default: BlendMode.NORMAL;
    };
  }

  public static function resolveEase(name:String):Float->Float
  {
    if (name == null || name == '' || name == 'linear') return FlxEase.linear;
    final ease:Dynamic = Reflect.field(FlxEase, name);
    return ease == null ? FlxEase.linear : cast ease;
  }

  public static function warn(message:String):Bool
  {
    trace(' WARNING '.warning() + ' LuaSlice song event: ${message}');
    return false;
  }
}
