# LuaSlice Engine Changelog

All important LuaSlice engine changes are tracked here.
I'm making it as simple, professional, FNF style. (non-AI)

# Scroll down to see Versions

---

## [0.0.5] - 2026-07-12

### Added

- Added a `Psych Engine (V1.0.4)` Chart Editor importer for notes, sustains, BPM changes, characters, stages, note types, embedded events, and companion `events.json` files.
- Added a macOS GitHub Actions workflow that builds both the iOS Simulator app and an unsigned ARM64 IPA for physical iPhones. The Windows batch file starts the build and downloads both artifacts automatically.
- Added a working Downscroll view to the Chart Editor, including notes, hold notes, events, grid navigation, playhead controls, measure markers, and the note preview.
- Added `Change Stage`, which replaces the active stage and loads its JSON, scripts, shaders, character positions, and camera data.
- Added `Change Character`, which replaces the Player, Opponent, or Girlfriend and loads matching `.lua`, `.luag`, `.hx`, and `.hxc` character scripts when the event runs.
- Added Chart Editor icons for `Change Stage` and `Change Character` events.
- Added optimized Lua helpers for namespaced sprite, camera, debug, property, save, shader, script, timer, song, and event usage.
- Added batch property updates and cached property refs so scripts can avoid repeated string-path work in `onUpdate`.
- Added lazy event helpers like `song.atBeat`, `song.atStep`, `event.on`, and `event.once` so scripts can use event-based logic instead of polling every frame.
- Added a Performance tab in Options.
- Added a song shader toggle for stage and character shaders.
- Added Low Quality modes: `None`, `Minimal`, and `Max`.
- Added a live Lua API registry with `LuaSlice.api.list`, `LuaSlice.api.find`, `LuaSlice.api.docs`, and `LuaSlice.api.writeDocs`.
- Added Lua group/layer helpers so scripts can organize sprites and apply shared alpha, layer, property, and tween changes.
- Added `LuaSlice Lua API.md` as a full Lua API reference beside the engine changelog.
- Added safer namespaced helpers for window titles, characters, stages, options, tween pause/resume, camera tweens, beat ranges, script information/control, shader checks, and table-configured option pages.

### Changed

- Updated the main menu and Lua API version to `0.0.5`.
- Moved FPS, Unlocked/Unlimited FPS, VSync, Debug Display, and Debug Display BG from Preferences into the Performance page.
- Removed unused and unnecessary development assets and images to reduce the release size.
- Successful builds now create a timestamped summary and print `Build Log located at: PATH` when they finish.
- Optimized Chart Editor redraws by reusing render lists, avoiding unchanged HaxeUI updates, and skipping repeated event-icon and sorting work. (Paused around 800~ FPS, while song playing around 630~700.)
- Updated the optional pause Options example to return to the song through `howExit` without hiding the Options `EXIT` item.
- Optimized Lua hook dispatch so isolated `.lua` hooks are cached when scripts load, and unused hooks are skipped instead of being searched every call.
- Updated `mod-example.zip` with examples for save, debug, property refs, event helpers, timers, and namespaced shader usage.
- Low Quality `Minimal` now trims heavier Freeplay UI, disables song shaders, hides HUD icons, and culls fully off-camera stage sprites during gameplay.
- Low Quality `Max` now hides the health bar, combo numbers, hold covers, extra Freeplay decorations, and the rare alternate pause route.
- Updated `mod-example.zip` with clearer optimized API and Performance Options examples.
- Low Quality `Max` now keeps the DJ background/backcard visible like `Minimal`.
- Low Quality `Max` now keeps rating popups such as `Sick` and `Good`, while still hiding combo numbers.
- Updated `mod-example.zip` with a group/layer/API docs example.
- Updated `mod-example.zip` with an example covering the latest safe API helpers.

### Fixed (From V0.0.5 and Before)

- Fixed Android Unlimited FPS appearing inconsistently and only changing LuaSlice's software cap without requesting the display's highest supported refresh mode.
- Replaced the mobile Save Data Options `EXIT` list item with the normal touch back button.
- Fixed Nene's A-Bot visualizer being hidden by Low Quality off-screen culling and made Char Select reconnect its music analyzer reliably.
- Reworked Player and Opponent Preview bounds for regular, pixel, spritesheet, and atlas characters. Idle and active animations are measured once, cached, and added to a stable envelope that preserves animation offsets without rescanning every frame.
- Fixed `Change Stage` support for Erect stages by fully unloading the old stage, creating a fresh scripted stage, clearing stale shaders, and rerunning the new stage's `.hxc` setup and character positioning.
- Fixed broken stage or character scripts repeatedly opening error windows. Invalid scripts are skipped and scripted characters/stages fall back to their data implementation when possible.
- Fixed failed global `.luag` files leaving partially registered hooks active.
- Fixed stage and character changes not resetting correctly after restarting or reloading Lua with F5.
- Fixed Nene's A-Bot support objects and visualizer not attaching or initializing when `Change Character` replaces Girlfriend mid-song.
- Fixed pausing after repeated character changes crashing when pause music could not allocate or load.
- Fixed Chart Editor Playtest's `Enable Song Scripts` only controlling `.hxc`; it now also controls song-scoped `.luag` scripts without adding `.lua` to the toggle.
- Fixed saved Chart Editor Downscroll reopening with an upscroll waveform and note overview.
- Fixed shader cleanup failing Windows compilation because of Haxe null-safety checks.
- Fixed oversized and unreliable mobile Main Menu touch boxes by matching touches against the rendered menu artwork on Android and iOS.
- Fixed Android Preferences touch checks after scrolling and stabilized Unlimited FPS visibility by caching the device's maximum supported refresh rate.
- Fixed Downscroll cursor placement snapping one note-snap level too early.
- Fixed multi-note mouse dragging reusing the previous drag offset.
- Fixed Lua shader application still being allowed in PlayState when song shaders are disabled by Performance settings.
- Fixed Freeplay becoming stuck after Low Quality hid objects before the Freeplay intro finished setting up input.
- Fixed the Performance tab becoming hard to navigate when Low Quality disabled the Shaders row.
- Fixed Low Quality `Max` still allowing note splashes.
- Fixed Low Quality `Max` Freeplay album art, album titles, stars, highscore digits, and clear percent being able to reappear after later Freeplay updates.
- Fixed Low Quality `Max` Character Select still showing the crowd and nametag while keeping the character/GF visualizer visible.

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
