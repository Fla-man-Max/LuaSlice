package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.song.SongData.SongEventData;

class PlayCountdownSongEvent extends SongEvent
{
  public function new() super('PlayCountdown');
  public override function getTitle():String return 'Play Countdown';
  public override function handleEvent(data:SongEventData):Void
  {
    PlayState.instance?.songEventRuntime?.playCountdown();
  }
  public override function getEventSchema():SongEventSchema return new SongEventSchema();
}
