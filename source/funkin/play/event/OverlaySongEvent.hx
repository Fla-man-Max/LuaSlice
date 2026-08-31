package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class OverlaySongEvent extends SongEvent
{
  public function new() super('Overlay', {processOldEvents: true});
  public override function getTitle():String return 'Overlay';

  public override function handleEvent(data:SongEventData):Void
  {
    final runtime = PlayState.instance?.songEventRuntime;
    if (runtime == null) return;
    final tag = data.getString('tag') ?? 'overlay';
    switch (data.getString('action') ?? 'create')
    {
      case 'create':
        runtime.createOverlay(tag, data.getString('kind') ?? 'solid', data.getString('resource') ?? '', data.getDynamic('color') ?? '#000000',
          data.getDynamic('secondColor') ?? '#00000000', data.getFloat('opacity') ?? 1, data.getFloat('x') ?? 0, data.getFloat('y') ?? 0,
          data.getFloat('scale') ?? 1, data.getFloat('rotation') ?? 0, data.getString('blend') ?? 'normal', data.getString('camera') ?? 'hud',
          data.getFloat('duration') ?? 0, data.getString('atlasType') ?? 'sparrow', data.getString('prefix') ?? '');
      case 'fade': runtime.tweenOverlay(tag, data.getFloat('opacity') ?? 0, data.getFloat('duration') ?? 1, false);
      case 'remove': runtime.removeOverlay(tag, data.getFloat('duration') ?? 0);
      default: LuaSliceSongEventRuntime.warn('Unknown overlay action: ${data.getString('action')}');
    }
  }

  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'action', title: 'Action', defaultValue: 'create', type: SongEventFieldType.ENUM,
    keys: ['Create' => 'create', 'Fade' => 'fade', 'Remove' => 'remove']
  }, {
    name: 'tag', title: 'Overlay Tag', defaultValue: 'overlay', type: SongEventFieldType.STRING
  }, {
    name: 'kind', title: 'Overlay Type', defaultValue: 'solid', type: SongEventFieldType.ENUM,
    keys: ['Solid Color' => 'solid', 'Gradient' => 'gradient', 'Image' => 'image', 'Animated Image' => 'animated']
  }, {
    name: 'resource', title: 'Image or Atlas File Path', defaultValue: 'assets/', type: SongEventFieldType.STRING
  }, {
    name: 'atlasType', title: 'Atlas Type', defaultValue: 'sparrow', type: SongEventFieldType.ENUM,
    keys: ['Sparrow XML' => 'sparrow', 'Packer TXT' => 'packer']
  }, {
    name: 'prefix', title: 'Animation Prefix', defaultValue: '', type: SongEventFieldType.STRING
  }, {
      name: 'color', title: 'Color', defaultValue: '#000000', type: SongEventFieldType.COLOR
  }, {
      name: 'secondColor', title: 'Gradient End Color', defaultValue: '#00000000', type: SongEventFieldType.COLOR
  }, {
    name: 'opacity', title: 'Opacity', defaultValue: 1.0, min: 0, max: 1, step: 0.05, type: SongEventFieldType.FLOAT
  }, {
    name: 'x', title: 'X', defaultValue: 0.0, step: 1, type: SongEventFieldType.FLOAT
  }, {
    name: 'y', title: 'Y', defaultValue: 0.0, step: 1, type: SongEventFieldType.FLOAT
  }, {
    name: 'scale', title: 'Size', defaultValue: 1.0, min: 0, step: 0.05, type: SongEventFieldType.FLOAT
  }, {
    name: 'rotation', title: 'Rotation', defaultValue: 0.0, step: 1, type: SongEventFieldType.FLOAT
  }, {
    name: 'blend', title: 'Blend Mode', defaultValue: 'normal', type: SongEventFieldType.ENUM,
    keys: ['Normal' => 'normal', 'Add' => 'add', 'Multiply' => 'multiply', 'Screen' => 'screen', 'Overlay' => 'overlay', 'Darken' => 'darken',
      'Lighten' => 'lighten', 'Difference' => 'difference', 'Subtract' => 'subtract']
  }, {
    name: 'camera', title: 'Target Camera', defaultValue: 'hud', type: SongEventFieldType.ENUM,
    keys: ['Game' => 'game', 'HUD' => 'hud', 'Cutscene' => 'cutscene']
  }, {
    name: 'duration', title: 'Fade Duration', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }]);
}
