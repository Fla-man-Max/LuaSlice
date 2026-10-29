import haxe.crypto.Crc32;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class PsychLuaFixtures
{
  static function chunk(output:BytesOutput, name:String, data:Bytes):Void
  {
    var checked = new BytesOutput();
    checked.writeString(name);
    checked.write(data);
    output.writeInt32(data.length);
    output.write(checked.getBytes());
    output.writeInt32(Crc32.make(checked.getBytes()));
  }

  static function atlas(root:String):Void
  {
    var pixels = Bytes.alloc(64 * 64 * 4);
    var colors = ['purple', 'blue', 'green', 'red'];
    var rgb = [0xAA1100, 0x11AA00, 0x0011AA, 0xAA00AA];
    var xml = '<TextureAtlas imagePath="atlas-hold-test.png">';
    for (direction in 0...4)
    {
      var y = direction * 12;
      for (rectangle in [{x: 0, w: 8, h: 8, color: rgb[direction]}, {x: 12, w: 4, h: 3, color: rgb[direction]},
        {x: 20, w: 6, h: 5, color: rgb[direction]}, {x: 30, w: 4, h: 3, color: 0x123456}])
        for (row in 0...rectangle.h)
          for (column in 0...rectangle.w)
          {
            var offset = ((y + row) * 64 + rectangle.x + column) * 4;
            pixels.set(offset, rectangle.color >> 16);
            pixels.set(offset + 1, rectangle.color >> 8);
            pixels.set(offset + 2, rectangle.color);
            pixels.set(offset + 3, 255);
          }
      xml += '<SubTexture name="${colors[direction]}0000" x="0" y="$y" width="8" height="8"/>';
      xml += '<SubTexture name="${colors[direction]} hold piece0010" x="30" y="$y" width="4" height="3" frameX="-2" frameY="-1" frameWidth="8" frameHeight="4"/>';
      xml += '<SubTexture name="${colors[direction]} hold piece0000" x="12" y="$y" width="4" height="3" frameX="-2" frameY="-1" frameWidth="8" frameHeight="4"/>';
      var endPrefix = direction == 0 ? 'pruple end hold' : colors[direction] + ' hold end';
      xml += '<SubTexture name="${endPrefix}0000" x="20" y="$y" width="6" height="5" frameX="-2" frameY="-1" frameWidth="10" frameHeight="6"/>';
    }
    var filtered = new BytesOutput();
    for (row in 0...64)
    {
      filtered.writeByte(0);
      filtered.writeBytes(pixels, row * 64 * 4, 64 * 4);
    }
    var png = new BytesOutput();
    png.bigEndian = true;
    png.write(Bytes.ofHex('89504E470D0A1A0A'));
    var header = new BytesOutput();
    header.bigEndian = true;
    header.writeInt32(64);
    header.writeInt32(64);
    for (value in [8, 6, 0, 0, 0]) header.writeByte(value);
    chunk(png, 'IHDR', header.getBytes());
    chunk(png, 'IDAT', haxe.zip.Compress.run(filtered.getBytes(), 6));
    chunk(png, 'IEND', Bytes.alloc(0));
    var images = Path.join([root, 'images']);
    FileSystem.createDirectory(images);
    File.saveBytes(Path.join([images, 'atlas-hold-test.png']), png.getBytes());
    File.saveContent(Path.join([images, 'atlas-hold-test.xml']), xml + '</TextureAtlas>');
    Sys.println('PSYCH_ATLAS_FIXTURE_CREATED');
  }

  static function verifySave(root:String, requestPath:String):Void
  {
    var request:Dynamic = haxe.Json.parse(File.getContent(requestPath));
    var name:String = request.name;
    var folder:String = request.path;
    if (name == null || folder == null || name.indexOf('..') != -1 || folder.indexOf('..') != -1 || Path.isAbsolute(folder))
      throw 'Invalid persistence fixture save identity';
    var disk:Dynamic = haxe.Unserializer.run(File.getContent(Path.join([root, folder, name + '.sol'])));
    if (disk.options == null || disk.options.downscroll != request.downscroll) throw 'Preference changed in memory but not on disk';
    File.saveContent(requestPath + '.verified', 'verified');
    Sys.println('SAVE_DISK_PERSISTENCE_VERIFIED');
  }

  static function main():Void
  {
    var args = Sys.args();
    switch (args[0])
    {
      case 'atlas': atlas(args[1]);
      case 'verify-save': verifySave(args[1], args[2]);
      default: throw 'Expected atlas or verify-save operation';
    }
  }
}
