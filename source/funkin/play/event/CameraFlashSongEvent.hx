package funkin.play.event;

import flixel.util.FlxColor;
import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class CameraFlashSongEvent extends SongEvent
{
  public function new() super('CameraFlash', {processOldEvents: true});
  public override function getTitle():String return 'Camera Flash';
  public override function handleEvent(data:SongEventData):Void
  {
    final camera = LuaSliceSongEventRuntime.resolveCamera(data.getString('camera') ?? 'game');
    if (camera == null)
    {
      LuaSliceSongEventRuntime.warn('Camera not found: ${data.getString('camera')}');
      return;
    }
    var color = LuaSliceSongEventRuntime.parseColor(data.getString('color') ?? '#FFFFFF', FlxColor.WHITE);
    color.alphaFloat = data.getFloat('opacity') ?? 1;
    camera.flash(color, data.getFloat('duration') ?? 0.5, null, true);
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'color', title: 'Color', defaultValue: '#FFFFFF', type: SongEventFieldType.COLOR
  }, {
    name: 'duration', title: 'Duration', defaultValue: 0.5, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
  }, {
    name: 'camera', title: 'Target Camera', defaultValue: 'game', type: SongEventFieldType.ENUM,
    keys: ['Game' => 'game', 'HUD' => 'hud', 'Cutscene' => 'cutscene']
  }, {
    name: 'opacity', title: 'Starting Opacity', defaultValue: 1.0, min: 0, max: 1, step: 0.05, type: SongEventFieldType.FLOAT
  }]);
}
