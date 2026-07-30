package funkin.ui.options;

#if mobile
import funkin.Preferences;

/**
 * Mobile-only options page for Arrow/Hitbox layout, RGB colors, and transparency.
 */
class ArrowsMenu extends PreferencesMenu
{
  override function createPrefItems():Void
  {
    createPrefItemEnum('Arrow Box', 'Choose the input layout: Arrow follows the receptors, Hitbox uses four full-screen touch lanes.',
      ["Arrow" => "Arrow", "Hitbox" => "Hitbox"], function(key:String, value:String):Void
      {
        Preferences.arrowBoxLayout = value;
      }, Preferences.arrowBoxLayout);

    createPrefItemCheckbox('RGB', 'When ON, hitbox lanes use the note-head colors. When OFF, they use the default hitbox colors.',
      function(value:Bool):Void
      {
        Preferences.arrowRGB = value;
      }, Preferences.arrowRGB);

    createPrefItemPercentage('Transparency', 'How visible the hitbox lanes are (0% = invisible, 90% = nearly solid).',
      function(value:Int):Void
      {
        Preferences.arrowTransparency = value;
      }, Preferences.arrowTransparency, 0, 90);
  }
}
#end
