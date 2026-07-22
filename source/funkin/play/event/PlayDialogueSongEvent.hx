package funkin.play.event;

import funkin.data.dialogue.ConversationRegistry;
import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class PlayDialogueSongEvent extends SongEvent
{
  public function new() super('PlayDialogue', {processOldEvents: true});
  public override function getTitle():String return 'Play Dialogue';

  public override function handleEvent(data:SongEventData):Void
  {
    PlayState.instance?.songEventRuntime?.showDialogue(data.getString('conversation') ?? '', data.getFloat('fadeOut') ?? 0.5,
      data.getFloat('volume') ?? 0.2, data.getFloat('fadeIn') ?? 0.5, true, data.getBool('keepHud') ?? false);
  }

  public override function getEventSchema():SongEventSchema
  {
    final conversations:Map<String, Dynamic> = [];
    final ids = ConversationRegistry.instance.listEntryIds();
    ids.sort(function(a, b) return Reflect.compare(a, b));
    for (id in ids) conversations.set(id, id);
    final defaultConversation = ids.length > 0 ? ids[0] : '';

    return new SongEventSchema([{
      name: 'conversation', title: 'Conversation', defaultValue: defaultConversation, type: SongEventFieldType.ENUM, keys: conversations
    }, {
      name: 'fadeOut', title: 'Music Fade Out', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    }, {
      name: 'volume', title: 'Music Volume During Dialogue', defaultValue: 0.2, min: 0, max: 1, step: 0.05, type: SongEventFieldType.FLOAT
    }, {
      name: 'fadeIn', title: 'Music Fade Back In', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    }, {
      name: 'keepHud', title: 'Keep HUD Visible', defaultValue: false, type: SongEventFieldType.BOOL
    }]);
  }
}
