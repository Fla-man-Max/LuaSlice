package funkin.ui.options;

#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end
import funkin.save.Save;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.graphics.FunkinSprite;

class SaveDataMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var descriptions:Array<String> = [];
  var descriptionText:FlxText;
  var descriptionBox:FunkinSprite;

  public function new()
  {
    super();

    add(items = new TextMenuList());

    createItem("CLEAR ALL DATA", "This will erase all data.", openSaveDataPrompt);
    createItem("CLEAR SONGS DATA", "Erases all song data.", openSongDataPrompt);
    createItem("CLEAR OPTIONS", "Sets options back to their default state.", openOptionsPrompt);
    createItem("CLEAR CONTROLS", "Sets all controls back to their defaults.", openControlsPrompt);

    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem("LOAD FROM NG", "Loads save data from Newgrounds.", function()
      {
        openConfirmPrompt("This will overwrite
        \nALL your save data.
        \nAre you sure?", "Overwrite",
          () -> Save.loadFromNewgrounds(() -> FlxG.switchState(() -> new funkin.InitState())));
      });

      createItem("SAVE TO NG", "Saves all data to Newgrounds.", function()
      {
        openConfirmPrompt("This will overwrite
        \nALL save data saved
        \non NG. Are you sure?", "Overwrite", function()
        {
          Save.saveToNewgrounds();
        });
      });

      createItem("CLEAR NG SAVE DATA", "Erases all data saved on Newgrounds.", function()
      {
        openConfirmPrompt("This will delete
        \nALL save data saved
        \non NG. Are you sure?", "Delete", function()
        {
          funkin.api.newgrounds.NGSaveSlot.instance.clear();
        });
      });
    }
    #end

    createItem("EXIT", "Returns to the Options menu.", exit);

    add(descriptionBox = new FunkinSprite());
    descriptionBox.makeSolidColor(1, 1, FlxColor.BLACK);
    descriptionBox.alpha = 0.6;
    descriptionBox.setPosition(50, FlxG.height - 160);
    descriptionBox.setGraphicSize(FlxG.width - 100, 110);
    descriptionBox.updateHitbox();

    add(descriptionText = new FlxText(70, FlxG.height - 145, FlxG.width - 140, descriptions[0], 30));
    descriptionText.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, flixel.text.FlxText.FlxTextAlign.CENTER,
      flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    descriptionText.borderSize = 2;
    items.onChange.add(function(_) descriptionText.text = descriptions[items.selectedIndex]);
  }

  function createItem(name:String, description:String, callback:Void->Void, fireInstantly = false)
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    descriptions.push(description);
    return item;
  }

  override function update(elapsed:Float)
  {
    enabled = (prompt == null);
    super.update(elapsed);
  }

  override function set_enabled(value:Bool)
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  var prompt:Prompt;

  function openConfirmPrompt(text:String, yesText:String, onYes:Void->Void, ?groupToOpenOn:Null<flixel.group.FlxGroup>):Void
  {
    if (prompt != null) return;

    prompt = new Prompt(text, Custom(yesText, "Cancel"));
    prompt.create();
    prompt.createBgFromMargin(100, 0xFFFAFD6D);
    prompt.back.scrollFactor.set(0, 0);
    FlxG.state.add(prompt);

    prompt.onYes = function()
    {
      onYes();

      if (prompt != null)
      {
        prompt.close();
        prompt.destroy();
        prompt = null;
      }
    };

    prompt.onNo = function()
    {
      prompt.close();
      prompt.destroy();
      prompt = null;
    }
  }

  public function openSaveDataPrompt()
  {
    openConfirmPrompt("This will delete
        \nALL your save data.
        \nAre you sure?
      ", "Delete", function()
    {
      // Clear the save data.
      Save.clearData();

      FlxG.switchState(() -> new funkin.InitState());
    });
  }

  function openSongDataPrompt():Void
  {
    openConfirmPrompt("This will erase\nall song data.\nAre you sure?", "Delete", function()
    {
      Save.instance.clearSongData();
      FlxG.switchState(() -> new funkin.InitState());
    });
  }

  function openOptionsPrompt():Void
  {
    openConfirmPrompt("This will reset\nall options to default.\nAre you sure?", "Reset", function()
    {
      Save.instance.clearOptions();
      FlxG.switchState(() -> new funkin.InitState());
    });
  }

  function openControlsPrompt():Void
  {
    openConfirmPrompt("This will reset\nall controls to default.\nAre you sure?", "Reset", function()
    {
      Save.instance.clearControls();
      FlxG.switchState(() -> new funkin.InitState());
    });
  }

  /**
   * True if this page has multiple options, excluding the exit option.
   * If false, there's no reason to ever show this page.
   */
  public function hasMultipleOptions():Bool
  {
    return items.length > 2;
  }
}
