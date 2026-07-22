package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class BlackoutSongEvent extends SongEvent
{
  public function new() super('Blackout', {processOldEvents: true});
  public override function getTitle():String return 'Blackout';
  public override function handleEvent(data:SongEventData):Void PlayState.instance?.songEventRuntime?.blackout(data.getFloat('fadeIn') ?? 0.5,
    data.getFloat('hold') ?? 1, data.getFloat('fadeOut') ?? 0.5, data.getString('camera') ?? 'hud', data.getBool('keepHud') ?? false,
    data.getBool('instant') ?? false, data.getDynamic('color') ?? '#000000');
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'color', title: 'Color', defaultValue: '#000000', type: SongEventFieldType.COLOR
  }, {
    name: 'fadeIn', title: 'Fade In', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'hold', title: 'Hold', defaultValue: 1.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'fadeOut', title: 'Fade Out', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'camera', title: 'Target Camera', defaultValue: 'hud', type: SongEventFieldType.ENUM,
    keys: ['Game' => 'game', 'HUD' => 'hud', 'Cutscene' => 'cutscene']
  }, {
    name: 'keepHud', title: 'Keep HUD Visible', defaultValue: false, type: SongEventFieldType.BOOL
  }, {
    name: 'instant', title: 'Instant', defaultValue: false, type: SongEventFieldType.BOOL
  }]);
}
