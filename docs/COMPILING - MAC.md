# Compiling LuaSlice on macOS

Run Lime's mac setup first:

```sh
lime setup mac
```

Build and run:

```sh
lime test mac
```

For release packaging, build both Apple Silicon and Intel if you want a universal app. The base game has a helper script:

```sh
art/macos-universal.sh
```

For wider release builds, remember:

- Code signing is needed for clean user installs.
- Notarization is needed to avoid Gatekeeper warnings.
- If native libraries act weird after a library update, run `lime rebuild mac` and `lime rebuild mac -debug`.
