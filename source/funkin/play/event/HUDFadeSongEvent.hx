package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;
import funkin.Conductor;

class HUDFadeSongEvent extends SongEvent
{
  public function new() super('HUDFade', {processOldEvents: true});
  public override function getTitle():String return 'HUD Fade';
  public override function handleEvent(data:SongEventData):Void
  {
    final durationBeats = data.getFloat('duration') ?? 1;
    final durationSeconds = Conductor.instance.beatLengthMs * durationBeats / 1000;
    var target = data.getString('target') ?? 'hud';
    if (target == 'receptors')
    {
      target = switch (data.getString('strumlineTarget') ?? 'both')
      {
        case 'player': 'playerreceptors';
        case 'opponent': 'opponentreceptors';
        default: 'receptors';
      };
    }
    else if (target == 'notes' || target == 'icons')
    {
      target = switch (data.getString('sideTarget') ?? 'both')
      {
        case 'player': 'player${target}';
        case 'opponent': 'opponent${target}';
        default: target;
      };
    }
    PlayState.instance?.songEventRuntime?.fadeHud(target, data.getFloat('opacity') ?? 1, durationSeconds, data.getString('ease') ?? 'linear');
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'target', title: 'HUD Target', defaultValue: 'hud', type: SongEventFieldType.ENUM,
    keys: ['Entire HUD' => 'hud', 'Health Bar' => 'healthbar', 'Icons' => 'icons', 'Notes' => 'notes', 'Strumline' => 'receptors']
  }, {
    name: 'strumlineTarget', title: 'Strumline Target', defaultValue: 'both', type: SongEventFieldType.ENUM,
    keys: ['Both' => 'both', 'Player' => 'player', 'Opponent' => 'opponent']
  }, {
    name: 'sideTarget', title: 'Side', defaultValue: 'both', type: SongEventFieldType.ENUM,
    keys: ['Both' => 'both', 'Player' => 'player', 'Opponent' => 'opponent']
  }, {
    name: 'opacity', title: 'Opacity', defaultValue: 1.0, min: 0, max: 1, step: 0.05, type: SongEventFieldType.FLOAT
  }, {
    name: 'duration', title: 'Fade Duration', defaultValue: 1.0, min: 0, step: 0.25, type: SongEventFieldType.FLOAT, units: 'beats'
  }, {
    name: 'ease', title: 'Easing', defaultValue: 'linear', type: SongEventFieldType.ENUM,
    keys: ['Linear' => 'linear', 'Sine In' => 'sineIn', 'Sine Out' => 'sineOut', 'Quad In' => 'quadIn', 'Quad Out' => 'quadOut']
  }]);
}
