# Native scripting verification — 2026-09-29

This update extends LuaSlice's existing native bridge and Lua prelude. Property resolution and configuration share `ScriptPropertyService` with SScript; tween creation shares `ScriptTweenService`. Existing LuaSlice raw APIs, Psych aliases, isolated/shared Lua loading, and the separate Psych loader remain in place. NxScript and the standalone FNF Psych Lua API project were not migrated or replaced by this work.

## Verified

- Windows release compilation with hxluajit 1.0.5 and hxluajit-wrapper 1.0.0.
- Android release compilation for arm64-v8a and armeabi-v7a; APK v2 signature verified, no debuggable application flag.
- Windows runtime regression: Psych callbacks, script routing, custom notes, table conversion, legacy Lua coexistence, isolated/shared globals, require, hot reload, custom substates, and song exit.
- Lua property setters in all three forms, bulk getters, references, metadata generation, and profiler counters.
- Coroutine scheduling, cancellation, script-path preservation, and scalar/table native return values on the coroutine's stack.
- Real SScript direct access, Map literals, configuration, property helpers, and fractional-duration tween completion.
- Property service tests: partial failure recovery, current-root lookup after replacement, indexed reads, and disabled profiling counters.
- Windows chart editor: repeated Psych/Codename chart imports, full tutorial OGG instrumental decoding, vocal refresh, waveform processing, and corrupt audio rejection.

Run `tools/tests/TestPsychLua.ps1 -CheckConverters` for the scripting/converter regression and `tools/tests/TestPsychLua.ps1 -CheckEditor` for repeated imports inside the chart editor. The optional `-NoteFixture` points to custom-note test assets. Tests launch an isolated release copy with separate mods and saves under `.work`.

## Small runtime comparison

`tools/tests/TestLuaBenchmark.ps1 -Executable <path>` ran the same legacy script on the prior Lua 5.4 executable and the new LuaJIT executable. Each round performed 1,000,000 arithmetic iterations, then 10,000 native property write/read pairs.

| Runtime | Arithmetic, three rounds (ms) | Property pairs, three rounds (ms) |
| --- | --- | --- |
| Previous Lua 5.4 | 5, 6, 6 | 10, 10, 10 |
| LuaJIT 2.1.1744318430 | 1, 1, 1 | 11, 11, 13 |

These are coarse `os.clock` smoke measurements on one Windows laptop, not a controlled FPS benchmark. The native property bridge did not improve in these samples. No overall gameplay speedup is claimed. The LuaJIT sample ran alongside another regression process, so small differences should not be treated as reliable performance comparisons.

## Limitations

No Android device was connected for the final checks. Android file-picker/OGG import behavior and on-device gameplay still require testing. Linux compilation/runtime were not verified on this Windows host. A passing Windows test does not establish that every mod or Android device works.

LuaJIT uses Lua 5.1-compatible syntax, not Lua 5.4 syntax. Lua 5.4 bytecode and variable attributes are unsupported; use `bit` functions for bit operations and `math.floor(a / b)` for floor division. `table.pack` and `table.unpack` compatibility helpers are included. API compatibility does not imply compatibility with every Lua 5.4 language feature.

The renamed `changelogs/CHANGELOG - PSYCH API.MD` retains the full Psych API guide and now includes dated changes. `changelogs/LuaSlice Lua API.md` documents the optional Lua/SScript helpers, profiling, tasks, and generated LuaLS definitions.
