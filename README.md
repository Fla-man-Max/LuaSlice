# LuaSlice
I added Lua Support to V-slice. I don't know what to add mor-

You can download the LuaSlice Versions Here:
- [Versions](https://github.com/Fla-man-Max/LuaSlice/releases)
- [Source Code](https://github.com/Fla-man-Max/LuaSlice)

# Lua API (More Will be added)

### Script Types

- `.lua` scripts are isolated. They get private script environments.
- `.luag` scripts are global. They share globals with other global Lua scripts.
- Both script types can use the Lua API.
- `.luag` is best for shared helpers and compatibility modules.

### Script Load Folders

LuaSlice looks for scripts in these places:

- `mods/global.lua`
- `mods/global.luag`
- `mods/scripts/global.lua`
- `mods/scripts/global.luag`
- `mods/scripts/*.lua`
- `mods/scripts/*.luag`
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

Folder rule:

- `scripts/lua` loads `.lua` only.
- `scripts/luag` loads `.luag` only.
- `scripts/menu` loads on the Main Menu only.
- `scripts/options` loads in the Options menu only.
- `scripts/pause` loads in PlayState and can configure the pause menu when it opens.
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

These are small wrappers for common menu/shader work:

- Pause menu item targets: `resume`, `restartSong`, `changeDifficulty`, `practiceMode`, `exitToMenu`, `options`, `callback`, or a custom `.hx/.hxc` state class.
- Pause menu items are added/edited with `configureLuaPauseMenu({ items = {...} })`.
- `addLuaMainMenu(id, position, target, assetPath, animName)` adds a main menu item.
- `makeLuaMenuSimple(id, items, x, y, spacing)` creates a simple text menu.
- `makeLuaImageMenuSimple(id, items, x, y, spacing)` creates a simple image menu.
- `makeLuaShader(tag, path)`, `setLuaShader(tag, target)`, and `setLuaCameraShader(tag, camera)` wrap common shader setup.

Options still use the normal simple option API: `createLuaOptionPage`, `addLuaCheckbox`, `addLuaNumber`, and `addLuaEnum`.
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
- Shaders: `LuaShaderManager` makes shaders easier to apply and un-apply from Lua.
- Raw bridge: `getProperty`, `setProperty`, `callMethod`, static access, arrays, stored objects, object creation/destruction.

### Current Limits
- HTML5 does not use hxlua. | Never.
