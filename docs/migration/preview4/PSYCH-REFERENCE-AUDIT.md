# Psych 1.0.4 reference notes

Reference commit: `5c67ced49e5a98535298a6daa3f8f4ec79ac8399` in ShadowMario/FNF-PsychEngine.

These are implementation findings, not a statement that the migrated API is complete. The preserved Psych implementation is still present while the engine integration is compiled and tested. Its replacement and the full function-by-function compatibility matrix remain unfinished.

## Creation order

Verified directly against the pinned `source/states/PlayState.hx` on 2026-11-10:

- General scripts load around lines 439, before `generateSong()` at line 507.
- Custom note-type and event scripts load around lines 573–583, after generation.
- Song-specific scripts load around lines 588–602, also after generation.
- `startCallback()` runs at line 611. The default callback can start the countdown here.
- `onCreatePost` runs at line 630, after generation. A cutscene can defer the countdown until later.

Consequently, `onStartCountdown` must see created scripts, but it cannot universally require `onCreatePost` to have run already. The lifecycle fixture was corrected to match that order; it still fails if `onCreatePost` runs before note generation or if creation is duplicated. It is NOT RUN until a migrated executable is available.

Source: [pinned PlayState](https://github.com/ShadowMario/FNF-PsychEngine/blob/5c67ced49e5a98535298a6daa3f8f4ec79ac8399/source/states/PlayState.hx).

## Earlier registration audit

The read-only audit examined FunkinLua, CallbackHandler, ReflectionFunctions, ExtraFunctions, TextFunctions, ShaderFunctions, FlxAnimateFunctions, HScript and the deprecated/custom-substate helpers at the same commit. The literal core registrations and optional feature registrations are not evidence of behavioral compatibility.

Outstanding differences identified in that audit:

- `noteTweenDirection`, `FlxColor` and `setHealthBarColors` are missing from the preserved registration list.
- `setOnHScript` takes `ignoreSelf` before exclusions in the reference.
- `setSoundPitch` accepts `doPause`; `removeLuaSprite` accepts a group; `precacheImage` accepts `allowGPU`.
- `deleteFile` distinguishes mod-folder handling from absolute paths.
- `addLuaScript` can deliberately create another script instance; a path-only deduplication rule changes that behavior.
- Animate atlas loading supports custom JSON parameters. Returning a no-op is not support.
- `callOnScripts` must respect Lua stop/exclusion results before dispatching HScript callbacks.
- Global callback registration must also reach scripts loaded later.
- Named tween completion callbacks are broadcast in the reference, rather than always belonging only to the creating script.
- Lua note callbacks take scalar values while HScript callbacks may take note objects. They must not share one untyped argument array.
- Creation, pre-hit, keyboard, ghost-tap, event-early-trigger, pushed-event, countdown-started and score-update hooks need ordering/signature checks.

## Replacement boundaries

- Keep the original LuaSlice runtime separate from Psych, including discovery by extension.
- Resolve live game objects through adapters; do not retain old characters or PlayStates across replacement/restart.
- Give each script its own VM, callback-error state and owned resources. Explicit shared globals/callbacks must be host-managed rather than an accidental shared Lua environment.
- Normalize mod roots once and use only enabled roots, with deterministic precedence and confinement checks.
- Register only implemented behavior. Compatibility status must include actual native tests, not registration-name counts.
- Restrict Haxe reflection/imports, process/FFI access, sensitive filesystem access and interpreter internals. Review LuaJIT standard libraries before executing any mod text.
- Do not describe either existing runtime as a secure sandbox. Preserve and document the original runtime's broader trust assumptions separately.

The pinned engine, native interface, and API reference must remain fixed during this work. Runtime verification, platform support, and any unavoidable compatibility differences belong in the final matrix and report.
