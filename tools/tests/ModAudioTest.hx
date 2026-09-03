import haxe.crypto.Crc32;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Writer;
import lime.app.Application;
import lime.app.Future;
import lime.media.AudioBuffer;
import luaslice.modding.ModAudio;
import polymod.fs.SysZipFileSystem;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;

class ModAudioTest
{
  static var checks:Int = 0;
  static var app:Application;
  static var mainThread:Thread;

  static function expect(value:Bool, label:String):Void
  {
    if (!value) throw 'FAILED: $label';
    checks++;
    Sys.println('PASS: $label');
  }

  static function wav():Bytes
  {
    var samples = 441;
    var output = new BytesOutput();
    output.bigEndian = false;
    output.writeString('RIFF');
    output.writeInt32(36 + samples * 2);
    output.writeString('WAVEfmt ');
    output.writeInt32(16);
    output.writeUInt16(1);
    output.writeUInt16(1);
    output.writeInt32(44100);
    output.writeInt32(88200);
    output.writeUInt16(2);
    output.writeUInt16(16);
    output.writeString('data');
    output.writeInt32(samples * 2);
    for (i in 0...samples) output.writeUInt16((i % 2) * 2000);
    return output.getBytes();
  }

  static function writeZip(path:String, contents:Map<String, Bytes>):Void
  {
    var entries = new List<Entry>();
    for (name => bytes in contents)
    {
      var entry:Entry = {fileName: name, fileSize: bytes.length, fileTime: Date.now(), compressed: false,
        dataSize: bytes.length, data: bytes, crc32: Crc32.make(bytes), extraFields: new List()};
      haxe.zip.Tools.compress(entry, 6);
      entries.add(entry);
    }
    var output = File.write(path, true);
    new Writer(output).write(entries);
    output.close();
  }

  static function settle(future:Future<AudioBuffer>, label:String):Void
  {
    var deadline = haxe.Timer.stamp() + 10;
    while (!future.isComplete && !future.isError && haxe.Timer.stamp() < deadline)
    {
      app.onUpdate.dispatch(1 / 60);
      Sys.sleep(0.005);
    }
    expect(future.isComplete || future.isError, label + ': Future settles');
  }

  static function valid(path:String, fs:AudioTestFileSystem, expected:AudioBuffer, label:String):Void
  {
    var completions = 0;
    var errors = 0;
    var callbackOnMain = false;
    var future = ModAudio.load(path, fs);
    future.onComplete(buffer -> {
      completions++;
      callbackOnMain = Thread.current() == mainThread;
    });
    future.onError(error -> errors++);
    settle(future, label);
    expect(future.isComplete && !future.isError, label + ': completes successfully (' + Std.string(future.error) + ')');
    expect(completions == 1 && errors == 0, label + ': exactly one success callback');
    expect(callbackOnMain, label + ': completion callback runs on main thread');
    expect(future.value.channels == expected.channels && future.value.sampleRate == expected.sampleRate,
      label + ': decoded audio properties preserved');
    expect(future.value.data.toBytes().compare(expected.data.toBytes()) == 0, label + ': decoded samples match original');
    #if lime_threads
    expect(fs.lastReadThread != mainThread, label + ': file read runs off main thread');
    #end
    future.value.dispose();
  }

  static function invalid(path:String, fs:AudioTestFileSystem, fragment:String, label:String):Void
  {
    var completions = 0;
    var errors = 0;
    var callbackOnMain = false;
    var future = ModAudio.load(path, fs);
    future.onComplete(buffer -> completions++);
    future.onError(error -> {
      errors++;
      callbackOnMain = Thread.current() == mainThread;
    });
    settle(future, label);
    expect(future.isError && !future.isComplete, label + ': rejects as an error');
    expect(completions == 0 && errors == 1, label + ': exactly one error callback');
    expect(callbackOnMain, label + ': error callback runs on main thread');
    expect(Std.string(future.error).indexOf('Could not load mod audio "' + path + '"') != -1,
      label + ': error identifies audio path');
    expect(Std.string(future.error).indexOf(fragment) != -1, label + ': error identifies cause');
  }

  static function main():Void
  {
    #if !lime_cffi
    throw 'Run this test with native Lime audio decoding (-D lime_cffi).';
    #end
    var args = Sys.args();
    if (args.length != 1) throw 'Pass an existing valid OGG file as the only argument.';
    var ogg = File.getBytes(args[0]);
    var pcm = wav();
    var expectedWav = AudioBuffer.fromBytes(pcm);
    var expectedOgg = AudioBuffer.fromBytes(ogg);
    expect(expectedWav != null && expectedWav.data != null && expectedWav.data.length == 882, 'Native WAV decoder available');
    expect(expectedOgg != null && expectedOgg.data != null && expectedOgg.data.length > 0, 'Native OGG decoder available');

    app = new Application();
    mainThread = Thread.current();
    var fixture = '.research/mod-audio-test/fixture-' + Std.string(Date.now().getTime()) + '-' + Std.random(1000000);
    if (FileSystem.exists(fixture)) throw 'Fixture already exists';
    var root = fixture + '/mods';
    var folder = root + '/folder-mod';
    var zip = root + '/zip-mod';
    FileSystem.createDirectory(folder + '/songs/test');
    var contents:Map<String, Bytes> = [
      'songs/test/Inst.wav' => pcm,
      'songs/test/Voices.ogg' => ogg,
      'songs/test/empty.ogg' => Bytes.alloc(0),
      'songs/test/corrupt.ogg' => Bytes.ofString('This file is not valid audio data.')
    ];
    for (name => data in contents) File.saveBytes(Path.join([folder, name]), data);
    writeZip(zip + '.zip', contents);
    polymod.Polymod.onError = error -> Sys.println('POLYMOD: ' + error.code + ': ' + error.message);
    var fs = new AudioTestFileSystem(root);

    for (location in [folder, zip])
    {
      var label = location == folder ? 'Folder' : 'Compressed ZIP';
      valid(location + '/songs/test/Inst.wav', fs, expectedWav, label + ' WAV');
      valid(location + '/songs/test/Voices.ogg', fs, expectedOgg, label + ' OGG');
      invalid(location + '/songs/test/empty.ogg', fs, 'empty', label + ' empty file');
      invalid(location + '/songs/test/corrupt.ogg', fs, 'decoded', label + ' corrupt file');
      invalid(location + '/songs/test/missing.ogg', fs, 'could not be read', label + ' missing file');
    }
    invalid(null, fs, 'path is missing', 'Null path');
    invalid('', fs, 'path is missing', 'Empty path');
    invalid('throw-read.ogg', fs, 'Isolated read failure', 'Thrown filesystem error');
    invalid('null-read.ogg', fs, 'could not be read', 'Null filesystem read');
    fs.closeFixtures();
    expectedWav.dispose();
    expectedOgg.dispose();
    Sys.println('PASS: ' + checks + ' real ModAudio / Lime decoder checks. Fixture: ' + fixture);
  }
}

private class AudioTestFileSystem extends SysZipFileSystem
{
  public var lastReadThread:Thread;

  public function new(root:String)
  {
    super({modRoot: root, autoScan: true});
  }

  override public function getFileBytes(path:String):Null<Bytes>
  {
    lastReadThread = Thread.current();
    if (path == 'throw-read.ogg') throw 'Isolated read failure';
    if (path == 'null-read.ogg') return null;
    return super.getFileBytes(path);
  }

  public function closeFixtures():Void
  {
    @:privateAccess for (parser in zipParsers) parser.fileHandle.close();
  }
}
