# Psych Lua compatibility adapter

API conventions and callback behavior reference Psych Engine 1.0.4, commit `5c67ced49e5a98535298a6daa3f8f4ec79ac8399`, by Shadow Mario, RiverOaken, and contributors, under Apache License 2.0.

The files in `source/funkin/modding/psychlua` are a modified integration for LuaSlice, based on the separate official FNF v0.8.7 adapter. The host, object mapping, native event bridge, lifecycle ownership, mod discovery, and Lua 5.4 binding are adapted to LuaSlice's V-Slice v0.8.6 base.

The full Apache-2.0 license is included in `Psych-Engine-Apache-2.0.txt`. FNF's own license remains at the project root. Lua/hxlua and hscript-iris are separate dependencies retaining their own licenses.
