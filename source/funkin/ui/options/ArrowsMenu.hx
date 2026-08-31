package funkin.ui.options;

#if mobile
import funkin.Preferences;
import funkin.mobile.ui.FunkinHitbox.FunkinHitboxControlSchemes;

class ArrowsMenu extends PreferencesMenu
{
  override function createPrefItems():Void
  {
    createPrefItemEnum('Arrow Box', 'Arrow places touch controls over the receptors. Hitbox uses four full-screen touch lanes.',
      ['Arrow' => FunkinHitboxControlSchemes.Arrows, 'Hitbox' => FunkinHitboxControlSchemes.FourLanes], function(key:String, value:String):Void
      {
        Preferences.controlsScheme = value;
      }, Preferences.controlsScheme == FunkinHitboxControlSchemes.Arrows ? 'Arrow' : 'Hitbox');

    createPrefItemCheckbox('RGB', 'Use the note direction colors instead of gray touch controls.', function(value:Bool):Void
    {
      Preferences.arrowRGB = value;
    }, Preferences.arrowRGB);

    createPrefItemPercentage('Transparency', 'Touch lane visibility while not pressed. Zero percent keeps the lanes invisible.', function(value:Int):Void
    {
      Preferences.arrowTransparency = value;
    }, Preferences.arrowTransparency, 0, 90);
  }
}
#end
