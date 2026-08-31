package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class HealthDrainSongEvent extends SongEvent
{
  public function new() super('HealthDrain', {processOldEvents: true});
  public override function getTitle():String return 'Health Drain';

  public override function handleEvent(data:SongEventData):Void
  {
    PlayState.instance?.songEventRuntime?.setHealthDrain(data.getString('target') ?? 'player', data.getFloat('amount') ?? 0.1,
      data.getBool('canDie') ?? true, data.getBool('changeScore') ?? false, data.getInt('scoreChange') ?? 0);
  }

  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'target', title: 'Drain From', defaultValue: 'player', type: SongEventFieldType.ENUM,
    keys: ['Player' => 'player', 'Opponent' => 'opponent']
  }, {
    name: 'amount', title: 'Drain Per Second', defaultValue: 0.1, min: 0, max: 2, step: 0.05, type: SongEventFieldType.FLOAT
  }, {
    name: 'canDie', title: 'Die?', defaultValue: true, type: SongEventFieldType.BOOL
  }, {
    name: 'changeScore', title: 'Change Score', defaultValue: false, type: SongEventFieldType.BOOL
  }, {
    name: 'scoreChange', title: 'Score Amount', defaultValue: -10, step: 10, type: SongEventFieldType.INTEGER
  }]);
}


