# HTML5/Web (From Funkin' Crew)
1. Nope

# Windows
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist, alongside the executable.
2. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
3. Restart the game. The game should detect the mod and start with it.

# Linux
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist, alongside the executable.
2. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
3. Restart the game. The game should detect the mod and start with it.

# MacOS
1. Start the game at least once. This will create a `mods` folder if it doesn't already exist in the game's system files.
2. Right click `Funkin.app` and select `Show Package Contents`.
3. Navigate to `Contents/Resources/mods`.
4. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
5. Restart the game. The game should detect the mod and start with it.

# Android
1. Start the game at least once. This will create a `mods` folder deep in your system files.
2. Get an Android file browser that lets you view the app data files, or use Android Studio and open up the Device Explorer.
3. Locate the `/sdcard/Android/obb/me.funkin.fnf/mods` folder.
4. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
5. Restart the game (you may have to [force close](https://support.google.com/android/answer/9079646?hl=en) the app first). The game should detect the mod and start with it.

# iOS
1. Start the game at least once. This will create a `mods` folder in your system files.
2. Open the Files app, and navigate to `On My iPhone` -> `Friday Night Funkin` -> `mods`.
3. Extract the mod you downloaded from its ZIP file, and place the mod folder into the game's `mods` folder.
4. Restart the game (you may have to [force close](https://support.apple.com/en-us/109359) the app first). The game should detect the mod and start with it.

# Optional mod photosensitivity warning

Mod authors can opt in using the existing custom metadata object inside `_polymod_meta.json`. Keep the other required mod fields and merge this key into any existing `metadata` object:

```json
"metadata": {
  "photosensitivityWarning": "true"
}
```

The warning is shown before the selected mods' assets and scripts are activated. Players can continue or disable the existing Flashing Lights option and continue. Disabling this option only reduces effects that respect it; other mod visuals can still pose a photosensitivity risk. The option remains available in Options > Performance.

Acknowledgment lasts for the current app session, including song restarts and unchanged hot reloads. Changing a flagged mod's metadata or disabling and re-enabling it requires acknowledgment again. Unflagged mods do not show this warning.
