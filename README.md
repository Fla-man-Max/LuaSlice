# LuaSlice
LuaSlice is a fork of Friday Night Funkin' V-Slice that adds built-in Lua modding support and small tweaks to the engine itself. It is made for people who want to create gameplay scripts, events, menus, options and other mod features without having to write everything in Haxe.

LuaSlice supports isolated `.lua` scripts and shared `.luag` scripts. It also includes F5 hot reloading, Lua error reports, persistent save data, custom Chart Editor events, and Lua hooks for gameplay and menus. Existing `.hx` and `.hxc` modding still works, so Lua can be used by itself or alongside Haxe scripts.

The engine is based on V-Slice 0.8.6 and is still being worked on. Lua compatibility is the main focus, along with making mod creation easier on Windows and Android. And maybe other builds....

Join the LuaSlice Discord server:
- [LuaSlice Engine](https://discord.gg/sCr5rpPwBn)

Download LuaSlice or view its source code here:
- [Versions](https://github.com/Fla-man-Max/LuaSlice/releases)
- [Source Code](https://github.com/Fla-man-Max/LuaSlice)
- [Gamebanana](https://gamebanana.com/tools/23050)

---

# LuaSlice Lua API

LuaSlice supports isolated `.lua` scripts and global `.luag` scripts. Lua is enabled by default on native C++ builds. Use `-DNO_LUA` only if you need a build without Lua.

## Script Types
- `.lua`: isolated script environment.
- `.luag`: global shared script environment.
- `.luag` is best for shared modules, global toggles, and compatibility helpers.

## Main Script Folders
- `mods/global.lua`
- `mods/global.luag`
- `mods/scripts/global.lua`
- `mods/scripts/global.luag`
- `mods/scripts/*.lua`
- `mods/scripts/*.luag`
- `mods/scripts/lua/*.lua`
- `mods/scripts/luag/*.luag`
- `mods/scripts/menu/*.lua`
- `mods/scripts/menu/*.luag`
- `mods/scripts/options/*.lua`
- `mods/scripts/options/*.luag`
- `mods/scripts/pause/*.lua`
- `mods/scripts/pause/*.luag`
- `mods/scripts/freeplay/*.lua`
- `mods/scripts/freeplay/*.luag`
- `mods/scripts/story/*.lua`
- `mods/scripts/story/*.luag`
- `mods/scripts/results/*.lua`
- `mods/scripts/results/*.luag`
- `mods/scripts/characters/CharacterId.lua`
- `mods/scripts/characters/CharacterId.luag`
- `mods/scripts/song-SongId.lua`
- `mods/scripts/song-SongId.luag`
- `mods/scripts/stage-StageId.lua`
- `mods/scripts/stages/StageId.lua`
- `mods/<mod name>/scripts/*.lua`
- `mods/<mod name>/scripts/*.luag`
- `mods/<mod name>/scripts/lua/*.lua`
- `mods/<mod name>/scripts/luag/*.luag`
- `mods/<mod name>/scripts/menu/*.lua`
- `mods/<mod name>/scripts/options/*.luag`
- `mods/<mod name>/scripts/pause/*.luag`
- `mods/<mod name>/songs/SongId/script.lua`
- `mods/<mod name>/songs/SongId/script.luag`
- `mods/<mod name>/data/songs/SongId/script.lua`
- `mods/<mod name>/data/songs/SongId/script.luag`
- `mods/<mod name>/stages/StageId.lua`

## Require Paths
- `mods/?.lua`
- `mods/?.luag`
- `mods/?/init.lua`
- `mods/?/init.luag`
- `mods/scripts/?.lua`
- `mods/scripts/?.luag`
- `mods/scripts/?/init.lua`
- `mods/scripts/?/init.luag`
- `mods/<mod name>/?.lua`
- `mods/<mod name>/?.luag`
- `mods/<mod name>/?/init.lua`
- `mods/<mod name>/?/init.luag`
- `mods/<mod name>/script/?.lua`
- `mods/<mod name>/script/?.luag`
- `mods/<mod name>/scripts/?.lua`
- `mods/<mod name>/scripts/?.luag`

## Hot Reload
- `F5` reloads Lua in PlayState.
- `reloadLuaScripts()` requests the same reload from Lua.
- `onReload()` runs after reload.
- Lua-created sprites, text, sounds, tweens, timers, menus, shaders, and registered objects are cleaned before reload.

## LuaSlice Chart Events
- `PreloadResource`
- `ChangeCharacter` with optional `preload`
- `ChangeStage` with optional `preload`
- `PlayAudio` with `play`, `resume`, `volume`, `pause`, and `stop` actions
- `Shader` with apply/remove actions for `.hxc` and `.frag` shaders, including number, whole-number, on/off, X/Y, color, and optional transparent-pixel protection for sprite targets
- `Overlay` and `Blackout`
- `HealthDrain` with Player/Opponent targeting and optional score changes
- `HUDFade` with Both, Player, and Opponent targeting for icons, notes, and strumlines
- `PlayDialogue`
- `PlayCountdown`
- `HUDFade`
- `CameraFlash` and `CameraShake`
- `StageObjectControl`
- `ScrollSpeed` with optional `returnToOriginal`

These are normal Chart Editor events. File fields use explicit paths and start at `assets/` by default. Shader entries include `.hxc` classes, `.frag` files, and the built-in `DropShadowShader`. Character targets use BF, Dad, or GF choices, named stage objects use the Object target, and fragment shaders on sprite targets can ignore fully transparent pixels. Play Dialogue lists available conversation JSON files, preloads their music, speakers, and dialogue boxes, then releases them when the conversation closes. F5 and song retries remove active event effects before the song is restored.

## Script Folder Rules
- `scripts/lua` loads `.lua` only.
- `scripts/luag` loads `.luag` only.
- `scripts/menu` loads in the Main Menu.
- `scripts/options` loads in Options.
- `scripts/pause` loads in PlayState and can configure the pause menu.
- `scripts/freeplay`, `scripts/story`, and `scripts/results` load for their matching screens.
- `scripts/characters/CharacterId` loads when that Player, Opponent, or Girlfriend becomes active.
- Chart Editor Playtest's `Enable Song Scripts` controls song-scoped `.hxc` and `.luag` scripts, not `.lua` scripts.
- PlayState also scans `modules`, `module`, `ui`, `UI`, `gameplay`, `opponent`, `player`, `songs`, `stages`, `characters`, `events`, `notekinds`, `players`, `shaders`, `dialogue`, and `levels` under each scripts folder.

## Globals
- `luaSupportVersion`
- `luaScriptCount`
- `luaGlobalScriptCount`
- `luaIsolatedScriptCount`
- `songName`
- `songId`
- `difficultyName`
- `variationName`
- `stageId`
- `curBeat`
- `curStep`
- `songPosition`
- `health`
- `score`
- `combo`
- `botPlay`
- `practice`

## Hooks
- Lifecycle: `onCreate`, `onReload`, `onUpdate`, `onDestroy`, `onAdded`
- Timing: `onStepHit`, `onBeatHit`, `onSectionHit`
- Song: `onSongLoaded`, `onCountdownStart`, `onCountdownStep`, `onCountdownEnd`, `onSongStart`, `onSongEnd`, `onSongRetry`
- Notes: `onNoteIncoming`, `onNoteHit`, `onNoteMiss`, `onNoteHoldDrop`, `onGhostMiss`, `onNoteGhostMiss`
- Events: `onEvent`, `onCreateEvent`, `onUpdateEvent`, `onDestroyEvent`, `onSongEvent`
- State: `onStateCreate`, `onStateChangeBegin`, `onStateChangeEnd`, `onSubStateOpenBegin`, `onSubStateOpenEnd`, `onSubStateCloseBegin`, `onSubStateCloseEnd`
- Gameplay: `onPause`, `onResume`, `onGameOver`
- Input: `onKeyDown`, `onKeyUp`, `onFocusGained`, `onFocusLost`
- Dialogue: `onDialogueStart`, `onDialogueLine`, `onDialogueCompleteLine`, `onDialogueSkip`, `onDialogueEnd`
- Completion: `onTweenCompleted`, `onTimerCompleted`
- Menus: `onLuaMenuChange`, `onLuaMenuAccept`, `onLuaMenuCancel`, `onLuaMainMenuAccept`, `onPauseMenuCreate`, `onLuaPauseMenuAccept`, `onLuaOptionChanged`
- Screens: `onFreeplayCreate`, `onFreeplayUpdate`, `onFreeplayClose`, `onStoryCreate`, `onStoryUpdate`, `onStoryClose`, `onResultsCreate`, `onResultsUpdate`, `onResultsClose`

## New Helper API

### Docs
- `LuaSlice.version`
- `LuaSlice.versionAtLeast(version)`
- `requiresLuaSlice(version)`
- `LuaSlice.api.list(category?)`
- `LuaSlice.api.find(name)`
- `LuaSlice.api.docs()`
- `LuaSlice.api.writeDocs(path?)`

### Debug
- `debug.print(message)`
- `debug.info(message)`
- `debug.warn(message)`
- `debug.error(message)`

### Properties
- `property.get(path)`
- `property.set(path, value)`
- `property.setMany(target, values)`
- `property.ref(path)`

### Window
- `window.setTitle(title)`

### Sprites
- `sprite.create(tag, data, x?, y?)`
- `sprite.add(tag, options?)`
- `sprite.remove(tag)`
- `sprite.exists(tag)`
- `sprite.set(tag, values)`
- `sprite.setAlpha(tag, value)`
- `sprite.setCamera(tag, camera)`
- `sprite.setLayer(tag, layer)`

Named layers:
- `background`
- `stage`
- `characters`
- `foreground`
- `hud`
- `top`

### Groups
- `group.create(name)`
- `group.add(name, tag)`
- `group.each(name, callback)`
- `group.set(name, values)`
- `group.setAlpha(name, alpha)`
- `group.setLayer(name, layer)`
- `group.tween(name, values, duration, options?)`
- `group.remove(name, tag?)`

### Camera
- `camera.setZoom(cameraName, zoom)`
- `camera.flash(cameraName, color, duration)`
- `camera.shake(cameraName, intensity, duration)`
- `camera.tween(cameraName, values, duration, ease?)`

### Characters And Stages
- `character.exists(target)`
- `character.playAnim(target, animation, force?, reversed?, frame?)`
- `stage.exists(id)`
- `stage.change(id)`
- `option.exists(key)`

### Shaders
- `shader.init(name, tag?)`
- `shader.make(tag, path, vertex?)`
- `shader.apply(target, tag)`
- `shader.remove(target)`
- `shader.exists(tag)`
- `shader.setColor(tag, property, color)`
- `initLuaShader(name, tag?)`
- `makeLuaShader(tag, pathOrSource?, vertexPathOrSource?)`
- `setLuaShader(tag, target)`
- `setShaderOnSprite(sprite, tag)`
- `removeLuaShader(target)`
- `setLuaCameraShader(tag, camera?)`
- `removeLuaCameraShader(camera?)`
- `setLuaShaderFloatSimple(tag, name, value)`
- `setShaderColor(tag, property, color)`

Named stage objects can be targeted with `object:<name>`, for example `setShaderOnSprite("object:streetLamp", "rim")`. `DropShadowShader` supports `color`, `angle`, `distance`, `strength`, `threshold`, `antialiasAmt`, `baseHue`, `baseSaturation`, `baseBrightness`, `baseContrast`, and `maskThreshold`.

### Save
- `save.get(key, fallback?)`
- `save.set(key, value)`
- `save.flush()`
- `getLuaSave(key, fallback?)`
- `setLuaSave(key, value)`
- `flushSave()`

### Sound
- `sound.play(tag, key, volume?, looped?)`
- `sound.stop(tag)`
- `sound.exists(tag)`

### Scripts
- `script.disableHook(name)`
- `script.enableHook(name)`
- `script.getName()`
- `script.getPath()`
- `script.reload()`
- `script.stop()`
- `script.setPriority(priority)`
- `disableLuaHook(name)`
- `enableLuaHook(name)`

### Tweens And Timers
- `tween.to(target, values, duration, options?)`
- `tween.cancel(tag)`
- `tween.pause(tag)`
- `tween.resume(tag)`
- `timer.after(delay, callback)`
- `timer.every(delay, callback)`

### Song Events
- `song.getPosition()`
- `song.atBeat(beat, callback)`
- `song.atStep(step, callback)`
- `song.betweenBeats(firstBeat, lastBeat, callback)`
- `event.on(name, callback)`
- `event.once(name, callback)`
- `event.once(name, value, callback)`

### Options Schema
- `options.page(id, config)`

The config accepts `name`, `position`, and an `items` array containing `checkbox`, `number`, or `enum` entries. The older simple option helpers remain supported.

### Menus
- `addLuaMainMenu(id, position, target, assetPath?, animName?)`
- `makeLuaMenuSimple(id, items, x?, y?, spacing?)`
- `makeLuaImageMenuSimple(id, items, x?, y?, spacing?)`

## Raw Bridge API

### Core
- `debugPrint`
- `luaTrace`
- `debugInfo`
- `debugWarn`
- `debugError`
- `reloadLuaScripts`
- `setLuaWindowTitle`
- `getCurrentLuaScriptPath`
- `stopCurrentLuaScript`
- `setCurrentLuaScriptPriority`
- `jsonParse`
- `jsonStringify`
- `fileExists`
- `directoryExists`
- `readTextFile`
- `writeTextFile`
- `randomFloat`
- `randomInt`
- `openLuaState(target, args?)`
- `openLuaSubState(target, args?)`

### Event Control
- `getCurrentEvent`
- `getEventField`
- `setEventField`
- `cancelEvent`
- `stopEventPropagation`

### Reflection And Objects
- `getProperty`
- `setProperty`
- `setProperties`
- `getPropertyRef`
- `setPropertyRef`
- `objectExists`
- `getObjectProperty`
- `setObjectProperty`
- `callMethod`
- `classExists`
- `getStaticProperty`
- `setStaticProperty`
- `callStatic`
- `createInstance`
- `storeObject`
- `forgetObject`
- `addObjectToState`
- `removeObjectFromState`
- `destroyObject`
- `getArrayLength`
- `getArrayItem`
- `setArrayItem`

### Input
- `keyPressed`
- `keyJustPressed`
- `keyJustReleased`
- `mouseX`
- `mouseY`
- `mousePressed`
- `mouseJustPressed`
- `mouseJustReleased`

### Song And PlayState
- `getSongPosition`
- `getBeat`
- `getStep`
- `getSongName`
- `getDifficulty`
- `getVariation`
- `getStageId`
- `changeStage`
- `changeCharacter`
- `getPlaybackRate`
- `setPlaybackRate`
- `getScrollSpeed`
- `setScrollSpeed`
- `getChartNotes`
- `getChartEvents`
- `setBotplay`
- `setPracticeMode`
- `getPreference`
- `setPreference`
- `getHealth`
- `setHealth`
- `addHealth`
- `getScore`
- `setScore`
- `addScore`
- `getCombo`
- `setCombo`
- `getAccuracy`
- `getTallies`
- `setVocalsVolume`
- `startCountdown`
- `startConversation`
- `endSong`
- `restartSong`

### Strumlines
- `setStrumlinePosition`
- `setStrumlineAlpha`
- `setStrumlineVisible`
- `setStrumlineNotePosition`
- `playStrumlineAnimation`

### Screen
- `getScreenWidth`
- `getScreenHeight`
- `setFullscreen`
- `getMemoryUsageMB`
- `getDebugDisplayVisible`
- `setDebugDisplayVisible`

### Sprites And Text
- `addSprite`
- `loadGraphic`
- `loadSparrow`
- `makeSolidSprite`
- `removeSprite`
- `setSpriteCamera`
- `addText`
- `setText`
- `setTextFormat`
- `removeText`
- `setObjectCamera`
- `setObjectPosition`
- `getObjectX`
- `getObjectY`
- `getObjectWidth`
- `getObjectHeight`
- `getObjectAlpha`
- `getObjectVisible`
- `getObjectAngle`
- `setObjectScale`
- `setObjectSize`
- `setObjectAlpha`
- `setObjectVisible`
- `setObjectAngle`
- `setObjectColor`
- `setObjectVelocity`
- `setObjectAcceleration`
- `setObjectScrollFactor`
- `setObjectZIndex`
- `screenCenter`
- `killObject`
- `reviveObject`
- `addAnimByPrefix`
- `playAnim`
- `hasAnim`

### Lua Options
- `defineLuaOption`
- `getLuaOption`
- `setLuaOption`
- `hasLuaOption`
- `luaStageExists`
- `removeLuaOption`
- `getLuaOptions`
- `createLuaOptionPage`
- `addLuaCheckbox`
- `addLuaNumber`
- `addLuaEnum`

### Lua Menus And Pause
- `createLuaMenu`
- `createLuaImageMenu`
- `addLuaMainMenuItem`
- `configureLuaPauseMenu`
- `setLuaPauseOptions`
- `setLuaPauseOptionsBehavior`
- `setLuaPauseMenuItem`
- `setLuaMenuItems`
- `setLuaMenuPosition`
- `showLuaMenu`
- `hideLuaMenu`
- `removeLuaMenu`
- `getLuaMenuSelected`

Pause item targets include `resume`, `restartSong`, `changeDifficulty`, `practiceMode`, `exitToMenu`, `options`, `callback`, and custom `.hx` or `.hxc` state classes. Pause-opened Options behavior can be configured with `hideExit` and `howExit`.

### Shader Bridge
- `initLuaShaderRaw`
- `initLuaShader`
- `makeLuaShader`
- `setLuaShader`
- `setShaderOnSprite`
- `createShader`
- `destroyShader`
- `luaShaderExists`
- `setShaderFloat`
- `setShaderFloatArray`
- `setShaderInt`
- `setShaderBool`
- `setShaderColor`
- `applyShader`
- `clearShader`
- `applyCameraShader`
- `clearCameraShader`

### Audio And Video
- `playSound`
- `stopSound`
- `pauseSound`
- `resumeSound`
- `setSoundVolume`
- `soundExists`
- `playMusic`
- `stopMusic`
- `pauseMusic`
- `resumeMusic`
- `setMusicVolume`
- `playVideo`
- `pauseVideo`
- `resumeVideo`
- `finishVideo`
- `isVideoPlaying`

### Raw Tweens And Timers
- `tween`
- `cancelTween`
- `pauseTween`
- `resumeTween`
- `runTimer`
- `cancelTimer`

### Cameras
- `setCamZoom`
- `cameraFlash`
- `cameraFade`
- `cameraShake`
- `setCameraZoom`
- `setCameraAlpha`
- `setCameraBgColor`
- `setCameraVisible`
- `setCameraPosition`
- `setCameraFollow`
- `setCameraBop`
- `setHealthBarColors`
- `resetCamera`
- `tweenCameraZoom`
- `tweenCameraToPosition`
- `cancelCameraTweens`
- `tweenScrollSpeed`
- `cancelScrollSpeedTweens`

### Paths
- `pathImage`
- `pathSound`
- `pathMusic`
- `pathFont`
- `pathFile`
- `pathJson`

### Compatibility Aliases
- `makeLuaSprite`
- `makeAnimatedLuaSprite`
- `makeGraphic`
- `addLuaSprite`
- `removeLuaSprite`
- `makeLuaText`
- `setTextString`
- `removeLuaText`
- `doTween`
- `doTweenX`
- `doTweenY`
- `doTweenAlpha`
- `doTweenAngle`
- `runTimer`
- `cancelTimer`

LuaSlice warns once when some old aliases are used, then keeps the script running.

## Error Reports And Logger
- Lua errors are written to `logs/lua`.
- Error windows include the script path, hook or API, Lua line number when available, report path, suggestions, and a performance warning only when repeated errors could affect FPS or memory.
- `-DFEATURE_LOGGER` enables the live Lua logger and writes logger builds to `export/logger/<target>/bin`.
- `-DNO_LUA` disables Lua support. Lua is enabled by default on native C++ builds.

## Current Limits
- HTML5 does not use hxlua.
