package funkin.ui.debug.moddebug;

#if (FEATURE_HAXEUI && (windows || android))
import flixel.FlxCamera;
import flixel.FlxState;
import funkin.data.character.CharacterRegistry;
import funkin.data.song.SongRegistry;
import funkin.data.stage.StageRegistry;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.PlayState;
import funkin.play.PlayStatePlaylist;
import funkin.play.character.BaseCharacter.CharacterType;
import funkin.play.stage.Stage;
import funkin.ui.transition.Transition;
import luaslice.debug.ModDebugSession;

class ModDebugPreview
{
  public var stage(default, null):Null<Stage>;
  public var stageId(default, null):Null<String>;
  public var paused:Bool = false;
  public var hideHud:Bool = false;
  public var testing(default, null):Bool = false;
  public var characterIds:Array<String> = ['bf', 'dad', 'gf'];

  final owner:FlxState;
  final camera:FlxCamera;
  final session:ModDebugSession;
  final status:String->Void;
  final preparePlay:Void->Void;
  final setTestingUI:Bool->Void;

  public function new(owner:FlxState, camera:FlxCamera, session:ModDebugSession, status:String->Void, preparePlay:Void->Void, setTestingUI:Bool->Void)
  {
    this.owner = owner;
    this.camera = camera;
    this.session = session;
    this.status = status;
    this.preparePlay = preparePlay;
    this.setTestingUI = setTestingUI;
  }

  public function loadStage(id:String):Bool
  {
    if (testing) return false;
    var candidate:Null<Stage> = null;
    try
    {
      candidate = StageRegistry.instance.createDiagnosticPreview(id);
      if (candidate == null) throw 'Stage is not registered: $id';
      candidate.cameras = [camera];
      dispatch(candidate, CREATE);
      for (i in 0...characterIds.length)
      {
        var characterId = characterIds[i];
        if (characterId == '') continue;
        var character = CharacterRegistry.instance.fetchEntry(characterId);
        if (character == null) throw 'Character is not registered: $characterId';
        final role:CharacterType = switch (i) { case 0: BF; case 1: DAD; default: GF; };
        candidate.addCharacter(character, role);
        dispatch(character, CREATE);
      }
      candidate.refresh();
    }
    catch (error:Dynamic)
    {
      if (candidate != null) destroyStage(candidate);
      session.diagnostics.record('asset', id, Std.string(error), haxe.Timer.stamp());
      status('Stage failed: $error');
      return false;
    }
    clearStage();
    session.nextPreview();
    stage = candidate;
    stageId = id;
    owner.add(candidate);
    candidate.active = !paused;
    camera.zoom = candidate.camZoom;
    focusCharacter(0);
    status('Stage preview: $id');
    session.diagnostics.record('stage', id, 'Preview loaded', haxe.Timer.stamp());
    return true;
  }

  public function focusCharacter(role:Int):Void
  {
    var character = switch (role) {
      case 0: stage?.getBoyfriend();
      case 1: stage?.getDad();
      default: stage?.getGirlfriend();
    };
    if (character != null) camera.focusOn(character.cameraFocusPoint);
  }

  public function panCamera(x:Float, y:Float):Void
  {
    if (stage != null && !testing) camera.scroll.add(x / camera.zoom, y / camera.zoom);
  }

  public function zoomCamera(amount:Float):Void
  {
    if (stage != null && !testing) camera.zoom = Math.max(0.15, Math.min(4, camera.zoom + amount));
  }

  public function update(elapsed:Float):Void
  {
    if (stage == null || testing) return;
    stage.active = !paused;
    if (paused) return;
    var event = UpdateScriptEvent.get(elapsed);
    ScriptEventDispatcher.callEvent(stage, event);
    stage.dispatchToCharacters(event);
    event.finish();
  }

  public function startSong(id:String, variation:String, difficulty:String):Bool
  {
    if (testing) return false;
    var song = SongRegistry.instance.fetchEntry(id, {variation: variation});
    if (song?.getDifficulty(difficulty, variation) == null)
    {
      status('Chart not found: $id / $variation / $difficulty');
      session.diagnostics.record('asset', id, 'Requested chart was not found', haxe.Timer.stamp());
      return false;
    }
    var generation = session.nextPreview();
    PlayStatePlaylist.reset();
    testing = true;
    setTestingUI(true);
    status('Loading $id / $difficulty…');
    session.diagnostics.record('song', id, 'Loading $variation / $difficulty', haxe.Timer.stamp());
    try Transition.openPlayState({
      targetSong: song,
      targetVariation: variation,
      targetDifficulty: difficulty,
      diagnosticSession: session,
      diagnosticGeneration: generation,
      diagnosticHideHud: hideHud
    }, {
      transition: None,
      shouldStopMusic: true,
      shouldPurgeCache: false,
      onConstruct: state ->
      {
        preparePlay();
      }
    }, true) catch (error:Dynamic)
    {
      returnFromTest('Could not start $id: $error');
      session.diagnostics.record('asset', id, Std.string(error), haxe.Timer.stamp());
      return false;
    }
    return true;
  }

  public function returnFromTest(message:String = 'Returned from song test. No score was saved.'):Void
  {
    testing = false;
    session.nextPreview();
    setTestingUI(false);
    status(message);
  }

  public function dispose():Void
  {
    testing = false;
    session.nextPreview();
    clearStage();
  }

  function clearStage():Void
  {
    if (stage == null) return;
    var old = stage;
    stage = null;
    stageId = null;
    owner.remove(old, true);
    destroyStage(old);
  }

  static function destroyStage(value:Stage):Void
  {
    try dispatch(value, DESTROY) catch (error:Dynamic) trace('[Mod Debug] Stage cleanup: $error');
    value.destroy();
  }

  static function dispatch(target:funkin.modding.IScriptedClass, type:funkin.modding.events.ScriptEventType):Void
  {
    var event = ScriptEvent.get(type);
    try ScriptEventDispatcher.callEvent(target, event) catch (error:Dynamic)
    {
      event.finish();
      throw error;
    }
    event.finish();
  }
}
#end
