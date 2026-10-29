# Psych Lua API Changelog

Changes to LuaSlice's Psych Lua API. The script folders, examples, and compatibility notes are below the changelog.

## [0.2.0] - 2026-10-26

### Added

- `addHScript`, `removeHScript`, `callOnHScript`, and `setOnHScript`. Loaded HScript files receive gameplay hooks, and `callOnScripts` and `setOnScripts` reach them too.
- `addToGroup` and `removeFromGroup`.
- Adobe Animate atlas functions: `makeFlxAnimateSprite`, `loadAnimateAtlas`, `addAnimationBySymbol`, and `addAnimationBySymbolIndices`.
- `loadMultipleFrames`, `insertToCustomSubstate`, `exitSong`, `loadSong`, `getModSetting`, `startVideo`, `startDialogue`, and `updateScoreText`.
- Rating setters, `onRecalculateRating`, and the rating, miss, hit, combo, botplay, and practice globals from Psych 1.0.4.

### Compatibility

- `setTimeBarColors` is accepted but has no effect: V-Slice does not have Psych's time bar.
- `startDialogue` uses V-Slice conversations, not Psych dialogue JSON. A path uses its file name as the conversation id.
- `getModSetting` reads saved values or defaults from the mod's `data/settings.json`.
- `loadSong` uses V-Slice song ids; spaces become dashes and names are lowercased.
- File-based HScript keeps LuaSlice's existing import restrictions and error reporting.
- Animate atlases use the standard `Animation.json` and spritemap filenames. Custom JSON filenames are not supported.
- Videos use the engine's skippable, non-looping cutscene playback. Unsupported video options report an error rather than being silently ignored.

## [0.1.5] - 2026-10-22

### Added

- LuaSlice custom script events call `onCustom(id, data)`. Return `Function_Stop` to cancel a cancelable event. This is a LuaSlice extension, separate from Psych chart events.
- Haxe string-keyed Maps, including nested custom-event data, convert to Lua tables.
- Sparrow hold bodies and end caps convert to continuous trails, preserving frame trim offsets, proportions and downscroll.

### Fixed

- Closing or unloading a script inside a callback waits until that callback returns before closing its Lua state.
- Failed initialization and reload validation release their Lua states instead of leaving them registered.
- Reloading clears old note overrides and owned splash sprites, and restores native note graphics.
- Custom note-type scripts load in a consistent order.
- Generated hold textures are reused by matching notes and released after their final user is gone during reload or song cleanup.
- `onSpawnNote` receives the note's strum time as its fifth argument, matching Psych 1.0.4.

### Changed

- Script errors include the runtime, mod path, callback and Lua traceback. Identical errors are reported once per script instance.

## [0.1.0] - 2026-09-28

### Added

- Added the Psych Engine 1.0.4 Lua API to LuaSlice.
- Added `.luap` and `.luapg` scripts for songs, stages, characters, custom events, and note types.
- Added script hot reload, including F5 and automatic file watching.

### Changed

- Switched from hxlua to hxluajit and hxluajit-wrapper.
- LuaSlice's existing `.lua` and `.luag` scripts still use their own API.

## API guide

### LuaSlice custom script events

HScript can dispatch a custom event through the current state:

```haxe
import funkin.modding.events.ScriptEvent.CustomScriptEvent;
import funkin.play.PlayState;

var event = new CustomScriptEvent("my-mod:phase", true);
event.data.set("phase", 2);
PlayState.instance.dispatchEvent(event);
trace(event.eventCanceled);
```

Receive it from a `.luap` or `.luapg` script:

```lua
function onCustom(id, data)
    if id == 'my-mod:phase' and data.phase == 2 then
        return Function_Stop
    end
end
```

Lua receives a snapshot of the data, not a live Haxe Map. HScript, SScript and NxScript receive the event itself and can edit its Map, call `cancel()` or `stopPropagation()`. Cancellation prevents the sender's associated behavior only when the sender checks `eventCanceled`; it does not stop propagation. Ordinary chart events still use `onEvent`.

Requires LuaSlice v0.1.0 or newer. This port follows Psych Engine 1.0.4, but runs on FNF v0.8.6. Some things work differently because LuaSlice still uses V-Slice's gameplay and asset formats.

Scripts run on LuaJIT 2.1, using hxluajit 1.0.5 and hxluajit-wrapper 1.0.0. Haxe calls use Iris 1.1.3.

LuaJIT uses Lua 5.1 syntax. If you're moving a Lua 5.4 script over, use `math.floor(a / b)` for floor division and the `bit` library for bitwise operations. Lua 5.4 variable attributes and compiled bytecode won't work. `table.pack` and `table.unpack` are included. Share the script source with your mod; native FFI code may not work on another platform.

## Installation and script folders

Put your mod in `mods`, include `_polymod_meta.json`, and enable it. Disabled mods won't load scripts. Set the metadata's `api_version` to the FNF version, such as `0.8.6`, not the LuaSlice or Psych version.

Each Lua file has its own globals. The following folders are relative to the mod:

| Folder | When it loads |
| --- | --- |
| `*.luapg` at the mod root, or `scripts/*.luapg` | Every song |
| `scripts/*.luap` | Every song, following Psych's folder convention |
| `data/<song-id>/*.luap`, `data/songs/<song-id>/*.luap`, or `songs/<song-id>/*.luap` | That song |
| `stages/<stage-id>.luap` | The current stage |
| `characters/<character-id>.luap` | Each character used by that stage |
| `custom_notetypes/<kind>.luap` | A note kind present in the chart |
| `custom_events/<event-name>.luap` | An event present in the chart |

Rename your Psych scripts from `.lua` to `.luap`. For a script that runs in every song, put a `.luapg` file in the mod root or `scripts/`.

Global means it loads in every song, not that all scripts share variables. Each Psych script has its own Lua state. Use `setVar`/`getVar` or the cross-script helpers to share values.

Match your folder and file names to the chart IDs, including capitalization. This matters on Android. `addLuaScript('path/name')` looks for `.luap`; include the extension when loading a `.luapg` file.

Assets go in `images/`, `sounds/`, `music/`, `fonts/`, and `shaders/` inside your mod. Leave off the extension when using image and sound helpers. `require` can load Lua modules from your mod too.

Only run mods you trust. Lua's standard libraries are still available, so this is not a security sandbox for an entire mod. Haxe imports and reflection through the Psych bridge now respect LuaSlice's existing class and field restrictions; filesystem, process-launching and interpreter internals are not exposed through that bridge.

To try the included example, copy `example_mods/psych-lua-test` into `mods`, enable it, and play Tutorial. Its `scripts/api-test.luapg` also runs in other songs.

## Script examples

### Text and a solid-color sprite

```lua
function onCreate()
    makeLuaSprite('panel', nil, 24, 24)
    makeGraphic('panel', 380, 80, '14243A')
    setObjectCamera('panel', 'hud')
    addLuaSprite('panel', true)

    makeLuaText('message', 'Hello from Lua!', 350, 40, 45)
    setTextSize('message', 24)
    setTextColor('message', 'A7E8FF')
    addLuaText('message')
end
```

### Tween, timer, and callbacks

Add this to the text-and-sprite example above.

```lua
function onCreatePost()
    doTweenAlpha('fadePanel', 'panel', 0.5, 0.4, 'quadOut')
    runTimer('changeMessage', 2)
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'changeMessage' then
        setTextString('message', 'Timer finished')
    end
end

function onTweenCompleted(tag, target)
    debugPrint('Completed', tag, target)
end
```

### Custom note type

Save this as `custom_notetypes/Bonus.luap`, then set a note's kind to `Bonus` in the chart editor.

```lua
function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'Bonus' and not isSustainNote then
        addHealth(0.04)
        addScore(50)
    end
end
```

### Moving the camera on a beat

```lua
function onBeatHit()
    if curBeat == 16 then
        triggerVSliceEvent('FocusCamera', {
            char = 0,
            x = 0,
            y = -40,
            duration = 4,
            ease = 'quad',
            easeDir = 'Out'
        })
    end
end
```

### Saving mod settings

```lua
function onCreate()
    initSaveData('settings')
    local visits = getDataFromSave('settings', 'visits', 0)
    setDataFromSave('settings', 'visits', visits + 1)
    flushSaveData('settings')
end
```

### Reloading

Press **F5** to use the game's normal reload, including Psych scripts. There is no separate Psych reload shortcut.

Scripts can still call `reloadLuaScripts()` to reload just the Psych scripts, or `setLuaAutoReload(true)` to check for file changes once per second. The following describes that script-only reload, not F5's full game-state reload.

If an edited file has a syntax error, the current scripts keep running. Other errors show the script and callback name. Changes a script already made aren't automatically undone.

Reload clears the scripts' sprites, text, timers, tweens, sounds, save handles, and Haxe interpreters. It then calls `onCreate`, `onCreatePost`, and `onReload`. The music keeps playing. Values saved with `setVar` survive reload; ordinary Lua globals reset.

In LuaSlice, `onCreate` runs after the stage, characters, and receptors are ready, before the countdown. This is later than in Psych.

## Advanced script examples

### Calling Haxe from Lua

```lua
function onCreate()
    local result = runHaxeCode('return 6 * 7;')
    debugPrint(result)
    runHaxeCode([[
        function doubleValue(value) {
            return value * 2;
        }
    ]])
    debugPrint(runHaxeFunction('doubleValue', {21}))
end
```

In Haxe code, `game` is the current PlayState. `FlxG`, `FlxSprite`, `FlxText`, `FlxCamera`, `FlxTween`, `FlxEase`, `FlxTimer`, `Paths`, `PlayState`, `Conductor`, `ShaderFilter`, and `FlxRuntimeShader` are already available. The bridge also includes `Assets`, `Preferences`, `Constants`, `FunkinSprite`, `FlxObject`, `FlxMath`, `FlxPoint`, `StringMap`, `IntMap`, `Json` and `Lambda`. `Reflect` and `Type` use the engine's safe reflection helpers.

Use `addHaxeLibrary('TypeName', 'package.name')` for another permitted class compiled into the game. It returns false for a missing or blocked class; it doesn't install libraries. Optional missing imports produce a diagnostic and let the rest of the snippet run. Parse and runtime failures report the script path and snippet line, returning nil so another call can recover. Existing `.hx` and `.hxc` scripts still use Polymod; no extra interpreter is required.

Use `setVar`, `getVar` and `removeVar` to share values with Lua. `createCallback` exposes an HScript function to its owning Lua script:

```lua
function onCreatePost()
    runHaxeCode([[
        setVar('extraPoints', 25);
        createCallback('addExtraPoints', function(points) {
            return points + getVar('extraPoints', 0);
        });
    ]])
    debugPrint(addExtraPoints(100))
end
```

If you add an object directly with `game.add()`, remove it yourself when reloading. Objects made through the Lua helpers are cleaned up automatically.

### Custom pause overlay

```lua
function onUpdate()
    if keyboardJustPressed('F7') then
        openCustomSubstate('info', true)
    end
end

function onCustomSubstateCreate(name)
    if name == 'info' then
        makeLuaText('infoText', 'Press Escape to return', 600, 80, 80)
        setObjectCamera('infoText', 'other')
        addToCustomSubstate('infoText')
    end
end

function onCustomSubstateUpdate(name, elapsed)
    if name == 'info' and keyboardJustPressed('ESCAPE') then
        closeCustomSubstate()
    end
end
```

Objects you move into a custom substate are destroyed when it closes. Don't move the game's stage or characters into it.

Closing isn't immediate. Use `onCustomSubstateDestroy` to run code when it closes, rather than checking for deleted objects straight after `closeCustomSubstate()`.

## Callbacks and globals

Callbacks: `onCreate`, `onCreatePost`, `onDestroy`, `onReload`, `onUpdate(elapsed)`, `onUpdatePost(elapsed)`, `onStartCountdown`, `onCountdownTick(index)`, `onSongStart`, `onEndSong`, `onPause`, `onResume`, `onGameOver`, `onSongRetry`, `onBeatHit`, `onStepHit`, `onSectionHit`, `onMoveCamera(target)`, `onSpawnNote(id, direction, kind, isSustainNote, strumTime)`, `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `noteMissPress(direction)`, `onEvent(name, value1, value2, time)`, `onTimerCompleted`, `onTweenCompleted`, `onSoundFinished`, and the custom-substate callbacks shown above plus `onCustomSubstateCreatePost`, `onCustomSubstateUpdatePost`, and `onCustomSubstateDestroy`.

`Function_Continue`, `Function_Stop`, `Function_StopLua`, and `Function_StopAll` are available. Stop/StopAll can cancel game events that support cancellation. They can't undo callbacks that already ran.

Globals include `version` (Psych API reference version), `vSliceVersion`, `scriptName`, `modFolder`, `curBeat`, `curStep`, `curDecBeat`, `curDecStep`, `curSection`, `bpm`, `curBpm`, `crochet`, `stepCrochet`, `songPosition`, `songName`, `songPath`, `songLength`, `curStage`, `screenWidth`, `screenHeight`, `downscroll`, `scrollSpeed`, `score`, `health`, `difficultyName`, `inGameOver`, and `mustHitSection`. The last is derived from native FocusCamera events, because V-Slice has no Psych `mustHitSection` chart sections.

## Differences from Psych Engine

Song scripts can go in `data/songs/<song-id>/`, such as `data/songs/black-knife/knightscript.luap`. The loader can match `Black-Knife` to `black-knife` if there is only one matching folder. Images and audio have the same fallback, but it's better to fix the capitalization in your files.

`addCharacterToList(id, role)` preloads a V-Slice character. `triggerEvent('Change Character', role, id)` changes the character and health icon. Use `bf`/`boyfriend`/`0`, `dad`/`1`, or `gf`/`2` for the role. The character needs V-Slice JSON and its assets; Psych character JSON isn't converted by these calls.

You can use `curCharacter`, `imageFile`, and `healthColorArray`. Set `isCameraOnForcedPos` to keep FocusCamera events from overriding your scripted camera position.

Sprites made from a current Sparrow character's `imageFile` reuse its frames and animation names, which is useful for ghost trails. Animate and MultiAtlas characters aren't converted to Sparrow sprites.

Adding the Lua API doesn't make a whole Psych mod work unchanged. Songs, characters, stages, events, note styles, and assets still need to work with V-Slice. Scripts that access Psych-only class fields will need changes too.

- `boyfriend`, `dad`, `gf`, `camGame`, `camHUD`, `camOther`, `camFollow`, `notes`, `unspawnNotes`, `playerStrums`, `opponentStrums`, and `strumLineNotes` refer to V-Slice objects. Receptor indexes are 0–3 for the opponent and 4–7 for the player. Active-note indexes can change between frames.
- Holds use continuous trails, not separate sustain sprites. While a hold is being hit, note callbacks run at step intervals with `isSustainNote = true`.
- `texture`, `noteSplashTexture`, `antialiasing`, `ignoreNote`, `hitCausesMiss`, `missHealth`, `hitHealth`, and `noteSplashDisabled` work with the group/property helpers. Settings made before a note spawns are applied to its sprite, without carrying over to other notes when that sprite is reused.
- `ignoreNote` removes miss and dropped-hold penalties. Players can still hit the note, but botplay skips it. `hitCausesMiss` takes away the amount in `missHealth` when hit; zero is allowed.
- Custom note heads use Sparrow atlases. Hold frames use `<color> hold piece` and `<color> hold end` prefixes; purple also accepts Psych's legacy `pruple end hold` name. The first numerically sorted frame is used for each body and cap; animated hold textures are not supported. Trimmed frames keep their offsets, and missing hold frames leave the native trail in place. For the `pixel` note style, Psych pixel sheets go in `images/pixelUI`: four columns and five rows for the notes, four columns and two rows for `nameENDS.png`. Both formats convert to continuous holds without changing V-Slice's hold timing or scoring.
- `noteSplashTexture` supports legacy Psych Sparrow splash atlases, with names such as `note splash purple1`. If the atlas is missing, the game keeps the normal splash and logs a warning. Advanced Psych 1.0 splash settings aren't converted.
- `triggerVSliceEvent` takes a V-Slice event's values as an object. `triggerEvent` passes Psych's `value1` and `value2` to Lua callbacks. Not every built-in Psych event has an implementation.
- `.hxc` modules still use FNF's HScript system. `runHaxeCode` uses Iris separately for each Lua script. Lua cross-script calls don't call `.hxc` modules.
- `camOther` is the cutscene camera. Character animation names and the game's default cameras keep their V-Slice names.
- `saveFile`, `deleteFile`, and directory helpers stay inside your mod folder, even with an old absolute-path flag.
- Psych achievements, dialogue JSON, FlxAnimate-specific Lua helpers, rating overrides, and Psych-only class fields aren't supported here. Use V-Slice's systems or adjust the script.

Use `isLuaFunctionSupported('callbackName')` to check whether an API function is available. The registered names and signatures are in `source/funkin/modding/psychlua/PsychLuaAPI.hx`.

## Credits

Based on the Lua API from Psych Engine 1.0.4 by Shadow Mario, RiverOaken, and contributors, adapted for LuaSlice and V-Slice. Psych Engine's Apache-2.0 license is in `licenses`.

FNF, LuaJIT, hxluajit, hxluajit-wrapper, and Iris keep their original credits and licenses.
