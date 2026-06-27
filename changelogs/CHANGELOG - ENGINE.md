# LuaSlice Engine Changelog

All important LuaSlice engine changes are tracked here.
I'm making it as simple, professional, FNF style. (non-AI)

# Scroll down to see Versions

---

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

---

## [0.0.4] - 2026-06-27

### Added

- Added `configureLuaPauseMenu({...})` so Lua can edit built-in pause items, hide items, add custom entries, and change item positions.
- Added `setLuaPauseMenuItem(matchOrId, label, position, target, hidden)` for simple base/custom pause menu edits.
- Added pause menu targets for `resume`, `restartSong`, `changeDifficulty`, `practiceMode`, `exitToMenu`, `options`, `callback`, and custom `.hx/.hxc` state classes.
- Added pause-opened Options support so Lua can hide the Options `EXIT` item and control where exiting Options goes.
- Added a configurable Lua pause menu shortcut example.
- Added `initLuaShader(name)` for loading a shader by name.
- Added `setShaderOnSprite(sprite, tag)` for simple sprite shader assignment.
- Added `getLuaSave(key, fallback)` and `setLuaSave(key, value)` for persistent Lua data.
- Added Freeplay, Story Menu, and Results Lua hooks.
- Added `-DFEATURE_LOGGER` for cleaner live Lua script/error/variable logging during dev builds.
- Added `-DNO_LUA` as a simple way to build LuaSlice without Lua support.
- Added `setLuaPauseOptions(howExit)` so pause-opened Options return behavior is set through a clear API instead of item config fields.
- Added pause item config so targets like Options can have pause-only behavior without changing the normal menus.
- Added timestamped build logs under `BuildLogs/<target>/` so new logs do not overwrite older ones.
- Added one naming pattern for build logs: `BuildLogs/<target>/log-<target>build-YYYY-MM-DD-HH-MM-SS[-label].txt`.
- Added a Save Data Options page for clearing all data, song data, options, or controls separately.
- Added an Android Unlimited FPS option for displays that report support above 60 Hz.

### Changed

- Updated the main menu version text to `V-slice: v0.8.5 | LuaSlice: v0.0.4`.
- Reworked Lua shader helpers so simple scripts can use `initLuaShader`, `makeLuaShader`, `setLuaShader`, or `setShaderOnSprite`.
- Reworked Lua error popups so useful suggestions show in the popup, not only in the report file.
- Made the Lua API default for normal native builds, so `lime build windows` and `lime test windows` include it without extra defines.
- Changed `-DFEATURE_LOGGER` builds to output under `export/logger`.
- Updated the pause menu example so custom item ids can target actions like `practiceMode`, `restartSong`, or `options`.
- Updated the example Modifiers options page with health drain and watermark controls.
- Replaced the old pause add/hide example with a config-based `.luag` example.
- Reworked pause menu config so scripts can define it once and LuaSlice applies it whenever the pause menu opens.
- Added an isolated `.lua` pause shortcut example beside the `.luag` copy so global hook conflicts cannot hide the Options entry.
- Added the missing example script folders to `mod-example`.
- Added simple menu and shader example scripts to `mod-example`.
- Updated the health drain example so it stops draining while the player is singing.
- Updated example scripts to use the simpler pause/menu/shader helper functions.
- Replaced the old Options-only pause example with a target-based pause menu example.
- Organized engine changelogs into `changelogs/`.
- Organized build logs into `BuildLogs/<target>/`.
- Organized extra/source packaging files into `other/`.
- Organized icon and art files under `art/` and `art/icons/`.
- Organized setup docs under `docs/setup/`.
- Kept the example mod package at `example_mods/mod-example.zip` and removed the old RAR package.
- Restored Android as a playtest target after fixing the startup and orientation problems.
- Made the Android forced-landscape patch run from the project postbuild step, so it survives clean Android exports.

### Fixed

- Fixed returning from Main Menu targets resetting selection back to Story Mode.
- Changed Android package/save branding from Funkin defaults to LuaSlice branding, using Fla-man-OFFICIAL for save path and LuaSlice for company/app metadata.
- Fixed Lua table conversion so reading mixed/sparse tables does not corrupt Lua iteration or drop numeric entries.
- Fixed Lua-created objects not being destroyed outside PlayState during reload/cleanup.
- Fixed F5 hot reload being able to run twice in the same frame.
- Fixed duplicate Lua main menu items leaving old sprites behind.
- Fixed Lua option pages being able to collide with built-in Options pages.
- Fixed Lua shader camera filters stacking when reapplied.
- Fixed Lua note payload fields turning null values into the string "null".
- Hardened Lua number argument reads so non-number values fall back safely.
- Fixed Lua pause menu config positions so very low values clamp to the top and very high values clamp to the bottom.
- Cleaned up PlayState Lua folder reload rules so F5 keeps `scripts/lua`, `scripts/luag`, menu, and options behavior consistent.
- Fixed pause menu config only working during the pause hook instead of from normal script setup.
- Hardened the pause shortcut example so it reapplies config from `onCreate`, `onReload`, and `onPauseMenuCreate`.
- Fixed pause-opened Options leaving keyboard input disabled, which broke retry and back controls after returning or dying.
- Updated Lua error-window suggestions for v0.0.3-v0.0.4 APIs, including pause menu, options, menus, shaders, reload, and event APIs.
- Fixed Lua error suggestions being hidden from the popup even when the report had one.
- Fixed missing direct API bindings for the simple shader helper names.
- Improved Lua error popups so FPS/memory warnings only show for hooks that can spam errors, while reports still use `None` when no useful suggestion exists.
- Moved Android build/runtime logs into `BuildLogs/android` and kept the clean log split into `# Info` and `# Error/s`.
- Updated project paths for organized `other`, `changelogs`, and `art/icons` folders.
- Fixed hold-cover cleanup/reuse so recycled sustain notes do not keep stale cover links or crash when a cover ends without a valid hold note.
- Fixed pause-opened Options hiding `EXIT` leaking into normal Main Menu Options.
- Removed noisy per-frame perf spam from the Lua logger.
- Simplified the pause Options example so it only adds the Lua Options shortcut instead of replacing the whole pause menu.
- Updated the pause Options example to configure the pause-opened Options screen directly with `hideExit` and `howExit`.
- Verified the Windows Lua-enabled build still compiles after the latest fixes.
- Verified the Windows build after removing the Android export folders.
- Fixed Android startup crashes caused by early mobile rendering and asset loading paths.
- Fixed Android main menu rendering so late or missing menu graphics do not crash the app.
- Fixed Android Freeplay backcard loading so missing bitmap data does not kill the state.
- Fixed Android packaging so the APK uses fixed landscape orientation.
- Verified the Android APK installs, opens, plays music, and reaches the main menu in landscape.
- Fixed Android/emulator menu input being blocked when an external input device is detected.
- Hardened Android song audio loading so failed instrumental or vocal loads log cleanly instead of breaking PlayState.
- Fixed Stage Editor `.fnfs` zip loading for asset names with dots in the filename.
- Fixed Stage Editor animated object exports saving stale animation data after replacing or failing to add an animation.
- Fixed Stage Editor animated object JSON ordering so saved animations follow the real animation list.
- Fixed Stage Editor animation editing so graphic/frame/animation changes mark the stage as unsaved.
- Hardened Stage Editor object loading against missing animation fields, missing bitmap entries, and null offsets.
- Fixed the Android x86_64 Lime/SDL Java mismatch that caused an immediate startup crash in the emulator.
- Reduced Android-only menu and Freeplay rendering costs without changing desktop visuals.
- Fixed Android Unlimited FPS freezing the app by replacing the invalid zero-rate path with a safe high software ceiling.
- Removed the unintended built-in Options entry from the pause menu; Lua scripts can still add one when requested.
- Made the pause Options example opt-in so installing `mod-example` does not change the pause menu by default.
- Fixed Android Open Data Folder to open LuaSlice's external data directory through the system file picker.
- Updated Android Unlimited FPS detection to check all refresh rates supported by the display and hide the option on 60 Hz-only devices.
- Hardened Stage Editor stage and animated-object loading against missing props, scroll values, and animation arrays.
- Verified the Android title screen, main menu, Options, Freeplay, gameplay, and improved FPS in the emulator.
- Verified the Windows Stage Editor build after the latest fixes.
- Verified final Android and Windows builds with Save Data Options, refresh-rate detection, ZIP-only examples, and the Open Data Folder fix.
- Fixed Clear Songs Data leaving Story Mode level and Tutorial scores behind while only clearing Freeplay scores.
- Fixed Main Menu input remaining active during item transitions, which allowed another item to be selected before the first transition finished.
- Fixed Android launcher icons so builds use `art/icons/builds/android/IconAndroid.png` instead of expecting a missing adaptive-icon resource pack.

## [0.0.3] - 2026-06-18

### Added

- Added a cleaner Lua manager layer for options, menus, shaders, and Lua error windows.
- Added real Lua Options menu support, including saved checkboxes and page positioning.
- Added Lua main menu support so scripts can insert real main menu entries and open base game menus or custom `.hx/.hxc` states.
- Added Lua image menu helpers for simple custom menu layouts.
- Added `mod-example.zip` alongside the RAR example package for easier sharing.

### Changed

- Updated the main menu version text to `V-slice: v0.8.5 | LuaSlice: v0.0.3`.
- Reworked the Lua support notes into `CHANGELOG - ENGINE.md` so the API list and engine changes live in one place.
- Improved Lua error reports with cleaner Lua-only formatting, source file lists, and practical suggestions.

### Fixed

- Fixed Lua hot reload so F5 and `reloadLuaScripts()` both rescan scripts safely.
- Fixed Lua API errors from bad fields, missing optional event fields, broken hooks, and unsafe reflection calls.
- Fixed Lua-created objects not always cleaning up correctly after reloads or script errors.
- Fixed menu and options Lua scripts loading in PlayState instead of only in their matching menus.
- Fixed Lua main menu entries with bad atlases or custom state targets failing too hard.
- Fixed Lua error reports so they show script line numbers when Lua provides them.
- Reduced repeated Lua error popups so bad scripts do not keep hurting FPS or memory.
- Improved Lua error popup wording so it clearly says which script file needs fixing.
- Fixed title screen cleanup and reduced extra work during title/menu updates.

## [0.0.2] - 2026-06-17

### Added

- Added direct Lua scripting support through hxlua.
- Added `.lua` isolated scripts.
- Added `.luag` global scripts.
- Added F5 Lua hot reload in PlayState.
- Added `reloadLuaScripts()` for hot reload from Lua.
- Added Lua error popup windows instead of hard crashes.
- Added Lua crash/error reports in `logs/lua`.
- Added safer `setEventField()` behavior so bad fields do not break the engine.
- Added more example scripts to `mod-example.rar`.
- Added LuaSlice credits:
  - `Fla-man_OFFICAL`

### Changed

- Documented how the engine finds and loads `.lua` and `.luag` scripts.
- Renamed `All the things Supported - Engine.txt` to `Lua API Support - Engine.txt`.
- Made the Lua support document more professional.
- Changed the main menu version text for LuaSlice.

### Removed

- Removed the visible `Login to NG` option from the options menu.

### Fixed

- Fixed several Lag Adjustment / Offset Calibration bugs.
- Fixed the first calibration notes not appearing correctly.
- Fixed broken Lua scripts being able to hard-crash the game in more cases.

## [0.0.1] - 2026-06-16

### Added

- Started LuaSlice as a V-Slice `v0.8.5` engine fork.
- Added the first LuaSlice source/package cleanup work.
- Added the first Lua API planning notes.



