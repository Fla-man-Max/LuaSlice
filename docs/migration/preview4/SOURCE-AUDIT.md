# LuaSlice preview migration: source audit and execution design

Date: 2026-11-07. Status: source audit recorded; migration and conformance work are not complete.

## Source and preservation boundary

- Working source: `C:/Users/hodzi/Desktop/LuaSlice v0.0.8 - FNF v0.8.6 Rebuild`.
- Current branch: `codex/luaslice-v086-rebuild`; HEAD `536c98816e261fc233906337a43a437502955ee9`.
- The checkout is dirty, including 126 source paths reported by Git. Some important API/native/test files are untracked. A worktree made from HEAD alone would lose these changes.
- The existing `origin` points at FunkinCrew/Funkin, not the LuaSlice publishing repository. Do not push this migration there.
- Inventory: **650 files, 4,557,934 bytes** under source: 613 Haxe, 15 Markdown, 7 Java, 6 HPP, 5 Objective-C++, 3 XML, 1 CPP. Every path and its SHA-256 is in SOURCE-INVENTORY.csv.
- Inventory is not a claim that every function was reviewed. Detailed reads covered integration/lifecycle paths below; large files received targeted range/diff review. Native Apple implementations, all editor commands, all renderer/audio DSP internals and all legacy parsers still need implementation-stage review.
- No gameplay code, dependencies, assets, user index or branch was changed during the audit. No builds or runtime tests were run during this phase.
- Existing assets submodule HEAD is `7f0c72a577e95a524febc1e534c82d3ed40e6028`; four tracked changes include credits, chart menubar and Philly stage scripts. Art HEAD is `268749ab9be74e518ae46f5f456ea4e986f7328c`. Preserve their working contents separately; do not treat clean root Git status as proof they were protected.
- Bulk images, music and videos were not inspected.

## Verified versions and pinned references

| Item | Evidence |
| --- | --- |
| LuaSlice upstream baseline | FNF v0.8.6 `ee9d492becfc1178b2c80487167d09a880f90146` is an ancestor of current HEAD (verified git merge-base). |
| Actual current metadata | project.hxp says FNF 0.8.6/build 102; Constants and VersionUpdater.txt say LuaSlice v0.1.0; README incorrectly says FNF 0.8.5. |
| Selected official snapshot | FunkinCrew/Funkin, preview/public-playtest, **5a63f2062bfc95a1fe35f83405acdee1f8c845ec**, committed 2026-11-07 07:45:32 UTC, message “new monster from feedback”. Freeze this SHA rather than following a moving branch. |
| Target metadata | Official project.hxp still says 0.8.7/build 70. “Preview 4” is the requested preview label, not an invented source version/tag. |
| Tag/release check | Queried official tag refs and latest releases. No Preview 4/public-playtest tag was advertised. Latest ordinary release queried was v0.8.7. Use the requested branch fallback above. |
| Psych reference | ShadowMario/FNF-PsychEngine tag 1.0.4, **5c67ced49e5a98535298a6daa3f8f4ec79ac8399**, 2025-03-24 18:03:08 UTC. |
| Branch topology | v0.8.6 and the preview diverge: merge-base `188870dbe61fb88b062f8480e37cf03eed3063b0`, preview ahead 1960 / behind 547 in GitHub comparison. The comparison response returned only 300 files, so it is NOT the complete migration diff. Fetch fixed objects and perform local direct-tree comparisons before integration. |
| Target tree | Recursive Git tree was not truncated: 1,059 entries and 703 source blobs, including 38 Camera Editor files. |

Original scripting pins include hxluajit 1.0.5, hxluajit-wrapper 1.0.0, Iris 1.1.3 and pinned SScript/NxScript. Preserve original runtime ownership; upgrade native FNF dependency revisions as a coordinated target set rather than individually guessing newer APIs.

## Subsystem audit / upstream compatibility matrix

| Subsystem | Current responsibilities and lifecycle | Preview integration / preservation |
| --- | --- | --- |
| Startup/build | Main installs crash handling, mobile working directory and Flixel/HaxeUI; InitState initializes saves/preferences, native services, Polymod and plugins, then LuaSlice updater/title. project.hxp assembles flags, libraries, native providers, assets, icons and documentation. | Preserve me.luaslice, executable/title/icons/credits/updater and custom feature flags. Reconcile preview native providers and asset IDs rather than replace project.hxp wholesale. Keep the original checkout and its index untouched using an independent preservation checkpoint and worktree. |
| Original Lua | LuaScriptManager owns one LuaJIT VM per manager, tagged resources and original API. .lua executes in an environment inheriting manager _G; .luag shares that manager's globals. These are not process-wide shared globals. LuaApiPrelude/TaskPrelude add convenience API and coroutine scheduling. | Preserve this contract separately from Psych; adapt native bindings and discovery through a shared enabled-mod source service without sharing interpreter states or injecting Psych-only callbacks. |
| SScript/Nx | ScriptRuntimeManager owns independent interpreters; SScript uses property/tween services, Nx enables its interpreter sandbox. Global suffixes control discovery, not shared interpreter state. | Preserve .ss/.ssg and .nx/.nxg, native HScript/Polymod class scripting and hook order. Correct deterministic mod ordering and test coexistence. |
| Psych | PlayState owns PsychLuaHost; each PsychLuaScript owns a LuaJIT VM; tagged resources/variables are host-owned. Iris HScript is distinct from Polymod and SScript. Current conversion has depth bounds; existing host synthesizes sustain callbacks using native holds. | Reimplement from 1.0.4 source contracts using a VM bridge, discovery, event coordinator, live gameplay/property adapters and owner-scoped resources. Existing classes are integration evidence, not a trustworthy implementation to rename/copy. |
| Native event dispatch | Psych note preprocessing precedes modules; then song, events, note kinds, stage, conversation, characters, original Lua, alternate runtimes and Psych. eventCanceled differs from stopPropagation. | Define exactly-once lifecycle and cancellation behavior against the preview. Maintain original typed event payloads and native scripted consumers. |
| Gameplay/timing | Native PlayState/Conductor/PreciseInputManager own countdown, queued precise input, judgement, stages, characters and note/hold groups; LuaSlice adds camera following, note kinds, shader/quality policies, middle-scroll and scripted effects. | Retain native preview objects and sustain architecture, adapting hooks rather than importing Psych PlayState. Validate clocks at multiple frame rates and preserve native judgement accuracy. |
| Saving | Save/SaveSystem/SaveDataMigrator persist options, editor settings, controls and script data. | Preserve existing schema and active save slot; migrate old mobile preference fields and verify real restarts. Do not reset user data to pass tests. |
| Chart Editor | Current roughly 8,300-line state includes LuaSlice Vortex, gesture handling, randomization, parameters, preferences and importer hooks. | Target roughly 4,250-line state delegates to categorized commands and audio/chart/editor/UI handlers; new selectable collections include comments, subbeats and time changes. Port custom behavior into that architecture, not the old state file. |
| Camera Editor | Not present in current source. | Integrate target's 38 files, ChartDocument/FNFCUtil, event layers, UI resources, menus and lifecycle. Preserve LuaSlice titles and fail-save transition gates. |
| Import/export | Psych/Codename adapters retain song sidecars, note/event kinds and holds. Instrumental import validates decoding, while vocal import currently accepts raw bytes first. | Adapt new song schema and shared FNFC utilities; validate OGG/invalid/unknown-size streams and data-preserving roundtrips. Renaming MP3/WAV bytes to .ogg is not transcoding. |
| Touch/Android | Old funkin.mobile contains hitboxes/buttons/controls, native providers and FNFC intent loader. State/substate destruction explicitly detaches controls. | Target uses funkin.touch and funkin.util.mobile; FNFLoaderExtension replaces FNFCExtension with streaming cache copy. Preserve ownership fixes, custom controls, gestures, external keyboard and package identity. |
| Menus/options/identity | LuaSlice main watermark, title text, updater, performance menu, mod metadata/warning behavior, error Copy action and touch cursor are custom. | Reapply to preview UI without reintroducing the old Options/Freeplay selection bugs or replacing the official mod-menu behavior. |
| Caching/audio/errors | ResourceCache generations invalidate catalogs/text and stale load callbacks; loading queues audio with bounded concurrency. Crash recovery has guarded logging and recoverable editor states. | Map to preview asset/cache/transition classes, preserving generation checks and ownership. Audit cancellation paths instead of suppressing failures. |

## Source-proven findings (not runtime reproductions)

### Discovery and API contract

1. PlayState.initLuaScripts (2180–2194) only checks six loose mods/global and mods/scripts paths. It does not implement the broader per-mod/song/stage/character locations promised by the original API guide.
2. Active MusicBeatState class-script loading scans every physical mod subfolder (LuaScriptManager 666–707), including disabled mods. Original require paths also enumerate those folders (1084–1102). Psych discovery is restricted to loadedModDirs (PsychLuaHost 108–136). Original code also hardcodes mods rather than honoring redirected mod roots.
3. Legacy screen/options loader methods exist but have no source callers. LuaScriptFolders categories are require paths, not proof of automatic script loading.
4. SS/Nx globally sorts collected paths and can lose enabled-mod ordering. Direct filesystem loaders do not demonstrate execution from Polymod ZIP virtual roots.
5. Psych setTimeBarColors is an unconditional false stub but isLuaFunctionSupported reports registration as support (PsychLuaAPI 634/509). addLuaScript ignores allowDuplicate. File API flags are ignored or deliberately adapted. Complete parity must be established behaviorally, not by its version string.
6. .luap and .luapg currently have isolated VM globals alike. Document global discovery versus shared Lua environment accurately.

### Lifecycle, ownership and saving

7. Psych/original/alternate runtime startup follows the first startCountdown and native note generation, missing initial cancellable countdown/spawn hooks (PlayState 997 versus 1024–1038).
8. Player botplay bypasses Psych note interceptHit (3209–3224 versus manual 3449), unlike opponent/manual hit paths.
9. changeStage destroys a registry-owned cached Stage (2204–2206), but Stage documents kill/revive for cache reuse; switching back can revive a destroyed group.
10. PreciseInputManager signal subscription has no matching state cleanup unsubscribe in inspected source. Old PlayStates can remain retained.
11. Added input clock snapshot subtracts processing latency from an earlier captured clock, mixing reference times. Must reproduce against a controlled timestamp/frame-rate test before choosing a timing change.
12. LuaSliceSongEventRuntime.resetEffects has no callers; retry resets notes/audio but can retain overlays/drain/timers.
13. SaveSystem.flush rebinds the base slot, bypassing Save's corrupt-slot fallback. Old mobileOptions.controlsScheme is not transferred to options.controlsScheme.
14. FunkinSoundscape.destroy clears the global timer manager instead of just its own waits.
15. Hitbox hints borrow the same pauseButton/body as deadZones, while FunkinButton.destroy destroys each deadzone. This establishes repeated destruction calls and explains a credible song-exit risk; no new crash reproduction was run.
16. Chart autosave clears dirty before asynchronous export; failures/cancellation can leave an unsaved chart marked clean. Target improves dirty handling but still needs outcome-aware notifications/transitions.
17. Clearing the last tagged Lua camera filter drops captured base filters; clearCamera restores them only while its bookkeeping survives. Shader-manager update has no source caller in the inspected manager.
18. LuaOptionManager expects reflective OptionsMenu helpers that the current source does not define, and its specialized loader is dormant.

### Platform/security boundaries

19. Current Android FNFC reader allocates from getStatSize and performs one read; unknown sizes and partial reads are unsafe. Target's streaming loader replaces it.
20. Current DataFolderProvider accepts arbitrary absolute document paths without canonical BASE_DIR containment. Manifest exploitability was not tested.
21. Both Lua runtimes open all LuaJIT libraries. Psych classFor uses raw Type.resolveClass despite HScript filtering; original Lua reflection/file APIs are broad. Neither current implementation is a demonstrated sandbox.
22. Original Lua table conversion lacks cycle/depth/large-index bounds. Current Psych conversion has a 32-level bound but must be replaced/verified against reference behavior.
23. Song-event asset loading accepts direct filesystem paths outside mod/assets roots.
24. Psych notes() and sustain-index synthesis allocate/search arrays in hot paths. This is a source observation, not a measured performance result.

## Observed target hazards: do not bless upstream blindly

- Target MusicBeatState passes directions as FunkinHitbox constructor argument two, but the target signature still expects showGradint Bool there. Verify in touch-enabled compilation.
- Target hitbox teardown lacks LuaSlice's idempotence/container-detachment protection.
- Target moveToCameraEditor force-saves then transitions without awaiting/observing success.
- Target Camera Editor hardcodes official window titles in several paths.
- New native resource ownership, editor transformations and custom difficulties need runtime roundtrips before release.

## Security and compatibility design decision

Psych 1.0.4 is the behavioral reference, but arbitrary process execution, unrestricted FFI/native loading, interpreter internals and escaping filesystem paths are not acceptable capabilities for the replacement. Enforce those restrictions at runtime/import/property/file boundaries and document compatibility exceptions explicitly. Preserve the original LuaSlice API contract; do not call it a secure sandbox. Reference docs themselves target Psych 1.0+ rather than guaranteeing every 1.0.4 detail, so the pinned implementation is authoritative.

## PR review snapshot

- Open: #8304 (downscroll), #8374 (deleted/flip selection), #8315 (legacy vocals), #8394 (clock interpolation), #8402 (file stat), #8384 (grabbing cursor).
- Merged as reported by GitHub: #8343, #8397, #8398, #8399. Their reported merge timestamps are after the selected snapshot's timestamp. Check local ancestry/diffs after fetching; timestamp alone is not proof of inclusion.
- Do not cherry-pick anything merely from this list. Preserve working downscroll, inspect diffs and test selection/undo. Hold #8394 until judgement/frame-rate tests exist.
- Also queried twelve recently updated PRs; several were old closed/superseded develop branches, not suitable automatic additions.
- PR-STATUS.json records exact heads/merge SHAs/status at the audit, not an integration claim.

## Execution design and checkpoints

Use one source-preserving integration strategy: independently checkpoint the complete current source (including untracked API/tests), leave the user's checkout/index intact, then create an isolated migration worktree. Fetch only fixed target/reference commits and record direct-tree compatibility there. Preserve current assets/art contents separately before changing submodule pointers.

1. Checkpoint user source and requested audit; verify original file hashes and index unchanged.
2. Create/attach isolated worktree; run available original baseline tests there and record failures without hiding them.
3. Integrate preview architecture using actual merge-base and explicit conflict review. No blanket ours/theirs. Reapply custom features into new handlers, typed song data and transitions. Keep separate commits/checkpoints by subsystem.
4. Migrate chart/camera editor data, command and save architecture; retain Vortex/downscroll/gestures/converters and validate roundtrips.
5. Migrate touch/native Android providers and ownership fixes with teardown/provider regression tests.
6. Reimplement Psych VM, conversion, discovery, catalog, resource ownership and live-object/event adapters against pinned 1.0.4. Preserve original Lua/SS/Nx/native scripting separately.
7. Test enabled/disabled roots, suffixes, duplicates, filesystem case/traversal, Lua errors, repeated reload/destruction and real save restarts; then update all documented paths/examples.
8. Review PR diffs against fixed snapshot and actual migrated code; apply only justified changes.
9. Build Windows/Android and run gameplay/editor/native API regression suites. Compile success is not phone runtime success. Report PASSED/FAILED/NOT RUN/BLOCKED separately.
10. Clean source sync only after verifying it preserves this migrated source; never replace the existing known working release with a partial migration.

## Audit evidence and limitations

- Used actual source/working-tree diffs plus precise lifecycle call paths, not README claims.
- Codebase-memory generation 2026-10-24 is stale and Haxe paths are not tracked by its graph. All material Haxe findings used source fallback.
- Full/detailed reads: Lua runtime helpers, alternate runtimes, mod selection/metadata/audio policy, Psych conversion/script/HScript/notes, native module dispatcher, precise input/countdown/save migration, touch input/buttons/hitboxes, Android Haxe/Java providers, Psych/Codename importers and targeted editor command/handler files.
- Targeted reads: large PlayState, LuaScriptManager/Prelude/Host/API, PolymodHandler, ChartEditorState and save/dialog/transition/native-class integration.
- Remaining depth limitations: Apple native implementations, all editor commands, all cutscene/render/audio DSP internals and every old importer parser were inventoried but not exhaustively audited.
- Historical test logs/docs are not new test results. No migration or API completeness is claimed by this report.

Sources: [selected FNF commit](https://github.com/FunkinCrew/Funkin/commit/5a63f2062bfc95a1fe35f83405acdee1f8c845ec), [Psych 1.0.4](https://github.com/ShadowMario/FNF-PsychEngine/tree/5c67ced49e5a98535298a6daa3f8f4ec79ac8399), [official Psych Lua docs](https://shadowmario.github.io/psychengine.lua/).
