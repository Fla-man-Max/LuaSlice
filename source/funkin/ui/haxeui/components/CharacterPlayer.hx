package funkin.ui.haxeui.components;

import animate.internal.Timeline;
import flixel.FlxG;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.SongTimeScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.play.character.BaseCharacter;
import funkin.data.character.CharacterData.CharacterDataParser;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.events.AnimationEvent;
import haxe.ui.geom.Size;
import haxe.ui.layouts.DefaultLayout;

typedef AnimationInfo =
{
  var name:String;
  var prefix:String;
  var frameRate:Null<Int>; // default 30
  var looped:Null<Bool>; // default true
  var flipX:Null<Bool>; // default false
  var flipY:Null<Bool>; // default false
}

/**
 * A variant of SparrowPlayer which loads a BaseCharacter instead.
 * This allows it to play appropriate animations based on song events.
 */
@:composite(Layout)
class CharacterPlayer extends Box
{
  public var character:Null<BaseCharacter>;
  public var artworkOffsetX:Float = 0;
  public var artworkOffsetY:Float = 0;
  var artworkBoundsCacheKey:String = '';
  var animationArtworkBounds:Map<String, Array<Float>> = new Map<String, Array<Float>>();
  var referenceArtworkBounds:Null<Array<Float>> = null;
  var previewArtworkBounds:Null<Array<Float>> = null;
  var measuringArtworkBounds:Bool = false;

  public function setArtworkOffset(x:Float, y:Float):Void
  {
    if (artworkOffsetX == x && artworkOffsetY == y) return;
    artworkOffsetX = x;
    artworkOffsetY = y;
    invalidateComponentLayout();
  }

  public function getArtworkBounds():Array<Float>
  {
    if (character == null) return [0, 0, 0, 0];

    positionCharacter();
    final camera = character.camera ?? FlxG.camera;
    final matrix = new FlxMatrix();
    var visibleBounds:FlxRect;

    if (character.isAnimate && character.timeline != null)
    {
      @:privateAccess final timelineBounds:FlxRect = character.timeline._bounds;
      visibleBounds = character.timeline.getBounds(character.animation.frameIndex, false, null, null, true, true);
      matrix.identity();
      matrix.translate(-timelineBounds.x, -timelineBounds.y);
      @:privateAccess character.prepareAnimateMatrix(matrix, camera, timelineBounds);
      Timeline.applyMatrixToRect(visibleBounds, matrix);
    }
    else
    {
      final frame = character.frame;
      if (frame == null) return [0, 0, 0, 0];

      final rotated:Bool = frame.angle == FlxFrameAngle.ANGLE_90 || frame.angle == FlxFrameAngle.ANGLE_NEG_90;
      final frameWidth:Float = rotated ? frame.frame.height : frame.frame.width;
      final frameHeight:Float = rotated ? frame.frame.width : frame.frame.height;
      visibleBounds = FlxRect.get(0, 0, frameWidth, frameHeight);
      @:privateAccess frame.prepareMatrix(matrix, FlxFrameAngle.ANGLE_0, character.checkFlipX(), character.checkFlipY());
      @:privateAccess character.prepareDrawMatrix(matrix, camera);
      Timeline.applyMatrixToRect(visibleBounds, matrix);
    }

    final bounds:Array<Float> = [
      visibleBounds.x - cachedScreenX - artworkOffsetX,
      visibleBounds.y - cachedScreenY - artworkOffsetY,
      visibleBounds.width,
      visibleBounds.height
    ];
    visibleBounds.put();
    return bounds;
  }

  public function getAnimationArtworkBounds(?name:String):Array<Float>
  {
    ensureArtworkBoundsCacheState();
    final animationName:String = name ?? character?.animation.name ?? '';
    final bounds:Array<Float> = measureAnimationArtworkBounds(animationName);
    mergePreviewArtworkBounds(bounds);
    return bounds;
  }

  public function getReferenceArtworkBounds():Array<Float>
  {
    ensureArtworkBoundsCacheState();
    if (referenceArtworkBounds != null) return referenceArtworkBounds;

    if (character?.animation.exists('idle'))
    {
      referenceArtworkBounds = measureAnimationArtworkBounds('idle');
    }
    else
    {
      final danceLeft:Null<Array<Float>> = character?.animation.exists('danceLeft') ? measureAnimationArtworkBounds('danceLeft') : null;
      final danceRight:Null<Array<Float>> = character?.animation.exists('danceRight') ? measureAnimationArtworkBounds('danceRight') : null;
      if (danceLeft != null && danceRight != null)
      {
        referenceArtworkBounds = [
          Math.min(danceLeft[0], danceRight[0]),
          Math.min(danceLeft[1], danceRight[1]),
          Math.max(danceLeft[2], danceRight[2]),
          Math.max(danceLeft[3], danceRight[3])
        ];
      }
      else
      {
        referenceArtworkBounds = danceLeft ?? danceRight ?? getArtworkBoundsAsEdges();
      }
    }
    mergePreviewArtworkBounds(referenceArtworkBounds);
    return referenceArtworkBounds;
  }

  public function getPreviewArtworkBounds():Array<Float>
  {
    getReferenceArtworkBounds();
    getAnimationArtworkBounds();
    return previewArtworkBounds ?? getArtworkBoundsAsEdges();
  }

  function mergePreviewArtworkBounds(bounds:Array<Float>):Void
  {
    if (previewArtworkBounds == null)
    {
      previewArtworkBounds = bounds.copy();
      return;
    }

    previewArtworkBounds[0] = Math.min(previewArtworkBounds[0], bounds[0]);
    previewArtworkBounds[1] = Math.min(previewArtworkBounds[1], bounds[1]);
    previewArtworkBounds[2] = Math.max(previewArtworkBounds[2], bounds[2]);
    previewArtworkBounds[3] = Math.max(previewArtworkBounds[3], bounds[3]);
  }

  function getArtworkBoundsAsEdges():Array<Float>
  {
    final bounds:Array<Float> = getArtworkBounds();
    return [bounds[0], bounds[1], bounds[0] + bounds[2], bounds[1] + bounds[3]];
  }

  function invalidateArtworkBounds():Void
  {
    artworkBoundsCacheKey = '';
    animationArtworkBounds.clear();
    referenceArtworkBounds = null;
    previewArtworkBounds = null;
  }

  function ensureArtworkBoundsCacheState():Void
  {
    if (character == null) return;

    final frameCount:Int = character.frames?.frames?.length ?? 0;
    final cacheKey:String = '${character.characterId}:$frameCount:${character.scale.x}:${character.scale.y}:${character.flipX}:${character.flipY}';
    if (artworkBoundsCacheKey == cacheKey) return;

    invalidateArtworkBounds();
    artworkBoundsCacheKey = cacheKey;
  }

  @:access(funkin.play.stage.Bopper)
  function measureAnimationArtworkBounds(animationName:String):Array<Float>
  {
    ensureArtworkBoundsCacheState();
    if (character == null || animationName == '') return getArtworkBoundsAsEdges();

    final cachedBounds:Null<Array<Float>> = animationArtworkBounds.get(animationName);
    if (cachedBounds != null) return cachedBounds;

    final animation = character.animation.getByName(animationName);
    if (animation == null || animation.numFrames <= 0) return getArtworkBoundsAsEdges();

    final currentName:Null<String> = character.animation.name;
    final currentFrame:Int = character.animation.curAnim?.curFrame ?? 0;
    final currentPaused:Bool = character.animation.paused;
    final currentFinished:Bool = character.animation.finished;
    final currentOffsets:Array<Float> = character.animOffsets.copy();
    measuringArtworkBounds = true;
    final offsets:Null<Array<Float>> = character.animationOffsets.get(animationName);
    character.animOffsets = offsets == null ? [0, 0] : offsets;
    character.animation.play(animationName, true, false, 0);
    var bounds:Null<Array<Float>> = null;

    for (frame in 0...animation.numFrames)
    {
      animation.curFrame = frame;
      final frameBounds:Array<Float> = getArtworkBoundsAsEdges();
      if (frameBounds[2] > frameBounds[0] && frameBounds[3] > frameBounds[1])
      {
        if (bounds == null)
        {
          bounds = frameBounds;
        }
        else
        {
          bounds[0] = Math.min(bounds[0], frameBounds[0]);
          bounds[1] = Math.min(bounds[1], frameBounds[1]);
          bounds[2] = Math.max(bounds[2], frameBounds[2]);
          bounds[3] = Math.max(bounds[3], frameBounds[3]);
        }
      }
    }

    if (currentName != null && character.animation.exists(currentName))
    {
      character.animation.play(currentName, true, false, currentFrame);
    }
    character.animOffsets = currentOffsets;
    character.animation.paused = currentPaused;
    character.animation.finished = currentFinished;
    measuringArtworkBounds = false;

    final measuredBounds:Array<Float> = bounds ?? getArtworkBoundsAsEdges();
    animationArtworkBounds.set(animationName, measuredBounds);
    return measuredBounds;
  }

  public function new(defaultToBf:Bool = true)
  {
    super();
    // _overrideSkipTransformChildren = false;

    if (defaultToBf)
    {
      loadCharacter('bf');
    }
  }

  public var charId(get, set):String;

  function get_charId():String
  {
    return character?.characterId ?? '';
  }

  function set_charId(value:String):String
  {
    loadCharacter(value);
    return value;
  }

  public var charName(get, never):String;

  function get_charName():String
  {
    return character?.characterName ?? "Unknown";
  }

  // possible haxeui bug: if listener is added after event is dispatched, event is "lost"... is it smart to "collect and redispatch"? Not sure
  var _redispatchLoaded:Bool = false;
  // possible haxeui bug: if listener is added after event is dispatched, event is "lost"... is it smart to "collect and redispatch"? Not sure
  var _redispatchStart:Bool = false;
  var _characterLoaded:Bool = false;

  /**
   * Loads a character by ID.
   * @param id The ID of the character to load.
   */
  @:access(funkin.play.character.BaseCharacter)
  public function loadCharacter(id:String):Void
  {
    if (id == null) return;

    invalidateArtworkBounds();

    if (character != null)
    {
      remove(character);
      character.destroy();
      character = null;
    }

    // Prevent script issues by fetching with debug=true.
    var newCharacter:BaseCharacter = CharacterDataParser.fetchCharacter(id, true);
    if (newCharacter == null)
    {
      character = null;
      return; // Fail if character doesn't exist.
    }

    // Assign character.
    character = newCharacter;

    // Set character properties.
    if (characterType != null) character.characterType = characterType;
    if (flip) character.flipX = !character.flipX;
    if (targetScale != 1.0) character.setScale(targetScale);

    if (character._data.isPixel)
    {
      character.scale.x *= Constants.PIXEL_ART_SCALE;
      character.scale.y *= Constants.PIXEL_ART_SCALE;
    }

    character.animation.onFrameChange.add(onFrame);
    character.animation.onFinish.add(onFinish);
    add(character);

    invalidateArtworkBounds();

    invalidateComponentLayout();

    if (hasEvent(AnimationEvent.LOADED))
    {
      dispatch(new AnimationEvent(AnimationEvent.LOADED));
    }
    else
    {
      _redispatchLoaded = true;
    }
  }

  /**
   * The character type (such as BF, Dad, GF, etc).
   */
  public var characterType(default, set):CharacterType;

  function set_characterType(value:CharacterType):CharacterType
  {
    if (character != null) character.characterType = value;
    return characterType = value;
  }

  public var flip(default, set):Bool;

  function set_flip(value:Bool):Bool
  {
    if (value == flip) return value;

    if (character != null)
    {
      character.flipX = !character.flipX;
      invalidateArtworkBounds();
    }

    return flip = value;
  }

  public var targetScale(default, set):Float = 1.0;

  function set_targetScale(value:Float):Float
  {
    if (value == targetScale) return value;

    if (character != null)
    {
      character.setScale(value);
      invalidateArtworkBounds();
    }

    return targetScale = value;
  }

  function onFrame(name:String, frameNumber:Int, frameIndex:Int):Void
  {
    if (measuringArtworkBounds) return;
    dispatch(new AnimationEvent(AnimationEvent.FRAME));
  }

  function onFinish(name:String):Void
  {
    if (measuringArtworkBounds) return;
    dispatch(new AnimationEvent(AnimationEvent.END));
  }

  public function playAnimManually(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
  {
    if (character != null) character.playAnimation(name, restart, ignoreOther, reversed);
  }

  override function repositionChildren():Void
  {
    super.repositionChildren();

    positionCharacter();
  }

  function positionCharacter():Void
  {
    if (character == null) return;
    character.x = this.cachedScreenX + artworkOffsetX + (-character.globalOffsets[0] * character.scale.x);
    character.y = this.cachedScreenY + artworkOffsetY + (-character.globalOffsets[1] * character.scale.y);
  }

  /**
   * Called when an update event is hit in the song.
   * Used to play character animations.
   * @param event The event.
   */
  public function onUpdate(event:UpdateScriptEvent):Void
  {
    if (character != null) character.onUpdate(event);
  }

  /**
   * Called when an beat is hit in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onBeatHit(event:SongTimeScriptEvent):Void
  {
    if (character != null) character.onBeatHit(event);
  }

  /**
   * Called when a step is hit in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onStepHit(event:SongTimeScriptEvent):Void
  {
    if (character != null) character.onStepHit(event);
  }

  public function onNoteIncoming(event:NoteScriptEvent):Void
  {
    if (character != null) character.onNoteIncoming(event);
  }

  /**
   * Called when a note is hit in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    if (character != null)
    {
      character.onNoteHit(event);

      if ((event.note.noteData.getMustHitNote() && characterType == BF)
        || (!event.note.noteData.getMustHitNote() && characterType == DAD)) character.holdTimer = -event.note.noteData?.length / 1000;
      // At least i tried yaknow?
    }
  }

  /**
   * Called when a note is missed in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onNoteMiss(event:NoteScriptEvent):Void
  {
    if (character != null) character.onNoteMiss(event);
  }

  /**
   * Called when a hold note is dropped in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void
  {
    if (character != null) character.onNoteHoldDrop(event);
  }

  /**
   * Called when a key is pressed but no note is hit in the song
   * Used to play character animations.
   * @param event The event.
   */
  public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void
  {
    if (character != null) character.onNoteGhostMiss(event);
  }
}

@:access(funkin.ui.haxeui.components.CharacterPlayer)
@:access(funkin.play.character.BaseCharacter)
private class Layout extends DefaultLayout
{
  public override function resizeChildren():Void
  {
    super.resizeChildren();

    var player:CharacterPlayer = cast(_component, CharacterPlayer);
    var character:BaseCharacter = player.character;
    if (character == null)
    {
      return super.resizeChildren();
    }

    character.cornerPosition.set(0, 0);
    player.positionCharacter();
  }

  public override function calcAutoSize(exclusions:Array<Component> = null):Size
  {
    var player:CharacterPlayer = cast(_component, CharacterPlayer);
    var character:BaseCharacter = player.character;
    if (character == null)
    {
      return super.calcAutoSize(exclusions);
    }
    var size:Size = new Size();

    final charSceenBounds = character.getScreenBounds();
    size.width = charSceenBounds.width + paddingLeft + paddingRight;
    size.height = charSceenBounds.height + paddingTop + paddingBottom;

    return size;
  }
}
