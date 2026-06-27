# LuaSlice
I added Lua Support to V-slice. I don't know what to add mor-

You can download the LuaSlice Versions Here:
- [Versions](https://github.com/Fla-man-Max/LuaSlice/releases)
- [Source Code](https://github.com/Fla-man-Max/LuaSlice)
- [Gamebanana](https://gamebanana.com/tools/23050)

## Lua API Support

### Script Types

- `.lua` scripts are isolated. They get private script environments.
- `.luag` scripts are global. They share globals with other global Lua scripts.
- Both script types can use the Lua API.
- `.luag` is best for shared helpers and compatibility modules.
- Lua support is enabled by default on native C++ builds, including normal `lime build windows` and `lime test windows`.
- Use `-DNO_LUA` to build without Lua support.

### Script Load Folders

LuaSlice looks for scripts in these places:

- `mods/global.lua`
- `mods/global.luag`
- `mods/scripts/global.lua`
- `mods/scripts/global.luag`
- `mods/scripts/*.lua`
- `mods/scripts/*.luag`
- `mods/scripts/freeplay/*.lua`
- `mods/scripts/freeplay/*.luag`
- `mods/scripts/story/*.lua`
- `mods/scripts/story/*.luag`
- `mods/scripts/results/*.lua`
- `mods/scripts/results/*.luag`
- `mods/scripts/song-SongId.lua`
- `mods/scripts/SongId.lua`
- `mods/scripts/stage-StageId.lua`
- `mods/scripts/StageId.lua`
- `mods/scripts/stages/StageId.lua`
- `mods/SongId/script.lua`
- `mods/SongId/scripts/song.lua`
- `mods/stages/StageId.lua`
- `mods/<mod name>/global.lua`
- `mods/<mod name>/global.luag`
- `mods/<mod name>/script.lua`
- `mods/<mod name>/script.luag`
- `mods/<mod name>/scripts/global.lua`
- `mods/<mod name>/scripts/global.luag`
- `mods/<mod name>/scripts/song-SongId.lua`
- `mods/<mod name>/scripts/SongId.lua`
- `mods/<mod name>/scripts/stage-StageId.lua`
- `mods/<mod name>/scripts/stages/StageId.lua`
- `mods/<mod name>/songs/SongId/script.lua`
- `mods/<mod name>/data/songs/SongId/script.lua`
- `mods/<mod name>/stages/StageId.lua`
- `mods/<mod name>/script/*.lua`
- `mods/<mod name>/script/*.luag`
- `mods/<mod name>/scripts/*.lua`
- `mods/<mod name>/scripts/*.luag`
- `mods/<mod name>/scripts/freeplay/*.lua`
- `mods/<mod name>/scripts/freeplay/*.luag`
- `mods/<mod name>/scripts/story/*.lua`
- `mods/<mod name>/scripts/story/*.luag`
- `mods/<mod name>/scripts/results/*.lua`
- `mods/<mod name>/scripts/results/*.luag`

Folder rule:

- `scripts/lua` loads `.lua` only.
- `scripts/luag` loads `.luag` only.
- `scripts/menu` loads on the Main Menu only.
- `scripts/options` loads in the Options menu only.
- `scripts/pause` loads in PlayState and can configure the pause menu when it opens.
- `scripts/freeplay` loads in Freeplay.
- `scripts/story` loads in Story Menu.
- `scripts/results` loads in Results.
- F5 reloads PlayState Lua from normal gameplay folders, including modules, gameplay, player/opponent, songs, stages, characters, events, notekinds, shaders, dialogue, levels, pause, lua, and luag folders.
- Other script folders can load both `.lua` and `.luag`.

### Require Paths

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

### Hot Reload

- F5 reloads Lua scripts in PlayState.
- `reloadLuaScripts()` safely requests the same reload from Lua.
- Reload rescans mod folders, so added or removed `.lua` and `.luag` scripts update.
- `onReload()` is called after scripts reload.
- Script-created sprites, text, sounds, tweens, timers, menus, shaders, and objects are cleaned up before reload.

### Simple Helpers

These are small wrappers for common Lua work:

- `addLuaMainMenu(id, position, target, assetPath, animName)` adds a main menu item.
- `makeLuaMenuSimple(id, items, x, y, spacing)` creates a simple text menu.
- `makeLuaImageMenuSimple(id, items, x, y, spacing)` creates a simple image menu.
- `initLuaShader(name)` loads a shader by name and uses that name as the tag.
- `initLuaShader(name, tag)` loads a shader by name and stores it under a custom tag.
- `makeLuaShader(tag, path, vertexPath)` creates a shader from a fragment path/source and optional vertex path/source.
- `setLuaShader(tag, target)` applies a shader to a Lua object or engine path.
- `setShaderOnSprite(sprite, tag)` applies a shader to a sprite using sprite-first argument order.
- `setLuaCameraShader(tag, camera)` applies a shader to a camera.
- `getLuaSave(key, fallback)` and `setLuaSave(key, value)` store Lua data in the game save.

Options still use the normal simple option API: `createLuaOptionPage`, `addLuaCheckbox`, `addLuaNumber`, and `addLuaEnum`.

### Advanced Helpers

- Pause menu items are added/edited with `configureLuaPauseMenu({ items = {...} })`.
- Pause menu item targets: `resume`, `restartSong`, `changeDifficulty`, `practiceMode`, `exitToMenu`, `options`, `callback`, or a custom `.hx/.hxc` state class.
- Pause menu targets can use per-item config, such as `options = { hideExit = true, howExit = "BackToSong" }` for the pause-opened Options screen.
- `setLuaPauseOptions(howExit)` controls where pause-opened Options goes when backing out.
- Freeplay hooks:
  - `onFreeplayCreate()`
  - `onFreeplayUpdate(elapsed)`
  - `onFreeplayClose()`
- Story Menu hooks:
  - `onStoryCreate()`
  - `onStoryUpdate(elapsed)`
  - `onStoryClose()`
- Results hooks:
  - `onResultsCreate()`
  - `onResultsUpdate(elapsed)`
  - `onResultsClose()`
- These screen hooks load from `scripts/freeplay`, `scripts/story`, and `scripts/results`.

### Lua Error Reports

- Lua errors write reports to `logs/lua`.
- Error windows show script path, hook/API name, line number when Lua provides it, report path, and the error text.
- Suggestions show in the popup when LuaSlice knows a likely fix.
- If there is no useful suggestion, reports say `Suggestions: None`.
- Per-frame hook errors show a warning when repeated errors could hurt FPS or memory.

### Dev Logger

- `-DFEATURE_LOGGER` enables LuaSlice's live Lua logger.
- Example: `lime test windows -DFEATURE_LOGGER`.
- Logger builds still include the Lua API by default unless `-DNO_LUA` is also passed.
- Logger output includes loaded Lua script lists, Lua errors, and simple variable logs.
- Logger builds output to `export/logger/<target>/bin`.
- The normal Windows build keeps `FEATURE_LOGGER` disabled and outputs to `export/release/<target>/bin`.

### Supported API Areas

- Core helpers: `require`, JSON, text files, random numbers, keyboard input, mouse input.
- PlayState/song: song position, beat, step, section, song id/name, difficulty, variation, stage id, playback rate, scroll speed, health, score, combo, tallies, accuracy, botplay, practice mode, countdown, restart, end song, vocals volume.
- Events: create, reload, update, step, beat, section, destroy, countdown, song start/end, pause/resume, game over, note hit/miss, ghost miss, hold drop, note incoming, song events, retry, key up/down, focus, state/substate, dialogue.
- Live event editing: current event access, event fields, event canceling, propagation control.
- Notes: note payloads, strum time, direction, kind/noteData, raw note object access.
- Strumlines: player/opponent strumlines, position, alpha, visible, receptor positions, receptor animations, note splashes, scroll speed.
- Characters: boyfriend, dad, girlfriend, health icons, animations, raw fields and methods.
- Stage: current stage, stage props, stage characters, camera zoom, raw stage access, PlayState object insertion, z-index refresh.
- Sprites: static sprites, Sparrow sprites, solid sprites, cameras, position, scale, size, alpha, visibility, angle, color, velocity, acceleration, scroll factor, zIndex, screen centering, kill/revive, animations.
- Text/HUD: FlxText creation, formatting, HUD camera, score text, health bar, combo popups, icons.
- Cameras: flash, fade, shake, zoom, alpha, background color, visibility, position, follow point, camera bop, reset, tween zoom, tween position, cancel camera tweens.
- Audio: tagged sounds, music controls, vocals, volume controls, raw `FlxG.sound` access.
- Tweens/timers: tagged tweens, X/Y/alpha/angle aliases, canceling, timers, completion hooks.
- Custom options: `LuaOptionManager` makes Lua options easier, cleaner, and less complex.
- Custom menus: `LuaMenusManager` can make Lua menus, insert real main menu entries, configure pause menu items, and open base menus or custom `.hx/.hxc` state classes.
- Shaders: `LuaShaderManager` makes shaders easier to load, apply, and un-apply from Lua.
- Lua save data: persistent Lua values through `getLuaSave` and `setLuaSave`.
- Menu hooks: Freeplay, Story Menu, and Results scripts can run create/update/close hooks.
- Lua logger: `-DFEATURE_LOGGER` enables cleaner live Lua logging for scripts, errors, and simple variable logs.
- Raw bridge: `getProperty`, `setProperty`, `callMethod`, static access, arrays, stored objects, object creation/destruction.

### Current Limits
- HTML5 does not use hxlua. | Never.
- `-DNO_LUA` disables Lua support for builds that need it.