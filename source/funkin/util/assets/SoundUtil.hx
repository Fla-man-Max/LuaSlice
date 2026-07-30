package funkin.util.assets;

import haxe.io.Bytes;
import openfl.media.Sound as OpenFLSound;
import funkin.audio.FunkinSound;
import lime.media.AudioBuffer;

@:nullSafety
class SoundUtil
{
  /**
   * Convert byte data into a playable sound.
   *
   * @param input The byte data.
   * @return The playable sound, or `null` if loading failed.
   */
  public static function buildSoundFromBytes(input:Null<Bytes>):Null<FunkinSound>
  {
    if (input == null) return null;

    try
    {
      var audioBuffer:Null<AudioBuffer> = AudioBuffer.fromBytes(input);
      if (audioBuffer == null || audioBuffer.data == null || audioBuffer.channels <= 0 || audioBuffer.sampleRate <= 0) return null;

      var openflSound:Null<OpenFLSound> = OpenFLSound.fromAudioBuffer(audioBuffer);
      if (openflSound == null) return null;
      return FunkinSound.load(openflSound, 1.0, false);
    }
    catch (error:Dynamic)
    {
      FlxG.log.error('Failed to decode audio bytes: ${error}');
      return null;
    }
  }

  public static function isMP3(input:Null<Bytes>):Bool
  {
    if (input == null || input.length < 3) return false;

    if (input.get(0) == 0x49 && input.get(1) == 0x44 && input.get(2) == 0x33) return true;
    if (input.length < 4) return false;

    var second:Int = input.get(1);
    var third:Int = input.get(2);
    var version:Int = (second >> 3) & 0x03;
    var layer:Int = (second >> 1) & 0x03;
    var bitrate:Int = (third >> 4) & 0x0F;

    return input.get(0) == 0xFF && (second & 0xE0) == 0xE0 && version != 1 && layer != 0 && bitrate != 0 && bitrate != 0x0F;
  }
}
