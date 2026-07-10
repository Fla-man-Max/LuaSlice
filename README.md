# LuaSlice
I added Lua Support to V-slice. I don't know what to add mor-

Join mine Discord Server!
- [LuaSlice Engine](https://discord.gg/sCr5rpPwBn)

You can download the LuaSlice Versions Here:
- [Versions](https://github.com/Fla-man-Max/LuaSlice/releases)
- [Source Code](https://github.com/Fla-man-Max/LuaSlice)
- [Gamebanana](https://gamebanana.com/tools/23050)

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

### Shaders

- `shader.init(name, tag?)`
- `shader.make(tag, path, vertex?)`
- `shader.apply(target, tag)`
- `shader.remove(target)`
- `shader.exists(tag)`
- `initLuaShader(name, tag?)`
- `makeLuaShader(tag, pathOrSource?, vertexPathOrSource?)`
- `setLuaShader(tag, target)`
- `setShaderOnSprite(sprite, tag)`
- `removeLuaShader(target)`
- `setLuaCameraShader(tag, camera?)`
- `removeLuaCameraShader(camera?)`
- `setLuaShaderFloatSimple(tag, name, value)`

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
- `script.reload()`
- `disableLuaHook(name)`
- `enableLuaHook(name)`

### Tweens And Timers

- `tween.to(target, values, duration, options?)`
- `tween.cancel(tag)`
- `timer.after(delay, callback)`
- `timer.every(delay, callback)`

### Song Events

- `song.getPosition()`
- `song.atBeat(beat, callback)`
- `song.atStep(step, callback)`
- `event.on(name, callback)`
- `event.once(name, callback)`

### Menus

- `addLuaMainMenu(id, position, target, assetPath?, animName?)`
- `makeLuaMenuSimple(id, items, x?, y?, spacing?)`
- `makeLuaImageMenuSimple(id, items, x?, y?, spacing?)`

## Raw Bridge API

### Core

- `debugPrint`
- `luaTrace`
- `reloadLuaScripts`
- `jsonParse`
- `jsonStringify`
- `fileExists`
- `directoryExists`
- `readTextFile`
- `writeTextFile`
- `randomFloat`
- `randomInt`

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

### Shader Bridge

- `initLuaShaderRaw`
- `initLuaShader`
- `makeLuaShader`
- `setLuaShader`
- `setShaderOnSprite`
- `createShader`
- `destroyShader`
- `setShaderFloat`
- `setShaderFloatArray`
- `setShaderInt`
- `setShaderBool`
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