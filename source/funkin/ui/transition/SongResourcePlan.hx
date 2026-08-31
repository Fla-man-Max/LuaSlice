package funkin.ui.transition;

import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.stage.StageRegistry;
import funkin.play.PlayState.PlayStateParams;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.play.song.Song.SongDifficulty;
import openfl.utils.Assets;

@:nullSafety
class SongResourcePlan
{
  public final difficulty:SongDifficulty;
  public final audioPaths:Array<String>;
  public final characterIds:Array<String>;
  public final stageId:String;
  public final stageIds:Array<String>;
  public final noteStyleId:String;
  final extraVisualPaths:Array<String>;
  final extraAudioPaths:Array<String>;

  function new(difficulty:SongDifficulty, params:PlayStateParams)
  {
    this.difficulty = difficulty;
    this.audioPaths = [];
    this.characterIds = [];
    this.stageId = difficulty.stage ?? Constants.DEFAULT_STAGE;
    this.stageIds = [this.stageId];
    this.noteStyleId = difficulty.noteStyle ?? Constants.DEFAULT_NOTE_STYLE;
    this.extraVisualPaths = [];
    this.extraAudioPaths = [];

    if (!(params.overrideMusic ?? false))
    {
      addUnique(audioPaths, difficulty.getInstPath(params.targetInstrumental));
      for (path in difficulty.buildVoiceList()) addUnique(audioPaths, path);
    }

    if (difficulty.characters != null)
    {
      addUnique(characterIds, difficulty.characters.player);
      addUnique(characterIds, difficulty.characters.opponent);
      addUnique(characterIds, difficulty.characters.girlfriend);
    }

    for (event in difficulty.events ?? [])
    {
      if (event == null) continue;
      switch (event.eventKind)
      {
        case 'ChangeCharacter': addUnique(characterIds, event.getString('id') ?? '');
        case 'ChangeStage': addUnique(stageIds, event.getString('stage') ?? '');
        default:
      }
    }

    if (difficulty.songName == '2hot')
    {
      for (asset in [
        'wked1_cutscene_1_can',
        'spraypaintExplosionEZ',
        'SpraypaintExplosion',
        'CanImpactParticle',
        'spraycanAtlas/spritemap1'
      ])
        addUnique(extraVisualPaths, Paths.image(asset, 'weekend1'));
      for (asset in [
        'Darnell_Lighter',
        'fuse_burning',
        'Gun_Prep',
        'Kick_Can_FORWARD',
        'Kick_Can_UP',
        'Lightning1',
        'Lightning2',
        'Lightning3',
        'Pico_Bonk',
        'Shoot_1',
        'shot1',
        'shot2',
        'shot3',
        'shot4'
      ])
        addUnique(extraAudioPaths, Paths.sound(asset, 'weekend1'));
    }
  }

  public static function build(params:PlayStateParams):SongResourcePlan
  {
    var song = params.targetSong ?? throw 'Song resource plan requires a target song';
    if (!(params.overrideMusic ?? false)) song.cacheCharts(true);
    var difficultyId:String = params.targetDifficulty ?? Constants.DEFAULT_DIFFICULTY;
    var variation:String = params.targetVariation ?? Constants.DEFAULT_VARIATION;
    var difficulty:Null<SongDifficulty> = song.getDifficulty(difficultyId, variation);
    if (difficulty == null) throw 'Could not build resource plan for ${song.id}:$variation:$difficultyId';
    return new SongResourcePlan(difficulty, params);
  }

  public function preloadVisuals():Void
  {
    for (targetStageId in stageIds)
    {
      var stage = StageRegistry.instance.fetchEntry(targetStageId);
      if (stage == null) continue;
      for (path in stage.fetchAssetPaths())
      {
        if (Assets.exists(path)) FunkinMemory.cacheTexture(path);
      }
    }

    var noteStyle = NoteStyleRegistry.instance.fetchEntry(noteStyleId);
    if (noteStyle == null) noteStyle = NoteStyleRegistry.instance.fetchDefault();
    if (noteStyle != null) FunkinMemory.cacheNoteStyle(noteStyle);
    for (style in NoteKindManager.listNoteStylesByNoteData(difficulty.notes)) FunkinMemory.cacheNoteStyle(style);

    for (id in characterIds)
    {
      var data = CharacterDataParser.fetchCharacterData(id);
      if (data == null) continue;
      cacheCharacterPath(data.assetPath);
      for (animation in data.animations)
      {
        if (animation.assetPath != null) cacheCharacterPath(animation.assetPath);
      }
    }

    for (path in extraVisualPaths)
    {
      if (!Assets.exists(path)) continue;
      FunkinMemory.cacheTexture(path);
      if (path.endsWith('spritemap1.png') #if FEATURE_COMPRESSED_TEXTURES || path.endsWith('spritemap1.astc') #end) Assets.getBitmapData(path, true);
    }
    for (path in extraAudioPaths)
      if (Assets.exists(path)) FunkinMemory.cacheSound(path);
  }

  public function preloadAudio():Void
  {
    for (path in audioPaths)
    {
      if (Assets.exists(path)) FunkinMemory.cacheSound(path);
    }
  }

  public function preloadRequired():Void
  {
    preloadVisuals();
    preloadAudio();
  }

  static function cacheCharacterPath(path:String):Void
  {
    if (path == null || path == '') return;
    var imagePath:String = Paths.image(path);
    if (Assets.exists(imagePath)) FunkinMemory.cacheTexture(imagePath);
  }

  static function addUnique(values:Array<String>, value:String):Void
  {
    if (value != null && value != '' && !values.contains(value)) values.push(value);
  }
}
