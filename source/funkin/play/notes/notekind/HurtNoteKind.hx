package funkin.play.notes.notekind;

import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.play.notes.notekind.NoteKind.NoteKindParamType;

class HurtNoteKind extends NoteKind
{
  static final DEFAULT_DAMAGE:Float = 0.3;

  public function new()
  {
    super('hurt', 'Damages the player when hit.', null, [
      {
        name: 'damage',
        description: 'Health removed when the note is hit.',
        type: NoteKindParamType.FLOAT,
        data: {min: 0.0, max: 2.0, step: 0.05, precision: 2, defaultValue: DEFAULT_DAMAGE}
      }
    ]);
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    if (!event.note.noteData.getMustHitNote()) return;

    var damage:Null<Float> = event.note.getParam('damage');
    event.healthChange = -Math.abs(damage ?? DEFAULT_DAMAGE);
    event.doesNotesplash = false;
  }
}
