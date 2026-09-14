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
    if (input == null || input.length == 0) return null;

    try
    {
      var buffer:Null<AudioBuffer> = AudioBuffer.fromBytes(input);
      if (buffer == null) return null;
      #if (cpp && !macro)
      if (buffer.data == null || buffer.data.length == 0 || buffer.channels <= 0 || buffer.sampleRate <= 0)
      {
        buffer.dispose();
        return null;
      }
      #end
      var openflSound:Null<OpenFLSound> = OpenFLSound.fromAudioBuffer(buffer);
      if (openflSound == null)
      {
        buffer.dispose();
        return null;
      }
      return FunkinSound.load(openflSound, 1.0, false, false, false, false, null, null, true);
    }
    catch (error:haxe.Exception)
    {
      trace('[SoundUtil] Could not decode imported audio: ${error.message}');
      return null;
    }
  }
}
