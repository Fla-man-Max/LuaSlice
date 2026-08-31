package funkin.play.event;

import flixel.util.FlxAxes;
import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class CameraShakeSongEvent extends SongEvent
{
  public function new() super('CameraShake', {processOldEvents: true});
  public override function getTitle():String return 'Camera Shake';
  public override function handleEvent(data:SongEventData):Void
  {
    final camera = LuaSliceSongEventRuntime.resolveCamera(data.getString('camera') ?? 'game');
    if (camera == null)
    {
      LuaSliceSongEventRuntime.warn('Camera not found: ${data.getString('camera')}');
      return;
    }
    final horizontal = data.getFloat('horizontal') ?? 1;
    final vertical = data.getFloat('vertical') ?? 1;
    final axes = horizontal > 0 && vertical > 0 ? FlxAxes.XY : (horizontal > 0 ? FlxAxes.X : FlxAxes.Y);
    camera.shake((data.getFloat('intensity') ?? 0.02) * Math.max(horizontal, vertical), data.getFloat('duration') ?? 0.5, null, true, axes);
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'intensity', title: 'Intensity', defaultValue: 0.02, min: 0, step: 0.005, type: SongEventFieldType.FLOAT
  }, {
    name: 'duration', title: 'Duration', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'camera', title: 'Target Camera', defaultValue: 'game', type: SongEventFieldType.ENUM,
    keys: ['Game' => 'game', 'HUD' => 'hud', 'Cutscene' => 'cutscene']
  }, {
    name: 'horizontal', title: 'Horizontal Strength', defaultValue: 1.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT
  }, {
    name: 'vertical', title: 'Vertical Strength', defaultValue: 1.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT
  }]);
}


