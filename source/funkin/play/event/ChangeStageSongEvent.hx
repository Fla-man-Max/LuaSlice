package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;
import funkin.data.stage.StageRegistry;

class ChangeStageSongEvent extends SongEvent
{
  public function new()
  {
    super('ChangeStage', {
      processOldEvents: true
    });
  }

  public override function handleEvent(data:SongEventData):Void
  {
    final stageId:String = data.getString('stage') ?? '';
    if (data.getBool('preload') ?? false) PlayState.instance?.songEventRuntime?.preload('stage', stageId);
    if (PlayState.instance == null || !PlayState.instance.changeStage(stageId))
    {
      trace(' WARNING '.warning() + ' ChangeStageSongEvent: Could not load stage "${stageId}".');
    }
  }

  public override function getTitle():String
  {
    return 'Change Stage';
  }

  public override function getEventSchema():SongEventSchema
  {
    final stages:Map<String, Dynamic> = [];
    for (stageId in StageRegistry.instance.listEntryIds())
      stages.set(stageId, stageId);

    return new SongEventSchema([{
      name: 'stage',
      title: 'Stage',
      defaultValue: Constants.DEFAULT_STAGE,
      type: SongEventFieldType.ENUM,
      keys: stages,
    }, {
      name: 'preload',
      title: 'Preload',
      defaultValue: false,
      type: SongEventFieldType.BOOL,
    }]);
  }
}
