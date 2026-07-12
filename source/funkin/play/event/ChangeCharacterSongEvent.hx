package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;
import funkin.data.song.SongData.SongEventData;
import funkin.data.character.CharacterData.CharacterDataParser;

class ChangeCharacterSongEvent extends SongEvent
{
  public function new()
  {
    super('ChangeCharacter', {
      processOldEvents: true
    });
  }

  public override function handleEvent(data:SongEventData):Void
  {
    final char:Int = data.getInt('char') ?? 0;
    final characterId:String = data.getString('id') ?? '';
    if (PlayState.instance == null || !PlayState.instance.changeCharacter(char, characterId, true))
    {
      trace(' WARNING '.warning() + ' ChangeCharacterSongEvent: Could not load character "${characterId}".');
    }
  }

  public override function getTitle():String
  {
    return 'Change Character';
  }

  public override function getEventSchema():SongEventSchema
  {
    final characters:Map<String, Dynamic> = [];
    for (characterId in CharacterDataParser.listCharacterIds())
      characters.set(characterId, characterId);

    return new SongEventSchema([{
      name: 'char',
      title: 'Character',
      defaultValue: 0,
      type: SongEventFieldType.ENUM,
      keys: ['Player' => 0, 'Opponent' => 1, 'Girlfriend' => 2],
    }, {
      name: 'id',
      title: 'Character',
      defaultValue: Constants.DEFAULT_CHARACTER,
      type: SongEventFieldType.ENUM,
      keys: characters,
    }]);
  }
}
