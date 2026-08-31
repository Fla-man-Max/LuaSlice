package funkin.ui.title;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.Assets;
import funkin.Paths;
import funkin.util.Constants;
import funkin.util.TouchUtil;
import funkin.util.WindowUtil;
import haxe.Json;
import lime.net.HTTPRequest;
import lime.net.HTTPRequestHeader;

using StringTools;

class LuaSliceUpdateState extends FlxState
{
  static final RELEASE_API:String = 'https://api.github.com/repos/Fla-man-Max/LuaSlice/releases?per_page=20';
  static final RELEASES_URL:String = 'https://github.com/Fla-man-Max/LuaSlice/releases';

  var request:Null<HTTPRequest<String>>;
  var checkTimer:Null<FlxTimer>;
  var returnTimer:Null<FlxTimer>;
  var message:Null<FlxText>;
  var nahButton:Null<FlxText>;
  var okayButton:Null<FlxText>;
  var selected:Int = 0;
  var promptReady:Bool = false;
  var leaving:Bool = false;
  var waitingForBrowser:Bool = false;
  var browserTookFocus:Bool = false;
  var installedVersion:String = Constants.LUASLICE_VERSION;

  public override function create():Void
  {
    super.create();

    var background:FlxSprite = new FlxSprite();
    background.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    add(background);

    installedVersion = readInstalledVersion();
    request = new HTTPRequest<String>();
    request.timeout = 5000;
    request.userAgent = 'LuaSlice/$installedVersion';
    request.headers = [new HTTPRequestHeader('Accept', 'application/vnd.github+json')];

    checkTimer = new FlxTimer().start(6, function(_)
    {
      if (!promptReady && !leaving)
      {
        if (request != null) request.cancel();
        openTitle();
      }
    });

    var future = request.load(RELEASE_API);
    future.onComplete(handleRelease);
    future.onError(function(_)
    {
      openTitle();
    });
  }

  function handleRelease(response:String):Void
  {
    if (leaving) return;

    if (checkTimer != null)
    {
      checkTimer.cancel();
      checkTimer = null;
    }

    try
    {
      var parsed:Dynamic = Json.parse(response);
      var releases:Array<Dynamic> = Std.isOfType(parsed, Array) ? cast parsed : [parsed];
      var latestVersion:Null<String> = null;
      for (release in releases)
      {
        if (Reflect.field(release, 'draft') == true) continue;
        var tag:Null<String> = Reflect.field(release, 'tag_name');
        if (tag != null && (latestVersion == null || isNewer(tag, latestVersion))) latestVersion = tag;
      }
      if (latestVersion != null && isNewer(latestVersion, installedVersion))
      {
        showPrompt(displayVersion(latestVersion));
        return;
      }
    }
    catch (_) {}

    openTitle();
  }

  function showPrompt(latestVersion:String):Void
  {
    message = new FlxText(60, 230, FlxG.width - 120, 'Please Update to the newest version of LuaSlice Engine ($latestVersion)!', 32);
    message.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
    message.antialiasing = false;
    add(message);

    nahButton = new FlxText(FlxG.width / 2 - 190, 410, 150, 'Nah', 42);
    nahButton.setFormat(Paths.font('vcr.ttf'), 42, FlxColor.WHITE, FlxTextAlign.CENTER);
    nahButton.antialiasing = false;
    add(nahButton);

    var separator:FlxText = new FlxText(FlxG.width / 2 - 40, 410, 80, '|', 42);
    separator.setFormat(Paths.font('vcr.ttf'), 42, FlxColor.WHITE, FlxTextAlign.CENTER);
    separator.antialiasing = false;
    add(separator);

    okayButton = new FlxText(FlxG.width / 2 + 40, 410, 150, 'Okay', 42);
    okayButton.setFormat(Paths.font('vcr.ttf'), 42, FlxColor.WHITE, FlxTextAlign.CENTER);
    okayButton.antialiasing = false;
    add(okayButton);

    promptReady = true;
    refreshSelection();
  }

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!promptReady || leaving || waitingForBrowser || nahButton == null || okayButton == null) return;

    var overNah:Bool = FlxG.mouse.overlaps(nahButton);
    var overOkay:Bool = FlxG.mouse.overlaps(okayButton);
    #if mobile
    overNah = overNah || TouchUtil.overlapsComplex(nahButton);
    overOkay = overOkay || TouchUtil.overlapsComplex(okayButton);
    #end

    if (overNah && selected != 0)
    {
      selected = 0;
      refreshSelection();
    }
    else if (overOkay && selected != 1)
    {
      selected = 1;
      refreshSelection();
    }

    if (FlxG.keys.anyJustPressed([LEFT, A]) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_LEFT))
    {
      selected = 0;
      refreshSelection();
    }
    else if (FlxG.keys.anyJustPressed([RIGHT, D]) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_RIGHT))
    {
      selected = 1;
      refreshSelection();
    }

    var clickedNah:Bool = overNah && FlxG.mouse.justReleased;
    var clickedOkay:Bool = overOkay && FlxG.mouse.justReleased;
    #if mobile
    clickedNah = clickedNah || TouchUtil.pressAction(nahButton);
    clickedOkay = clickedOkay || TouchUtil.pressAction(okayButton);
    #end

    if (clickedNah)
    {
      openTitle();
    }
    else if (clickedOkay)
    {
      openReleases();
    }
    else if (FlxG.keys.anyJustPressed([ENTER, SPACE]) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.ACCEPT))
    {
      if (selected == 0) openTitle();
      else openReleases();
    }
    else if (FlxG.keys.justPressed.ESCAPE || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.BACK))
    {
      openTitle();
    }
  }

  function refreshSelection():Void
  {
    if (nahButton == null || okayButton == null) return;
    nahButton.color = selected == 0 ? FlxColor.PURPLE : FlxColor.WHITE;
    okayButton.color = selected == 1 ? FlxColor.PURPLE : FlxColor.WHITE;
  }

  function openReleases():Void
  {
    waitingForBrowser = true;
    browserTookFocus = false;

    try
    {
      WindowUtil.openURL(RELEASES_URL);
    }
    catch (_)
    {
      openTitle();
      return;
    }

    returnTimer = new FlxTimer().start(0.75, function(_)
    {
      if (waitingForBrowser && !browserTookFocus) openTitle();
    });
  }

  public override function onFocusLost():Void
  {
    super.onFocusLost();
    if (waitingForBrowser) browserTookFocus = true;
  }

  public override function onFocus():Void
  {
    super.onFocus();
    if (waitingForBrowser) openTitle();
  }

  function openTitle():Void
  {
    if (leaving) return;
    leaving = true;
    waitingForBrowser = false;

    if (checkTimer != null) checkTimer.cancel();
    if (returnTimer != null) returnTimer.cancel();
    if (request != null) request.cancel();

    FlxTransitionableState.skipNextTransIn = true;
    FlxG.switchState(() -> new TitleState());
  }

  static function displayVersion(version:String):String
  {
    var clean:String = version.trim();
    if (clean == '') return 'v?';
    if (clean.charAt(0).toLowerCase() == 'v') clean = 'v${clean.substr(1)}';
    else clean = 'v$clean';
    return clean;
  }

  static function readInstalledVersion():String
  {
    try
    {
      var lines:Array<String> = Assets.getText(Paths.txt('VersionUpdater')).replace('\r', '').split('\n');
      if (lines.length > 1)
      {
        var version:String = lines[1].trim();
        if (version != '') return version;
      }
    }
    catch (_) {}

    return Constants.LUASLICE_VERSION;
  }

  static function isNewer(latest:String, current:String):Bool
  {
    var latestParts:Array<Int> = versionParts(latest);
    var currentParts:Array<Int> = versionParts(current);
    var count:Int = Std.int(Math.max(latestParts.length, currentParts.length));

    for (index in 0...count)
    {
      var latestPart:Int = index < latestParts.length ? latestParts[index] : 0;
      var currentPart:Int = index < currentParts.length ? currentParts[index] : 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  static function versionParts(version:String):Array<Int>
  {
    var clean:String = version.trim().toLowerCase();
    if (clean.startsWith('v')) clean = clean.substr(1);

    var result:Array<Int> = [];
    for (chunk in clean.split('.'))
    {
      var digits:String = '';
      for (index in 0...chunk.length)
      {
        var code:Null<Int> = chunk.charCodeAt(index);
        if (code == null || code < 48 || code > 57) break;
        digits += chunk.charAt(index);
      }

      if (digits == '') break;
      var part:Null<Int> = Std.parseInt(digits);
      if (part == null) break;
      result.push(part);
    }

    return result;
  }
}
