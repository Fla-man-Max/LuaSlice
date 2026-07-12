package funkin.ui.options;

import funkin.Preferences;
import funkin.ui.debug.FunkinDebugDisplay.DebugDisplayMode;
import lime.ui.WindowVSyncMode;

class PerformanceMenu extends PreferencesMenu
{
  override function createPrefItems():Void
  {
    createPrefItemCheckbox('Shaders',
      'Enable song shaders on stages and characters. Low Quality Minimal/Max forces this off.',
      function(value:Bool):Void
      {
        Preferences.songShaders = value;
      }, Preferences.songShaders);

    createPrefItemEnum('Low Quality',
      'None keeps everything normal. Minimal trims heavier song and menu visuals. Max removes extra gameplay HUD effects too.',
      ["None" => "None", "Minimal" => "Minimal", "Max" => "Max"], function(key:String, value:String):Void
      {
        Preferences.lowQualityMode = value;
      }, Preferences.lowQualityMode);

    #if !(mobile || web)
    createPrefItemEnum('VSync', "When enabled, the game attempts to match the framerate with your monitor's refresh rate.",
      ["Off" => WindowVSyncMode.OFF, "On" => WindowVSyncMode.ON, "Adaptive" => WindowVSyncMode.ADAPTIVE], function(key:String, value:WindowVSyncMode):Void
      {
        Preferences.vsyncMode = value;
      }, switch (Preferences.vsyncMode)
      {
        case WindowVSyncMode.OFF: "Off";
        case WindowVSyncMode.ON: "On";
        case WindowVSyncMode.ADAPTIVE: "Adaptive";
      });
    #end

    #if (android || (!mobile && !web))
    #if android
    if (Preferences.supportsUnlockedFramerate())
    {
    #end
    createPrefItemCheckbox(#if android 'Unlimited FPS' #else 'Unlocked Framerate' #end,
      #if android 'Removes the software framerate limit. Your display may still limit the result.' #else 'When enabled, the framerate is unlocked.\nThis setting is mutually exclusive with FPS.' #end,
      function(value:Bool):Void
      {
        Preferences.unlockedFramerate = value;
      }, Preferences.unlockedFramerate);
    #if android
    }
    #end
    #end

    #if !(mobile || web)
    createPrefItemNumber('FPS', 'The maximum framerate that the game targets.\nThis setting is mutually exclusive with Unlocked Framerate.',
      function(value:Float):Void
      {
        Preferences.framerate = Std.int(value);
      }, null, Preferences.framerate, 30, 500, 5, 0);
    #end

    #if FEATURE_DEBUG_DISPLAY
    createPrefItemEnum('Debug Display', 'When enabled, FPS and other debug stats are displayed.',
      ["Advanced" => DebugDisplayMode.Advanced, "Simple" => DebugDisplayMode.Simple, "Off" => DebugDisplayMode.Off], (key:String, value:DebugDisplayMode) ->
      {
        Preferences.debugDisplay = value;
      }, Preferences.debugDisplay);
    createPrefItemPercentage('Debug Display BG', "Adjust the debug display's background opacity.", function(value:Int):Void
    {
      Preferences.debugDisplayBGOpacity = value;
    }, Preferences.debugDisplayBGOpacity);
    #end
  }
}
