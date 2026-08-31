package funkin.ui.transition.preload.hotreload;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.typeLimit.NextState;
import funkin.modding.PolymodHandler;
import funkin.modding.PolymodHandler.AssetReloadTask;
import funkin.ui.mainmenu.MainMenuState;
import funkin.util.plugins.ReloadAssetsDebugPlugin;
import funkin.util.assets.ResourceCache;

typedef HotReloadStateParams =
{
  var ?onComplete:Void->Void;
  var ?targetState:NextState;
}

@:nullSafety
class HotReloadState extends MusicBeatState
{
  var params:HotReloadStateParams;
  var tasks:Array<AssetReloadTask> = [];
  var taskIndex:Int = 0;
  var statusText:FlxText;
  var progressBar:FlxSprite;
  var failed:Bool = false;
  var finished:Bool = false;
  var reloadStartedAt:Float = 0;

  public function new(?params:HotReloadStateParams)
  {
    super();
    this.params = params ?? {};
    statusText = new FlxText(40, FlxG.height * 0.5 - 32, FlxG.width - 80, 'Preparing reload...', 24);
    progressBar = new FlxSprite(40, FlxG.height * 0.5 + 20);
  }

  override function create():Void
  {
    super.create();
    reloadStartedAt = haxe.Timer.stamp();
    add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));
    statusText.alignment = CENTER;
    add(statusText);
    progressBar.makeGraphic(1, 16, 0xFFCAFF4D);
    progressBar.origin.set(0, 0);
    add(progressBar);
    tasks = PolymodHandler.buildAssetReloadTasks();
    updateProgress();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (failed || finished) return;
    runNextTask();
  }

  function runNextTask():Void
  {
    if (taskIndex >= tasks.length)
    {
      finishReload();
      return;
    }

    var task:AssetReloadTask = tasks[taskIndex];
    statusText.text = task.label;
    try
    {
      task.run();
      taskIndex++;
      updateProgress();
    }
    catch (error:Dynamic)
    {
      failed = true;
      ReloadAssetsDebugPlugin.hotReloadInProgress = false;
      statusText.text = 'Hot reload failed\n${Std.string(error)}\nReturning to the main menu...';
      trace(error);
      new flixel.util.FlxTimer().start(1.5, _ -> FlxG.switchState(() -> new MainMenuState()));
    }
  }

  function updateProgress():Void
  {
    var ratio:Float = tasks.length == 0 ? 0 : taskIndex / tasks.length;
    progressBar.scale.x = Math.max(1, (FlxG.width - 80) * ratio);
  }

  function finishReload():Void
  {
    finished = true;
    ReloadAssetsDebugPlugin.hotReloadInProgress = false;
    statusText.text = 'Reload complete';
    #if debug
    var elapsedMs:Int = Math.round((haxe.Timer.stamp() - reloadStartedAt) * 1000);
    var cacheStats = ResourceCache.stats();
    trace('Hot reload completed in $elapsedMs ms; catalog ${cacheStats.catalogHits}/${cacheStats.catalogMisses}, text ${cacheStats.textHits}/${cacheStats.textMisses}');
    #end

    FlxG.signals.postStateSwitch.addOnce(() ->
    {
      var state:Dynamic = cast FlxG.state;
      if (state is MusicBeatState || state is MusicBeatSubState) state.onPostHotReload();
    });

    if (params.targetState != null)
    {
      if (params.onComplete != null) params.onComplete();
      FlxG.switchState(params.targetState);
      return;
    }

    if (params.onComplete != null)
    {
      params.onComplete();
      return;
    }

    FlxG.switchState(() -> new MainMenuState());
  }

  override function destroy():Void
  {
    if (!finished) ReloadAssetsDebugPlugin.hotReloadInProgress = false;
    super.destroy();
  }
}
