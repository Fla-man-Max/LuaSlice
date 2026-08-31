package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class PreloadResourceSongEvent extends SongEvent
{
  public function new()
  {
    super('PreloadResource', {processOldEvents: true});
  }

  public override function handleEvent(data:SongEventData):Void
  {
    PlayState.instance?.songEventRuntime?.preload(data.getString('type') ?? '', data.getString('resource') ?? '');
  }

  public override function getTitle():String
  {
    return 'Preload Resource';
  }

  public override function getEventSchema():SongEventSchema
  {
    return new SongEventSchema([{
      name: 'type',
      title: 'Resource Type',
      defaultValue: 'image',
      type: SongEventFieldType.ENUM,
      keys: ['Image' => 'image', 'Sound' => 'sound', 'Music' => 'music', 'Character' => 'character', 'Stage' => 'stage', 'Stage Object' => 'stageobject', 'Dialogue Data' => 'dialogue']
    }, {
      name: 'resource',
      title: 'Path or ID',
      defaultValue: 'assets/',
      type: SongEventFieldType.STRING
    }]);
  }
}


