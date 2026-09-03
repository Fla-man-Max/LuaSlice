package luaslice.modding;

import lime.app.Future;
import lime.media.AudioBuffer;
import polymod.fs.PolymodFileSystem.IFileSystem;

@:nullSafety
class ModAudio
{
  public static function load(path:String, fileSystem:IFileSystem):Future<AudioBuffer>
  {
    return new Future<AudioBuffer>(() -> {
      try
      {
        if (path == null || path == '') throw 'The audio file path is missing.';
        var bytes = fileSystem.getFileBytes(path);
        if (bytes == null) throw 'The audio file could not be read.';
        if (bytes.length == 0) throw 'The audio file is empty.';

        var buffer = AudioBuffer.fromBytes(bytes);
        if (buffer == null || buffer.data == null || buffer.data.length == 0) throw 'The audio file could not be decoded.';
        return buffer;
      }
      catch (error:Dynamic)
      {
        throw 'Could not load mod audio "$path": ${Std.string(error)}';
      }
    }, true);
  }
}
