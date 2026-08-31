package funkin.play.notes.notekind;

import flixel.FlxSprite;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.play.character.BaseCharacter;
import funkin.play.notes.notekind.NoteKind.NoteKindParamType;

class PlayAnimationNoteKind extends NoteKind
{
  public function new()
  {
    super('play_animation', 'Plays an animation when the note is hit.', null, [
      {
        name: 'target',
        description: 'player, opponent, girlfriend, or the name of a stage prop.',
        type: NoteKindParamType.STRING,
        data: {defaultValue: 'auto'}
      },
      {
        name: 'animation',
        description: 'Animation name to play.',
        type: NoteKindParamType.STRING,
        data: {defaultValue: 'idle'}
      },
      {
        name: 'force',
        description: 'Use 1 to restart and force the animation.',
        type: NoteKindParamType.INT,
        data: {min: 0, max: 1, step: 1, defaultValue: 1}
      }
    ], true);
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    var state = PlayState.instance;
    var stage = state?.currentStage;
    if (stage == null) return;

    var targetName:String = event.note.getParam('target') ?? 'auto';
    var animationName:String = event.note.getParam('animation') ?? 'idle';
    var forceValue:Null<Int> = event.note.getParam('force');
    var force:Bool = (forceValue ?? 1) != 0;
    var target:Null<FlxSprite> = null;

    switch (targetName.toLowerCase())
    {
      case 'auto':
        target = event.note.noteData.getMustHitNote() ? stage.getBoyfriend() : stage.getDad();
      case 'boyfriend' | 'bf' | 'player':
        target = stage.getBoyfriend();
      case 'dad' | 'opponent':
        target = stage.getDad();
      case 'girlfriend' | 'gf':
        target = stage.getGirlfriend();
      default:
        target = stage.getNamedProp(targetName);
    }

    if (target == null) return;

    if (Std.isOfType(target, BaseCharacter))
    {
      cast(target, BaseCharacter).playAnimation(animationName, force, force);
    }
    else
    {
      target.animation.play(animationName, force);
    }
  }
}
