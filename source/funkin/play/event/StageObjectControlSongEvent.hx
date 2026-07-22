package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class StageObjectControlSongEvent extends SongEvent
{
  public function new() super('StageObjectControl', {processOldEvents: true});
  public override function getTitle():String return 'Stage Object Control';
  public override function handleEvent(data:SongEventData):Void
  {
    final action = data.getString('action') ?? 'show';
    final text = action == 'color' ? (data.getString('color') ?? data.getString('text') ?? '#FFFFFF') : (data.getString('animation') ?? data.getString('text') ?? '');
    PlayState.instance?.songEventRuntime?.controlStageObject(data.getString('object') ?? '', action, data.getFloat('value') ?? 0,
      data.getFloat('value2') ?? 0, text, data.getFloat('duration') ?? 0, data.getString('ease') ?? 'linear');
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'object', title: 'Object Name', defaultValue: '', type: SongEventFieldType.STRING
  }, {
    name: 'action', title: 'Action', defaultValue: 'show', type: SongEventFieldType.ENUM,
    keys: ['Show' => 'show', 'Hide' => 'hide', 'Move' => 'move', 'Rotate' => 'rotate', 'Scale' => 'scale', 'Change Opacity' => 'opacity',
      'Change Color' => 'color', 'Play Animation' => 'animation', 'Change Scroll Factor' => 'scrollfactor', 'Change Layer' => 'layer']
  }, {
    name: 'value', title: 'Value / X', defaultValue: 0.0, step: 0.1, type: SongEventFieldType.FLOAT
  }, {
    name: 'value2', title: 'Second Value / Y', defaultValue: 0.0, step: 0.1, type: SongEventFieldType.FLOAT
  }, {
    name: 'color', title: 'Color', defaultValue: '#FFFFFF', type: SongEventFieldType.COLOR
  }, {
    name: 'animation', title: 'Animation', defaultValue: 'idle', type: SongEventFieldType.STRING
  }, {
    name: 'duration', title: 'Duration', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'ease', title: 'Easing', defaultValue: 'linear', type: SongEventFieldType.ENUM,
    keys: ['Linear' => 'linear', 'Sine In' => 'sineIn', 'Sine Out' => 'sineOut', 'Quad In' => 'quadIn', 'Quad Out' => 'quadOut']
  }]);
}
