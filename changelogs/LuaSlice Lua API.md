# LuaSlice Lua API

LuaSlice supports isolated `.lua` scripts and global `.luag` scripts. Lua is enabled by default on native C++ builds. Use `-DNO_LUA` only if you need a build without Lua.

## Current API Audit
- This document is audited against the Lua API included with the LuaSlice v0.8.6 port.
- The current native bridge exposes 241 registered functions, plus the helper layer in `LuaApiPrelude.hx`.
- Functions removed from the current bridge are not listed here.
- Compatibility aliases are listed only when the current helper or native bridge still defines them.
- Use `LuaSlice.api.list()` inside the game to inspect the API available in the running build.
- Use `LuaSlice.api.find('functionName')` to inspect one function before depending on it.
- Native file access and native video playback are unavailable on HTML5.

## Script Types
- `.lua`: isolated script environment.
- `.luag`: global shared script environment.
- `.luag` is best for shared modules, global toggles, and compatibility helpers.
- `.ss`: isolated SScript with Haxe-style syntax.
- `.ssg`: global SScript loaded for every matching state.
- `.nx`: isolated NxScript bytecode script.
- `.nxg`: global NxScript loaded for every matching state.

LuaSlice uses the real SScript and NxScript interpreters. AngelScript is not disguised as another language: `.as` and `.asg` are not loaded unless a genuine, cross-platform AngelScript backend is added.

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

### SScript And NxScript Folders

- `mods/global.ssg` and `mods/global.nxg`
- `mods/scripts/global.ssg` and `mods/scripts/global.nxg`
- Global `.ssg` and `.nxg` files anywhere below `mods/scripts`
- `mods/StateClass.ss` and `mods/StateClass.nx`
- `mods/scripts/StateClass.ss` and `mods/scripts/StateClass.nx`
- `mods/scripts/states/StateClass.ss` and `mods/scripts/states/StateClass.nx`
- `mods/SongId.ss` and `mods/SongId.nx`
- `mods/scripts/songs/SongId.ss` and `mods/scripts/songs/SongId.nx`
- Local `.ss` and `.nx` files below `mods/scripts/gameplay` in PlayState
- The same paths inside every enabled mod folder

SScript and NxScript receive `state`, `game`, and `playState`, plus `FlxG`, `Paths`, `Preferences`, `Conductor`, `Save`, and `Json`. Supported hooks include `onCreate`, `onUpdate`, `onFocusGained`, `onFocusLost`, `onStepHit`, `onBeatHit`, and `onDestroy`.

## Script Examples

### Small Lua Song Script

```lua
function onCreate()
    debug.info('Loaded ' .. songName)
    window.setTitle('LuaSlice - ' .. songName)
end

function onBeatHit(beat)
    if beat % 4 == 0 then camera.setZoom('game', 1.03) end
end
```

### Lua Sprite

```lua
function onCreate()
    sprite.create('backdrop', 'my-mod/images/backdrop', -100, -50)
    sprite.set('backdrop', { alpha = 0.8, scale = 1.2 })
    sprite.setLayer('backdrop', 'background')
end
```

### Lua Timer And Tween

```lua
function onSongStart()
    timer.after(1, function()
        tween.to('camHUD', { alpha = 0.5 }, 0.4, {
            tag = 'hudFade',
            ease = 'quadOut'
        })
    end)
end
```

### Lua Save Value

```lua
function onCreate()
    local visits = save.get('visits', 0)
    save.set('visits', visits + 1)
    save.flush()
end
```

### Lua Note Kind

```lua
function onNoteHit(event)
    if event.note == nil then return end
    if event.note.kind == 'Heal Note' then addHealth(0.08) end
end

function onNoteMiss(event)
    if event.note == nil then return end
    if event.note.kind == 'Heal Note' then addHealth(-0.12) end
end
```

### SScript State Script

```haxe
function onCreate():Void
{
  trace('LuaSlice state script loaded');
}

function onBeatHit(beat:Int):Void
{
  if (beat % 4 == 0 && playState != null) playState.camGame.zoom = 1.03;
}
```

### NxScript State Script

```nx
func onCreate() {
    trace("NxScript state loaded")
}

func onBeatHit(beat) {
    if (beat % 4 == 0 && playState) playState.camGame.zoom = 1.03
}
```

## Advanced Script Examples

### Lua Custom Options Page

```lua
function onCreate()
    options.page('visualOptions', {
        name = 'Visual Options',
        position = 2,
        items = {
            { type = 'checkbox', key = 'particles', name = 'Particles', default = true },
            { type = 'number', key = 'particleCount', name = 'Particle Count', min = 0, max = 100, step = 5, default = 40 },
            { type = 'enum', key = 'color', name = 'Color', values = { 'Pink', 'Blue', 'Green' }, default = 'Pink' }
        }
    })
end
```

### Lua Menu

```lua
function onCreate()
    makeLuaMenuSimple('creditsMenu', { 'About', 'Back' }, 80, 120, 44)
end

function onLuaMenuAccept(menuId, index, label)
    if menuId ~= 'creditsMenu' then return end
    if label == 'About' then debug.info('This menu was created from Lua.') end
    if label == 'Back' then removeLuaMenu('creditsMenu') end
end
```

### Lua Animated Stage Object

```lua
function onCreate()
    loadSparrow('dancer', 'my-mod/images/dancer', 500, 250)
    addAnimByPrefix('dancer', 'idle', 'Dancer Idle', 24, true)
    addAnimByPrefix('dancer', 'hey', 'Dancer Hey', 24, false)
    setObjectZIndex('dancer', LuaSlice.layers.characters)
    playAnim('dancer', 'idle', true)
end

function onBeatHit(beat)
    if beat % 8 == 0 then playAnim('dancer', 'hey', true) end
end
```

### Lua Camera Shader With Cleanup

```lua
function onCreate()
    if not shader.make('gray', 'my-mod/shaders/grayscale.frag') then return end
    setShaderFloat('gray', 'amount', 0)
    setLuaCameraShader('gray', 'game')
end

function onSongStart()
    shader.tween('gray', 'amount', 0, 1, 1, 'quadInOut', 'grayAmount')
end

function onDestroy()
    removeLuaCameraShader('game')
    destroyShader('gray')
end
```

### Lua Group Of Objects

```lua
function onCreate()
    group.create('lights')
    for i = 1, 4 do
        local tag = 'light' .. i
        sprite.create(tag, 'my-mod/images/light', 160 * i, 100)
        group.add('lights', tag)
    end
    group.setAlpha('lights', 0.6)
end

function onSongStart()
    group.tween('lights', { alpha = 1 }, 0.5, { ease = 'quadOut', tag = 'lightsIn' })
end
```

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
- `FocusCamera` with fixed-position or character-follow targeting
- `ZoomCamera`, `SetCameraBop`, and `SetTargetBopSpeed`
- `PlayAnimation` for characters and named stage objects
- `PlayAudio` with `play`, `resume`, `volume`, `pause`, and `stop` actions
- `Overlay` and `Blackout`
- `HealthDrain` with Player/Opponent targeting and optional score changes
- `HUDFade` with Both, Player, and Opponent targeting for icons, notes, and strumlines
- `PlayDialogue`
- `PlayCountdown`
- `CameraFlash` and `CameraShake`
- `StageObjectControl`
- `ScrollSpeed` with optional `returnToOriginal`

These are normal Chart Editor events. File fields use explicit paths and start at `assets/` by default. Character targets use BF, Dad, or GF choices and named stage objects use the Object target. Play Dialogue lists available conversation JSON files, preloads their music, speakers, and dialogue boxes, then releases them when the conversation closes. F5 and song retries remove active event effects before the song is restored. Change Character reloads the character script when the same slot changes more than once. The removed Shader chart event is not part of this list; Lua shader APIs remain available to scripts.

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
- `shader.tween(tag, property, from, to, duration, ease?, tweenTag?)`
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
- `debugPrint(message)`
- `luaTrace(message)`
- `debugInfo(message)`
- `debugWarn(message)`
- `debugError(message)`
- `reloadLuaScripts()`
- `setLuaWindowTitle(title)`
- `getCurrentLuaScriptPath()`
- `stopCurrentLuaScript()`
- `setCurrentLuaScriptPriority(priority)`
- `jsonParse(text)`
- `jsonStringify(value, indentation?)`
- `fileExists(path)`
- `directoryExists(path)`
- `readTextFile(path)`
- `writeTextFile(path, text)`
- `randomFloat(min?, max?)`
- `randomInt(min?, max?)`
- `openLuaState(target, args?)`
- `openLuaSubState(target, args?)`

### Event Control
- `getCurrentEvent()`
- `getEventField(path)`
- `setEventField(path, value)`
- `cancelEvent()`
- `stopEventPropagation()`

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
- `keyPressed(key)`
- `keyJustPressed(key)`
- `keyJustReleased(key)`
- `mouseX()`
- `mouseY()`
- `mousePressed()`
- `mouseJustPressed()`
- `mouseJustReleased()`

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
- `setStrumlinePosition(target, x, y)`
- `setStrumlineAlpha(target, alpha)`
- `setStrumlineVisible(target, visible)`
- `setStrumlineNotePosition(target, direction, x, y)`
- `playStrumlineAnimation(target, direction, animation)`

Strumline targets are `player`, `opponent`, or `dad`. Directions use `0` through `3`. Animation names are `static`, `press`, `confirm`, `holdConfirm`, or `splash`.

### Screen
- `getScreenWidth`
- `getScreenHeight`
- `setFullscreen`
- `getMemoryUsageMB`
- `getDebugDisplayVisible`
- `setDebugDisplayVisible`

### Sprites And Text
- `addSprite(tag, asset, x?, y?, camera?, zIndex?, animated?)`
- `loadGraphic`
- `loadSparrow`
- `makeSolidSprite(tag, x?, y?, width?, height?, color?, camera?, zIndex?)`
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
- `tweenShaderFloat`
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

## Additional Lua Examples

These examples can be copied into a `.lua` or `.luag` file. Asset keys omit the file extension unless the example says otherwise.

### Basic Song Script

```lua
function onCreate()
    debug.info('Loaded ' .. songName .. ' on ' .. difficultyName)
    window.setTitle('LuaSlice - ' .. songName)
end

function onBeatHit(beat)
    if beat % 4 == 0 then
        camera.setZoom('game', 1.03)
    end
end
```

### Create And Configure A Sprite

```lua
function onCreate()
    sprite.create('myBackdrop', {
        image = 'my-mod/images/backdrop',
        x = -100,
        y = -50,
        alpha = 0.8,
        scale = 1.2,
        camera = 'game',
        layer = 'background'
    })

    setObjectScrollFactor('myBackdrop', 0.4, 0.4)
end
```

### Animated Sparrow Sprite

```lua
function onCreate()
    loadSparrow('dancer', 'my-mod/images/dancer', 500, 250)
    addAnimByPrefix('dancer', 'idle', 'Dancer Idle', 24, true)
    addAnimByPrefix('dancer', 'hey', 'Dancer Hey', 24, false)
    setObjectZIndex('dancer', LuaSlice.layers.characters)
    playAnim('dancer', 'idle', true)
end

function onBeatHit(beat)
    if beat % 8 == 0 then playAnim('dancer', 'hey', true) end
end
```

### Groups

```lua
function onCreate()
    group.create('lights')
    for i = 1, 4 do
        local tag = 'light' .. i
        sprite.create(tag, 'my-mod/images/light', 160 * i, 100)
        group.add('lights', tag)
    end
    group.each('lights', function(tag)
        sprite.setCamera(tag, 'hud')
    end)
    group.setAlpha('lights', 0.6)
end

function onSongStart()
    group.tween('lights', { alpha = 1 }, 0.5, {
        ease = 'quadOut',
        tag = 'lightsIn'
    })
end
```

### Tweens With Completion Callbacks

```lua
function onCreate()
    sprite.create('logo', 'my-mod/images/logo', 100, 100)
    tween.to('logo', { x = 900, angle = 360 }, 2, {
        tag = 'logoMove',
        ease = 'cubeInOut',
        onComplete = function(tag)
            debug.info(tag .. ' finished')
            tween.to('logo', { alpha = 0 }, 0.4, { tag = 'logoFade' })
        end
    })
end
```

### Timers

```lua
function onSongStart()
    timer.after(1, function()
        camera.flash('hud', '#FFFFFF', 0.25)
    end)

    local flashes = 0
    timer.every(0.5, function(loopsLeft)
        flashes = flashes + 1
        debug.print('Timer tick ' .. flashes)
    end)
end
```

### Beat And Step Scheduling

```lua
function onCreate()
    song.atBeat(16, function()
        camera.shake('game', 0.01, 0.3)
    end)

    song.atStep(128, function()
        setHealth(1.5)
    end)

    song.betweenBeats(32, 48, function(beat)
        if beat % 2 == 0 then addScore(100) end
    end)
end
```

### Named Events

```lua
function onCreate()
    event.on('songStart', function()
        debug.info('The song started')
    end)

    event.once('beat', 64, function(beat)
        camera.flash('game', '#FF66CC', 0.5)
    end)

    event.on('update', function(elapsed)
        -- Keep update callbacks short because they run every frame.
    end)
end
```

### Save Data

```lua
local wins = 0

function onCreate()
    wins = save.get('exampleWins', 0)
end

function onSongEnd()
    wins = wins + 1
    save.set('exampleWins', wins)
    save.flush()
end
```

### Custom Options Page

```lua
function onCreate()
    options.page('exampleOptions', {
        name = 'Example Mod',
        position = 2,
        items = {
            {
                type = 'checkbox',
                key = 'showParticles',
                name = 'Particles',
                description = 'Show the example particles.',
                default = true
            },
            {
                type = 'number',
                key = 'particleAmount',
                name = 'Particle Amount',
                min = 0,
                max = 100,
                step = 5,
                default = 50
            },
            {
                type = 'enum',
                key = 'particleColor',
                name = 'Particle Color',
                values = { 'Pink', 'Blue', 'Green' },
                default = 'Pink'
            }
        }
    })
end
```

### Character And Stage Control

```lua
function onBeatHit(beat)
    if beat == 32 and character.exists('dad') then
        character.playAnim('dad', 'hey', true)
    end

    if beat == 64 and stage.exists('spookyMansion') then
        stage.change('spookyMansion')
    end
end
```

### Fragment Shader On A Camera

```lua
function onCreate()
    if shader.make('gray', 'assets/preload/shaders/grayscale.frag') then
        setShaderFloat('gray', 'amount', 0)
        setLuaCameraShader('gray', 'game')
    end
end

function onSongStart()
    shader.tween('gray', 'amount', 0, 1, 1, 'quadInOut', 'grayAmount')
end

function onDestroy()
    removeLuaCameraShader('game')
    destroyShader('gray')
end
```

### Shader On A Stage Object

```lua
function onCreate()
    if shader.init('rim-light', 'rim') then
        shader.apply('object:streetLamp', 'rim')
        setShaderColor('rim', 'color', '#77CCFF')
    end
end
```

### Sound Control

```lua
function onCreate()
    sound.play('rainLoop', 'my-mod/sounds/rain', 0.4, true)
end

function onPause()
    pauseSound('rainLoop')
end

function onResume()
    resumeSound('rainLoop')
end

function onDestroy()
    sound.stop('rainLoop')
end
```

### Safe Property Access

```lua
function onCreate()
    local hudAlpha = property.get('camHUD.alpha')
    debug.print('HUD alpha: ' .. tostring(hudAlpha))

    property.set('camHUD.alpha', 0.75)
    property.setMany('camGame', {
        zoom = 1.05,
        alpha = 1
    })
end
```

### Global `.luag` Helper

```lua
-- Put this in mods/scripts/luag/helpers.luag.
function pulseCamera(cameraName, amount, duration)
    cameraName = cameraName or 'game'
    amount = amount or 1.05
    duration = duration or 0.25
    camera.tween(cameraName, { zoom = amount }, duration, 'quadOut')
end
```

```lua
-- Any later Lua script can call the global helper.
function onBeatHit(beat)
    if beat % 4 == 0 then pulseCamera('game', 1.04, 0.2) end
end
```

### Version Guard And Error Handling

```lua
function onCreate()
    if not LuaSlice.versionAtLeast('0.0.8') then
        debug.error('This mod needs LuaSlice v0.0.8 or newer.')
        script.stop()
        return
    end

    local ok, message = pcall(function()
        sprite.create('safeSprite', 'my-mod/images/safe-sprite', 0, 0)
    end)
    if not ok then debug.error(message) end
end
```

### Solid Color Sprite Without A Flash

`makeSolidSprite` creates the graphic immediately. It does not run a camera flash.

```lua
function onCreate()
    makeSolidSprite('redPanel', 40, 40, 320, 120, '#D92B3A', 'hud', 100)
    setObjectAlpha('redPanel', 0.8)
end

function onDestroy()
    removeSprite('redPanel')
end
```

### Lua Note Type Behavior

Place the script in a loaded Lua script folder and filter the note payload by `kind`. This example makes a `Heal Note` restore health without adding any screen flash.

```lua
local healAmount = 0.08

function onNoteHit(event)
    if event.note == nil then return end
    if event.note.kind ~= 'Heal Note' then return end
    addHealth(healAmount)
end

function onNoteMiss(event)
    if event.note == nil then return end
    if event.note.kind ~= 'Heal Note' then return end
    addHealth(-0.12)
end
```

The note payload can contain `strumTime`, `direction`, `noteData`, and `kind`. Check for `nil` because ghost misses do not always contain a normal note.

### Read The Current Note Event

```lua
function onNoteIncoming(event)
    local current = getCurrentEvent()
    if current == nil or current.note == nil then return end

    debug.info('Incoming direction: ' .. tostring(current.note.direction))
    debug.info('Incoming kind: ' .. tostring(current.note.kind))
end
```

### Keyboard And Mouse Input

```lua
function onUpdate(elapsed)
    if keyJustPressed('F6') then
        setDebugDisplayVisible(not getDebugDisplayVisible())
    end

    if mouseJustPressed() then
        debug.print('Mouse: ' .. mouseX() .. ', ' .. mouseY())
    end
end
```

### Health, Score, Combo, And Accuracy

```lua
function onBeatHit(beat)
    if beat % 8 ~= 0 then return end

    local tallies = getTallies()
    debug.print('Health: ' .. tostring(getHealth()))
    debug.print('Score: ' .. tostring(getScore()))
    debug.print('Combo: ' .. tostring(getCombo()))
    debug.print('Accuracy: ' .. tostring(getAccuracy()))
    debug.print('Sicks: ' .. tostring(tallies.sick))
end
```

### Position And Animate A Strumline

```lua
function onCreate()
    setStrumlinePosition('player', 420, 80)
    setStrumlineAlpha('opponent', 0.9)
    setStrumlineVisible('player', true)
end

function onStepHit(step)
    if step % 16 == 0 then
        playStrumlineAnimation('player', 0, 'confirm')
    end
end
```

### Read Chart Notes And Events

```lua
function onSongLoaded()
    local notes = getChartNotes()
    local events = getChartEvents()
    debug.info('Chart notes: ' .. tostring(#notes))
    debug.info('Chart events: ' .. tostring(#events))
end
```

### Camera Controls

```lua
function onSongStart()
    cameraFlash('hud', '#FFFFFF', 0.25)
    cameraShake('game', 0.006, 0.2)
    tweenCameraZoom(1.08, 0.35, false, 'quadOut')
end

function onDestroy()
    cancelCameraTweens()
    resetCamera(true, true, true)
end
```

### JSON And Text Files

```lua
function onCreate()
    local data = {
        enabled = true,
        amount = 3,
        label = 'LuaSlice'
    }

    local encoded = jsonStringify(data, '  ')
    local ok = writeTextFile('mods/my-mod/lua-example.json', encoded)
    if not ok then return end

    local text = readTextFile('mods/my-mod/lua-example.json')
    local decoded = jsonParse(text)
    debug.print(decoded.label)
end
```

File paths are native filesystem paths. Keep writes inside your mod folder and check the returned value.

### Script Priority And Hook Control

```lua
function onCreate()
    script.setPriority(50)
end

function onUpdate(elapsed)
    if getHealth() <= 0.25 then
        script.disableHook('onUpdate')
        debug.warn('Low-health update hook stopped.')
    end
end
```

### Character And Stage Checks

```lua
function onCreate()
    if stage.exists('mainStage') then
        stage.change('mainStage')
    end

    if character.exists('player') then
        character.playAnim('player', 'idle', true)
    end
end
```

### Playback And Vocals

```lua
function onSongStart()
    setPlaybackRate(1.0)
    setScrollSpeed(1.15, 'both')
    setVocalsVolume(1.0, 1.0)
end

function onPause()
    pauseSound('ambience')
end

function onResume()
    resumeSound('ambience')
end
```

### Safe Shader Cleanup

```lua
function onCreate()
    if not shader.make('heat', 'my-mod/shaders/heat.frag') then return end
    setLuaCameraShader('heat', 'game')
end

function onDestroy()
    removeLuaCameraShader('game')
end
```

### Save A Mod Setting

```lua
function onCreate()
    local launches = save.get('launches', 0)
    save.set('launches', launches + 1)
    save.flush()
end
```

### Schedule Work Without Per-Frame Polling

```lua
function onCreate()
    timer.after(1.0, function()
        debug.info('One second passed.')
    end)

    timer.every(0.5, function()
        addHealth(0.01)
    end)
end
```

## Error Reports And Logger
- Lua errors are written to `logs/lua`.
- Error windows include the script path, hook or API, Lua line number when available, report path, suggestions, and a performance warning only when repeated errors could affect FPS or memory.
- `-DFEATURE_LOGGER` enables the live Lua logger and writes logger builds to `export/logger/<target>/bin`.
- `-DNO_LUA` disables Lua support. Lua is enabled by default on native C++ builds.

## Current Limits
- HTML5 does not use hxlua.
