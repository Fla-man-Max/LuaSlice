package funkin.play.notes.notekind;

import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;

class DeathNoteKind extends NoteKind
{
  public function new()
  {
    super('death', 'Immediately defeats the player when hit.');
  }

  override public function onNoteHit(event:HitNoteScriptEvent):Void
  {
    if (!event.note.noteData.getMustHitNote()) return;

    event.healthChange = -Constants.HEALTH_MAX;
    event.doesNotesplash = false;
  }
}
