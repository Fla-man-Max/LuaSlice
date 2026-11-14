package funkin.ui.debug.charting.handlers;

#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.ChartEditorState;
import funkin.ui.debug.charting.handlers.chart.ChartEditorImportExportHandler as NativeImport;
import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.importer.ChartManifestData;
import funkin.util.file.FNFCUtil;
import haxe.io.Bytes;

@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorImportExportHandler
{
  public static final BACKUPS_PATH:String = NativeImport.BACKUPS_PATH;

  public static function loadSongAsTemplate(state:ChartEditorState, songId:String, ?targetSongDifficulty:String, ?targetSongVariation:String):Void
    NativeImport.loadSongFromTemplate(state, songId, targetSongDifficulty, targetSongVariation);

  public static function loadSong(state:ChartEditorState, newSongMetadata:Map<String, SongMetadata>, newSongChartData:Map<String, SongChartData>,
    ?newSongManifestData:ChartManifestData):Void
  {
    NativeImport.loadSongFromFNFCData(state, {
      manifest: newSongManifestData ?? state.songManifestData,
      songMetadatas: newSongMetadata,
      songChartDatas: newSongChartData,
      instrumentals: state.audioInstTrackData.copy(),
      vocals: state.audioVocalTrackData.copy()
    });
  }

  public static function loadFromFNFCPath(state:ChartEditorState, path:String):Null<Array<String>>
  {
    var data = FNFCUtil.loadDataFromFNFCPath(path, true);
    NativeImport.loadSongFromFNFCData(state, data, path);
    return data.issues;
  }

  public static function loadFromFNFC(state:ChartEditorState, bytes:Bytes):Null<Array<String>>
  {
    var data = FNFCUtil.loadDataFromFNFCBytes(bytes, true);
    NativeImport.loadSongFromFNFCData(state, data);
    return data.issues;
  }

  public static function getLatestBackupPath():Null<String> return NativeImport.getLatestBackupPath();
  public static function getLatestBackupInfo():Null<String> return NativeImport.getLatestBackupInfo();

  public static function exportAllSongData(state:ChartEditorState, force:Bool = false, ?targetPath:String, ?onSaveCb:String->Void,
    ?onCancelCb:Void->Void):Void
    NativeImport.exportCurrentChartToFNFC(state, force, targetPath, onSaveCb, onCancelCb);
}
#end
