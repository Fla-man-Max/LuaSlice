package funkin.ui.debug.charting.handlers;

#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
import funkin.ui.debug.charting.handlers.audio.ChartEditorAudioHandler as NativeAudio;
import funkin.play.character.BaseCharacter.CharacterType;
import funkin.util.FileUtil;
import haxe.io.Bytes;
import haxe.io.Path;

@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorAudioHandler
{
  public static function loadVocalsFromPath(state:ChartEditorState, path:Path, charId:String, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadVocalsFromPath(state, path, charId, instId, wipeFirst);

  public static function loadVocalsFromAsset(state:ChartEditorState, path:String, charId:String, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadVocalsFromBytes(state, funkin.Assets.getBytes(path), charId, instId, wipeFirst);

  public static function loadVocalsFromBytes(state:ChartEditorState, bytes:Bytes, charId:String, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadVocalsFromBytes(state, bytes, charId, instId, wipeFirst);

  public static function loadInstFromPath(state:ChartEditorState, path:Path, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadInstFromPath(state, path, instId, wipeFirst);

  public static function loadInstFromAsset(state:ChartEditorState, path:String, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadInstFromBytes(state, funkin.Assets.getBytes(path), instId, wipeFirst);

  public static function loadInstFromBytes(state:ChartEditorState, bytes:Bytes, instId:String = '', wipeFirst:Bool = false):Bool
    return NativeAudio.loadInstFromBytes(state, bytes, instId, wipeFirst);

  public static function switchToInstrumental(state:ChartEditorState, instId:String = '', ?playerId:String, ?opponentId:String):Bool
  {
    if (!NativeAudio.playInstrumental(state, instId)) return false;
    refreshVocals(state, instId, playerId, opponentId);
    return true;
  }

  public static function refreshVocals(state:ChartEditorState, instId:String = '', ?playerId:String, ?opponentId:String):Void
  {
    NativeAudio.stopExistingVocals(state);
    NativeAudio.playVocals(state, BF, instId, playerId);
    NativeAudio.playVocals(state, DAD, instId, opponentId);
    state.postLoadVocals();
    state.hardRefreshOffsetsToolbox();
    state.loadSubtitles();
  }

  public static function playInstrumental(state:ChartEditorState, instId:String = ''):Bool
    return NativeAudio.playInstrumental(state, instId);
  public static function stopExistingInstrumental(state:ChartEditorState):Void
    NativeAudio.stopExistingInstrumental(state);
  public static function playVocals(state:ChartEditorState, charType:CharacterType, charId:String, instId:String = ''):Bool
    return NativeAudio.playVocals(state, charType, instId, charId);
  public static function stopExistingVocals(state:ChartEditorState):Void
    NativeAudio.stopExistingVocals(state);
  public static function playSound(state:ChartEditorState, path:String, volume:Float = 1.0):Void
    NativeAudio.playSound(state, path, volume);
  public static function playStretchySound(state:ChartEditorState, volume:Float = 1.0):Void
    NativeAudio.playStretchySound(state, volume);
  public static function wipeInstrumentalData(state:ChartEditorState):Void
    NativeAudio.wipeInstrumentalData(state);
  public static function wipeVocalData(state:ChartEditorState):Void
    NativeAudio.wipeVocalData(state);

  public static function makeZIPEntriesFromInstrumentals(state:ChartEditorState):Array<haxe.zip.Entry>
  {
    var entries:Array<haxe.zip.Entry> = [];
    for (key => bytes in state.audioInstTrackData)
    {
      if (bytes == null) continue;
      var suffix = key == '' || key == Constants.DEFAULT_VARIATION ? '' : '-$key';
      entries.push(FileUtil.makeZIPEntryFromBytes('Inst$suffix.ogg', bytes));
    }
    return entries;
  }

  public static function makeZIPEntriesFromVocals(state:ChartEditorState):Array<haxe.zip.Entry>
  {
    var entries:Array<haxe.zip.Entry> = [];
    for (key => bytes in state.audioVocalTrackData)
    {
      if (bytes == null) continue;
      entries.push(FileUtil.makeZIPEntryFromBytes(key == '' ? 'Voices.ogg' : 'Voices-$key.ogg', bytes));
    }
    return entries;
  }
}
#end
