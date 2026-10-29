package funkin.play.notes.notekind;

import flixel.FlxSprite;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.play.character.BaseCharacter;
import funkin.play.notes.notekind.NoteKind.NoteKindParamType;

class PlayAnimationNoteKind extends NoteKind
{
  public function new()
  {
    super('play_animation', 'Play Animation', null, [
      {
        name: 'target',
        description: 'Character Target',
        type: NoteKindParamType.ENUM,
        data: {
          defaultValue: 'auto',
          options: [
            {text: 'Note owner (Auto)', value: 'auto'},
            {text: 'Player', value: 'player'},
            {text: 'Opponent', value: 'opponent'},
            {text: 'Girlfriend', value: 'girlfriend'}
          ]
        }
      },
      {
        name: 'animation',
        description: 'Animation Name',
        type: NoteKindParamType.STRING,
        data: {defaultValue: 'idle'}
      },
      {
        name: 'force',
        description: 'Force Animation',
        type: NoteKindParamType.BOOL,
        data: {defaultValue: true}
      }
    ], true);
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    if (event.eventCanceled || event.note == null) return;
    var state = PlayState.instance;
    var stage = state?.currentStage;
    if (stage == null) return;

    var targetName:String = StringTools.trim(Std.string(event.note.getParam('target') ?? 'auto'));
    var animationName:String = Std.string(event.note.getParam('animation') ?? 'idle');
    var forceValue:Dynamic = event.note.getParam('force');
    var force:Bool = forceValue == null;
    if (Std.isOfType(forceValue, Bool)) force = cast forceValue;
    else if (Std.isOfType(forceValue, Int) || Std.isOfType(forceValue, Float)) force = forceValue != 0;
    else if (Std.isOfType(forceValue, String))
    {
      var text:String = StringTools.trim(cast forceValue).toLowerCase();
      force = text == '1' || text == 'true';
    }
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

    if (target == null || !target.exists)
    {
      trace('[Play Animation note] Target "$targetName" is unavailable.');
      return;
    }

    if (Std.isOfType(target, BaseCharacter))
    {
      var character:BaseCharacter = cast target;
      if (character.animation?.getByName(animationName) == null)
      {
        var found:Bool = false;
        for (animation in character.getCharacterAnimations())
        {
          if ((animation.name == animationName || animation.prefix == animationName) && character.hasAnimation(animation.name))
          {
            animationName = animation.name;
            found = true;
            break;
          }
        }
        if (!found)
        {
          trace('[Play Animation note] Character "${character.characterId}" has no animation or prefix "$animationName".');
          return;
        }
      }
      var offsets = character.animationOffsets.get(animationName);
      if (offsets == null || offsets.length < 2) character.setAnimationOffsets(animationName, 0, 0);
      if (force) character.canPlayOtherAnims = true;
      character.playAnimation(animationName, force, force);
    }
    else
    {
      if (target.animation?.getByName(animationName) == null)
      {
        trace('[Play Animation note] Target "$targetName" has no animation "$animationName".');
        return;
      }
      target.animation.play(animationName, force);
    }
  }
}
