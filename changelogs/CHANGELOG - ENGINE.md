# LuaSlice Engine Changelog

Important LuaSlice engine updates are tracked here.
I'm making it as simple, professional, FNF style. (non-AI!!)

## [0.0.8] - 2026-08-23 | Funkin v0.8.6 Port

### Changed

- Ported LuaSlice to Funkin v0.8.6, and added and removed some stuff.

## [0.0.7] - 2026-07-29 | Story Mode and Chart Editor Bugfixes

### Added

- Added the Animation Editor. Made by the Nova Utils Team.
- Added the Level Editor. Made by the Nova Utils Team.
- Added a Automatic update system before the title intro when a newer LuaSlice version comes out.
- Added a Stage Editor conversion window for converting stage layout data between the Base Game, Psych Engine v1.0.4, and Codename Engine.
- Added support for Base Game `.fnfs` packages and JSON, Psych Engine JSON, and Codename Engine XML stage files in the converter.
- Added a Middle Scroll gameplay preference that centers the Player strumline and splits the Opponent notes along the sides.
- Added a one-click Windows setup and build batch file that installs everything you need to build the engine, before running `lime test windows`.

### Changed

- Improved Lag Adjustment with precise input timestamps, outlier-resistant averaging, and rounded final calibration values.
- Reworked gameplay input handling so keyboard, controller, and touch presses and releases are processed in their original timestamp order.
- Moved judgement ratings and combo numbers farther right when Middlescroll is enabled on desktop, or when Strumline Background is between 90% and 100% on all builds.
- Split the Opponent strumline background across its left and right lanes when Middlescroll is enabled.
- Replaced the unreleased trace only GitHub version check with an in-game release check that quietly continues when offline.
- Updated the main menu and Lua API version to `0.0.7`.

### Fixed

- Fixed Retry and F5 HUD-effect resets making Middlescroll Opponent receptors and notes fully opaque instead of restoring their 90% visibility.
- Fixed large mod textures causing gameplay audio to buffer-loop and song progression to stall when memory optimization ran immediately after playback began.
- Fixed duplicate bindings and keyboard, controller, and touch source-ID collisions causing lost, repeated, or mismatched inputs.
- Fixed fast inputs judging against the current frame instead of the input's actual song position, and made stacked note selection favor the closest valid note.
- Fixed input offset compensation being applied inconsistently to early inputs.
- Fixed normal and Chart Editor options reverting because a repeated save load could leave the active preferences attached to an outdated save object.
- Restored the original mobile HUD positions for the health bar, health icons, score, subtitles, ratings, and combo numbers.
- Restored the Freeplay rank glow, colored trail, and vignette after completing a song on Android.
- Fixed Shader events failing for animated fragment shaders, scripted HXC shader updates, `_amount` uniforms, case-sensitive shader names, and the Remove Existing Shaders option.
- Fixed rapid multi-touch Hitbox input leaving mobile strumline receptors falsely pressed or retriggering duplicate press animations.
- Fixed Chart Editor auto-save only counting from the first edit instead of restarting after each new change.
- Fixed Chart Editor metadata, BPM, time-signature, difficulty, audio-offset, and Freeplay-preview changes not consistently activating auto-save.
- Fixed a failed Chart Editor backup clearing the unsaved state instead of keeping the chart dirty and scheduling another auto-save attempt.
- Fixed a fatal crash in the Chart Editor when importing or loading `.mp3` files due to waveform generation failure.
- Fixed a fatal crash on Mobile devices when single or double-clicking notes and events in the Chart Editor.
- Fixed the Chart Editor Auto-Save preferences having overly restrictive minute bounds and failing to update the timer in some cases.
- Fixed Story Mode rejecting weeks that use only one or two custom difficulties instead of Easy, Normal, and Hard.
- Fixed Story Mode selecting an invalid remembered difficulty when changing to a week with a different difficulty list.
- Fixed the mobile Chart Editor requiring mouse hover to open Mirror Notes, Note Snapping, and Live Input Mode.
- Fixed Live Input Mode touch selections not reliably updating the active input style.
- Fixed F5 bypassing the Chart Editor reload path and failing to hot-reload a PlayState opened as a Chart Editor playtest substate.
- Fixed F5 only rescanning Lua scripts during normal gameplay instead of reloading the current song and its assets.
- Fixed note splashes being shifted left by an extra half-sprite offset.
- Fixed the Chart Editor character selector crashing when a character has a missing or invalid animated Freeplay icon.
- Fixed the Chart Editor character selector opening below the health icons and becoming hidden while using Downscroll.
- Fixed the Stage Editor converter accepting files that do not match the selected source engine.
- Fixed the Stage Editor Test Stage button being blocked by its own UI focus.
- Fixed the mobile Hitbox layout removing the press and release events required to hit notes.
- Repositioned and resized the mobile Hitbox layout into a safe lower-screen touch pad, with the receptor line kept above it instead of overlapping the notes.
- Fixed mobile Hitbox touches lighting up without reaching the gameplay note input queue.
- Kept Freeplay difficulty names and dots visible in Minimal and Max low-quality modes while hiding the difficulty selector arrows.
- Fixed the split Opponent receptors and incoming notes staying at the top of the screen when using Downscroll with Middlescroll.
- Fixed the split Opponent strumline backgrounds not lining up with their receptor pairs.
- Fixed Chart Editor Instrumental, Player Vocals, Opponent Vocals, and playback-speed preferences sometimes being overwritten by temporary minimum UI values.
- Restored the glowing selected song text in Freeplay on Android. HAPPY LEN?? HUH???
- Replaced the broken mobile Hitbox layout with four full-screen touch lanes that keep the normal strumline and Up/Downscroll layout.
- Fixed mobile Arrow and Hitbox controls changing the gameplay strumline layout, and force Arrow controls while an external keyboard or controller is connected. ops
- Fixed Chart Editor audio, playback, note snapping, input mode, Downscroll, theme, hitsound, and subtitle preferences not saving immediately on mobile.
- Fixed the Difficulty toolbox Load Metadata, Load Chart, Save Metadata, and Save Chart buttons doing nothing on mobile.
- Added 0% to the mobile Hitbox Transparency range so its resting lanes can be completely invisible.
- Fixed the mobile Chart Editor Metadata toolbox crashing when opened before an instrumental was loaded.

## [0.0.6.5] - 2026-07-23 | Small Bugfix Update

### Added

- Added `.mp3` support when loading Chart Editor instrumentals and vocals, including the Psych Engine import flow.
- Added a Chart Editor Preferences submenu with an auto-save interval from 6 to 29 minutes.
- Added an enabled-by-default mobile preference for double-tap deletion of notes and events.

### Changed

- Updated the main menu and Lua API version to `0.0.6.5`.

### Fixed

- Fixed Chart Editor preferences such as theme, metronome, hitsound, audio, playback, Downscroll, and note settings not always being flushed when leaving or reloading the editor.
- Fixed Downscroll waveforms rendering in the wrong direction and bouncing with animated Player/Opponent icons.
- Fixed a Title Screen input bug reported by `that0neidiotgb` and `characterfilemissing` where rapid clicks could skip past the logo and GF screen.
- Fixed vocal lookup used by the Chart Editor and song loading failing to find valid unsuffixed Player, Opponent, and legacy vocal files when a variation-specific file was unavailable.
- Fixed Chart Editor Downscroll waveform and Player/Opponent icon alignment, keeping the icons above the playbar and each waveform connected to its matching icon.
- Fixed deleted Chart Editor events leaving stale sprite and tooltip references that could crash the game.
- Fixed the Chart Editor Preferences submenu requiring mouse hover on mobile; tapping it now opens the submenu.

## [0.0.6] - 2026-07-22 | planned from 2026-06-18 :sob:

### Added

- Added `Preload Resource` for images, sounds, music, characters, stages, stage objects, shaders, and dialogue data.
- Added `Play Audio` with actions for playing, resuming, changing volume, pausing, and stopping tagged audio.
- Added `Shader` support for applying and removing `.hxc` and `.frag` shaders, including multiple properties in one event.
- Added reusable Overlay and Blackout events with colors, gradients, images, animated atlases, cameras, blend modes, opacity, and fading.
- Added `Play Dialogue`, HUD Fade, Camera Flash, Camera Shake, and Stage Object Control as normal Chart Editor events.
- Added `Play Countdown`, which shows and plays the normal countdown without restarting or resyncing the song.
- Added `Return to Original Speed` to the Scroll Speed event.
- Added an approximate Overlay and Blackout preview to the Chart Editor event toolbox.
- Added a layered HUD Fade preview for the strumline, notes, health bar, and icons.
- Added dedicated Chart Editor icons for Play Audio, Shader, Blackout, Stage Object Control, and HUD Fade.
- Added `Create Solid Block` below Find Object in the Stage Editor. The block can be edited through Object Properties.
- Added native mobile Chart Editor support, accessible from `Options > Chart Editor`.
- Added number, whole-number, on/off, X/Y, and color controls for Shader event properties.
- Added `Health Drain` with persistent per-second Player/Opponent draining, amount `0` to stop, optional score changes, and a `Die?` toggle (visible when Player is selected) so health can drain without killing the player when disabled.
- Added target compatibility filtering for `Shader` events. Shaders can declare supported target types, camera targets, and character targets (or restrictions like `//@no-hud`), automatically hiding unsupported choices in the Chart Editor dropdowns.
- Added a mobile-only hot-reload button in the top-right corner of the Main Menu with a cyan tint and 60% resting opacity to trigger a state reload (F5).
- Added softcoded Lua state and substate opening for scripted and built-in state classes.
- Added object shader targets to the Haxe and Lua APIs, including `DropShadowShader` support for named stage objects.
- Added a Difficulty toolbox action for deleting a non-default variation and every difficulty inside it.
- Added a secret when there's an error with a script.
- Added Lua helpers for reading GC memory usage and temporarily hiding or restoring the built-in debug display.

### Changed

- Removed the `Pause Gameplay` option from `Play Dialogue` event settings.
- Reworked gameplay memory cleanup to release finished song audio and CPU-side copies of large textures without destroying live Flixel graphics.
- Updated the main menu and Lua API version to `0.0.6`.
- `Play Dialogue` now lists real conversation JSON entries, preloads its music and visuals, and releases them after the dialogue closes.
- `Shader` now lists both `.hxc` classes and `.frag` files, reads their uniforms, provides BF, Dad, and GF targets, and can ignore fully transparent sprite pixels.
- File-based events now use explicit paths, starting at `assets/` by default.
- F5 and song retries now clear event-created audio, shaders, overlays, dialogue, tweens, and timers before restoring the song.
- Centered the Chart Editor menu buttons.
- Renamed the HUD Fade `Receptors` label to `Strumline`.
- Changed HUD Fade duration to use beats so chart timing is easier to control.
- Replaced hex color text fields in the new Chart Editor events with color-wheel pickers.
- Changed event blend modes from text fields to a list of supported modes.
- Moved the layered HUD Fade preview assets into the shared Chart Editor HUD folder.
- Score text now fades with the health bar instead of using a separate HUD Fade target.
- Split Play Audio into an audio folder path and audio filename while keeping tagged controls.
- Reordered Chart Editor events so the most commonly used camera, speed, resource, shader, character, and stage events appear first.
- Shift-clicking a placed event now selects it and opens its Event Data toolbox, including events missing from a stale dropdown.
- Shader property controls now use one clean slider with an integer value display. Values move by 1 normally and by 5 while Shift is held.
- Debug builds now identify both LuaSlice and FNF before the branch, commit, modified state, and prototype label.
- Overlay image events now preload their PNG and animated XML/TXT atlas data before gameplay.
- Reworked Psych Engine imports into a step-by-step flow for up to eight difficulty charts, optional events, and required instrumental, Player Vocals, and Opponent Vocals files. Android uses its native document picker for every step.
- Startup now keeps only commonly reused textures and sounds permanently cached instead of loading nearly every UI texture into memory.
- Reworked state caching so song assets survive loading while unused assets are retired before Flixel's state cleanup and released as soon as the old state is destroyed.
- Low Quality Minimal now avoids loading hidden Freeplay capsule details and disables off-screen stage sprites at a low update rate.
- Low Quality Max now skips heavy album, difficulty-star, flame, score-number, note-splash, hold-cover, and combo-number assets instead of loading and hiding them.
- Optimized Philly Streets and Philly Streets Erect by skipping disabled rain-shader updates, sharing mist calculations, sorting added mist layers once, and reducing Erect mist layers under Low Quality.
- On mobile, the Chart Editor now opens only from its Options entry.
- Low Quality Minimal and Max now skip video and dialogue cutscenes, while None keeps the normal cutscene flow.
- Reorganized the Lua implementation into focused files under `source/lua` so its APIs, menus, options, shaders, logging, and script discovery are easier to maintain.
- Replaced the mobile Upgrade menu item with the Merch item.
- Updated the LuaSlice logo and the platform build icons.
- Added a Discord item after Options on the Main Menu using the supplied Discord atlas and invite link.
- Locked `Remove Existing Shaders` on for this release because I can't get it to work, I'm sorry! 

### Fixed

- Fixed the Discord Main Menu item leaving menu navigation disabled after opening the invite link.
- Fixed F5 rebuilding the hidden PlayState while Game Over owned the player character, which shifted the death sprite and left a duplicate idle frame behind it.
- Fixed the volume-key plugin crashing during reload frames where player controls were temporarily unavailable.
- Fixed F5 triggering both the global asset reload and Lua hot reload in PlayState, which destroyed the song audio and caused a null-reference crash in the same frame.
- Fixed Shader event slider persistence and real-time number display updates so values remain correct across editor sessions.
- Fixed Shader slider dragging rebuilding note displays and HaxeUI layouts unnecessarily.
- Added null safety across `SoundGroup` operations to prevent crashes while switching states or cleaning up PlayState audio.
- Fixed shared Animate Atlas textures being destroyed while another live character or stage still referenced them, preventing compatible mod characters from crashing during rendering.
- Reworked the Psych Engine 1.0.4 importer around its real `psych_v1` format, including player/opponent lanes, GF camera sections, BPM sections, animation targets, note types, embedded events, and companion `events.json` files.
- Fixed Psych charts with an empty stage field by applying Psych Engine's normal song-to-stage fallback.
- Added a clear import error when `events.json` is selected instead of a Psych song chart.
- Fixed selecting HUD Fade crashing when stale event fields were still stored by the Chart Editor toolbox.
- Fixed HUD Fade opacity removing its preview image. Each HUD target now previews independently while the background remains visible.
- Fixed HUD Fade Sine and Quad easing previews not updating after Linear.
- Fixed F5 or asset reload crashing while a Play Dialogue conversation was active.
- Fixed Play Dialogue not opening during Chart Editor playtests.
- Fixed Play Dialogue, conversation music, and tagged audio volume fades crashing because `FlxSound.volume` could not be reflected by `FlxTween`.
- Fixed Overlay preview opacity hiding the preview and color-picker changes not refreshing it correctly.
- Fixed Overlay color-wheel values not reaching the in-game solid and gradient colors.
- Fixed HUD Fade target opacity changes not refreshing the layered preview.
- Fixed Blackout leaving uncovered screen space when used on a zoomed camera and removed its unnecessary Chart Editor preview.
- Fixed Chart Editor color pickers updating the preview without saving the new color into the event data.
- Fixed Play Dialogue portraits, dialogue boxes, and typing sounds failing when a Week 6 conversation runs in another song.
- Fixed Play Dialogue music not resolving from the Week 6 asset library.
- Fixed gradient overlays rendering as a few large bands instead of a smooth gradient.
- Fixed shader cleanup skipping some characters, sprites, or cameras after restarting a song or reloading with F5.
- Fixed normal Android release builds enabling advertisements when `.env` only contained signing information.
- Fixed existing Chart Editor event icons not refreshing after their event type changed.
- Prevented missing event resources, Lua files, audio tags, shaders, targets, dialogue, stage objects, and animations from crashing gameplay.
- Prevented repeated tagged audio, shader, overlay, tween, and timer resources from leaking after retries or leaving PlayState.
- Fixed Blackout's `Keep HUD Visible` option so the blackout renders on the game camera.
- Fixed shader fade-out starting from the wrong value when no fade-in ran first.
- Fixed Stage Editor local image loading by decoding the selected image directly instead of copying an incomplete preview frame.
- Added Stage Editor support for loading and preserving Animate Atlas spritemaps and their atlas settings.
- Fixed missing stage images hard-crashing the Stage Editor; affected objects now use a visible placeholder and report the missing path.
- Fixed Psych Engine imports so the song chart is selected first and the optional `events.json` file is selected second. Difficulty-suffixed and unsuffixed chart names are supported.
- Fixed Android Chart Editor chart, instrumental, vocals, metadata, and import boxes not opening the document picker. Imported, opened, and new `.fnfc` charts now save under the top-level `Charts` folder beside `mods`.
- Fixed mobile Chart Editor theme selection not applying reliably by placing Light and Dark directly in the touch-accessible View menu.
- Fixed HUD Fade Player/Opponent targeting for icons, strumlines, note heads, sustain trails, hold covers, and incoming notes.
- Fixed HUD Fade side previews reusing a stale cached frame after changing target or opacity.
- Fixed overlapping Both, Player, and Opponent HUD fades fighting over the same stored target.
- Fixed Shift-clicking a placed event crashing when its event type was not already present in the Event Data dropdown.
- Fixed Shader event tooltips listing controls that do not apply to the selected target or property type.
- Fixed disabling `Ignore Transparent Pixels` still preserving fully transparent pixels instead of processing the complete sprite texture.
- Fixed HUD Fade values remaining on note heads, sustains, hold covers, strumlines, icons, or the health bar after retrying or pressing F5.
- Fixed Health Drain applying only one health change instead of remaining active until another Health Drain event changes or stops it.
- Fixed helper-based fragment shaders such as `rain.frag` failing to compile through the normal runtime shader path.
- Fixed simultaneous Shader properties cancelling each other's tweens when they shared one shader tag.
- Fixed song-cache cleanup trying to unload a missing `songs` asset library.
- Fixed Low Quality changing the saved Shaders option instead of temporarily overriding it during gameplay.
- Fixed Low Quality Max disabling the hidden Freeplay difficulty controls and preventing difficulty changes.
- Fixed stage changes retaining references to culled sprites from the destroyed stage.
- Restored the original A-Bot visualizer after automatic audio-source switching stopped VIZ bars from working.
- Restored the original cached instrumental and vocal loading path so completed songs reliably leave gameplay again.
- Reverted the recent Character Select icon tint changes to the original behavior.
- Stabilized Character Select analyzer reconnects and limited its updates to 30 Hz without changing its visible behavior.
- Fixed failed or interrupted week cutscenes leaving video, dialogue, conductor, music, or black-screen objects alive.
- Fixed cache retirement destroying source atlases still used by combined Chart Editor note and event-icon frame collections.
- Fixed repeated Freeplay, Story Mode, and Options visits retaining a Freeplay rank camera, faded Story backgrounds, and the previous Options state.
- Fixed Philly Streets rain filters replacing unrelated camera filters, remaining registered after the stage closed, or returning when song shaders were disabled.
- Fixed Shader events leaving native character, object, stage, and camera shaders active. Removed shaders are restored safely after retry, reset, or F5.
- Fixed LuaSlice camera shaders replacing unrelated existing camera filters instead of preserving and restoring them.
- Fixed variation headers not becoming active before `Remove Variation`, which incorrectly tried to remove the Default variation.
- Fixed delayed memory cleanup destroying Freeplay album artwork that was still in use.

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
