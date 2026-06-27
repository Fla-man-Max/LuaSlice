package source; // Yeah, I know...

import sys.FileSystem;
import sys.io.File;

using StringTools;
using tools.AnsiUtil;

/**
 * A script which executes after the game is built.
 */
class Postbuild
{
  static inline final BUILD_TIME_FILE:String = '.build_time';

  static function main():Void
  {
    patchAndroidManifestOrientation();
    patchAndroidActivityOrientation();
    printBuildTime();
  }

  static function patchAndroidManifestOrientation():Void
  {
    var manifestPath = 'export/release/android/bin/app/src/main/AndroidManifest.xml';
    if (!FileSystem.exists(manifestPath)) return;

    var manifest = File.getContent(manifestPath);
    var patched = manifest.replace('android:screenOrientation="sensorLandscape"', 'android:screenOrientation="landscape"');
    if (patched != manifest) File.saveContent(manifestPath, patched);
  }

  static function patchAndroidActivityOrientation():Void
  {
    var activityPath = 'export/release/android/bin/app/src/main/java/org/libsdl/app/SDLActivity.java';
    if (!FileSystem.exists(activityPath)) return;

    var activity = File.getContent(activityPath);
    var patched = activity;

    if (!patched.contains('import android.content.pm.ActivityInfo;'))
      patched = patched.replace('import android.os.Bundle;', 'import android.os.Bundle;\nimport android.content.pm.ActivityInfo;');

    if (!patched.contains('setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);'))
      patched = patched.replace('super.onCreate(savedInstanceState);',
        'super.onCreate(savedInstanceState);\n\t\tsetRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);');

    if (patched != activity) File.saveContent(activityPath, patched);
  }

  static function printBuildTime():Void
  {
    // get buildEnd before fs operations since they are blocking
    var end:Float = Sys.time();
    if (FileSystem.exists(BUILD_TIME_FILE))
    {
      var fi:sys.io.FileInput = File.read(BUILD_TIME_FILE);
      var start:Float = fi.readDouble();
      fi.close();

      sys.FileSystem.deleteFile(BUILD_TIME_FILE);

      Sys.println(' INFO '.info() + ' Build took: ${format(end - start)}');
    }
  }

  static function format(time:Float, decimals:Int = 1):String
  {
    var units = [{name: "day", secs: 86400}, {name: "hour", secs: 3600}, {name: "minute", secs: 60}, {name: "second", secs: 1}];

    var parts:Array<String> = [];
    var remaining:Float = time;
    var factor = Math.pow(10, decimals); // compute once because the old code was computing it twice.

    for (u in units)
    {
      var value:Float = (u.name == "second") ? Math.round(remaining * factor) / factor : Math.floor(remaining / u.secs);

      if (u.name != "second") remaining %= u.secs;

      if (value > 0 || (u.name == "second" && parts.length == 0)) parts.push('${value} ${u.name}${value == 1 ? "" : "s"}');
    }

    return parts.join(" ");
  }
}
