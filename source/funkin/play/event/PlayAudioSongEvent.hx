package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;

class PlayAudioSongEvent extends SongEvent
{
  public function new() super('PlayAudio', {processOldEvents: true});
  public override function getTitle():String return 'Play Audio';
  public override function handleEvent(data:SongEventData):Void
  {
    final runtime = PlayState.instance?.songEventRuntime;
    if (runtime == null) return;
    final action = data.getString('action') ?? 'play';
    final tag = data.getString('tag') ?? 'audio';
    final volume = data.getFloat('volume') ?? 1;
    final duration = data.getFloat('duration') ?? 0;
    switch (action)
    {
      case 'play':
        final folder = (data.getString('path') ?? 'assets/').trim();
        final file = (data.getString('file') ?? '').trim();
        final separator = folder.endsWith('/') || folder.endsWith('\\') || file == '' ? '' : '/';
        runtime.playSound(file == '' ? folder : '${folder}${separator}${file}', tag, volume, data.getBool('loop') ?? false, data.getFloat('fadeIn') ?? 0,
          data.getFloat('fadeOut') ?? 0);
      case 'resume':
        runtime.controlSound('resume', tag);
        if ((data.getFloat('fadeIn') ?? 0) > 0) runtime.tweenSound(tag, volume, data.getFloat('fadeIn') ?? 0, false);
      case 'volume':
        if (duration > 0) runtime.tweenSound(tag, volume, duration, false);
        else runtime.controlSound('volume', tag, volume);
      case 'pause': runtime.controlSound('pause', tag);
      case 'stop':
        if ((data.getFloat('fadeOut') ?? 0) > 0) runtime.tweenSound(tag, 0, data.getFloat('fadeOut') ?? 0, true);
        else if (!runtime.removeSound(tag)) LuaSliceSongEventRuntime.warn('Audio tag not found: ${tag}');
      default: LuaSliceSongEventRuntime.warn('Unknown Play Audio action: ${action}');
    }
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema([{
    name: 'action', title: 'Action', defaultValue: 'play', type: SongEventFieldType.ENUM,
    keys: ['Play Audio' => 'play', 'Resume Audio' => 'resume', 'Change Audio Volume' => 'volume', 'Pause Audio' => 'pause', 'Stop Audio' => 'stop']
  }, {
    name: 'path', title: 'Audio Folder Path', defaultValue: 'assets/', type: SongEventFieldType.STRING
  }, {
    name: 'file', title: 'Audio File Name', defaultValue: '', type: SongEventFieldType.STRING
  }, {
    name: 'tag', title: 'Audio Tag', defaultValue: 'audio', type: SongEventFieldType.STRING
  }, {
    name: 'settings', title: 'Audio Settings', type: SongEventFieldType.FRAME, collapsible: true, children: [{
      name: 'volume', title: 'Volume', defaultValue: 1.0, min: 0, max: 1, step: 0.05, type: SongEventFieldType.FLOAT
    }, {
      name: 'loop', title: 'Loop', defaultValue: false, type: SongEventFieldType.BOOL
    }, {
      name: 'fadeIn', title: 'Fade In', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    }, {
      name: 'fadeOut', title: 'Fade Out', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    }, {
      name: 'duration', title: 'Volume Change Duration', defaultValue: 0.0, min: 0, step: 0.1, type: SongEventFieldType.FLOAT, units: 'seconds'
    }]
  }]);
}
