# LuaSlice
LuaSlice is a fork of Friday Night Funkin' V-Slice that adds built-in Lua modding support and small tweaks to the engine itself. It is made for people who want to create gameplay scripts, events, menus, options and other mod features without having to write everything in Haxe.

LuaSlice's original API uses `.lua` and `.luag`. Psych scripts use `.luap` and `.luapg` in a separate runtime; the global suffix controls loading scope, not a shared Psych Lua state. LuaSlice also includes F5 hot reloading, Lua error reports, persistent save data, custom Chart Editor events, and Lua hooks for gameplay and menus.
Existing `.hx` and `.hxc` modding still works, so Lua can be used by itself or alongside Haxe scripts.

This branch is migrating the existing V-Slice 0.8.6-based engine to the official public-playtest preview at `5a63f2062bfc95a1fe35f83405acdee1f8c845ec` (upstream metadata: 0.8.7, build 70). It is not ready for release. The migration and Psych Engine 1.0.4 API reimplementation are still being tested; see [the source audit](docs/migration/preview4/SOURCE-AUDIT.md) for the pinned versions and known gaps.

`Credit is required if you use LuaSlice in a engine edit, project, or anything like that. No [but ...]
(Videos, Showcases, Original Mods, Ported Mods are allowed!)`

Join the LuaSlice Discord server:
- [LuaSlice Engine](https://discord.gg/sCr5rpPwBn)

Download LuaSlice or view its source code here:
- [Versions](https://github.com/Fla-man-Max/LuaSlice/releases)
- [Source Code](https://github.com/Fla-man-Max/LuaSlice)
- [Gamebanana](https://gamebanana.com/tools/23050)
