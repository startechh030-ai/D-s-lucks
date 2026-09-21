# D's Luck 🍀

A modular, low-power game engine where **every part of the architecture — renderer,
physics, scripting, even the core itself — can be replaced without breaking the rest.**

> Not built to beat other engines. Built to prove that a fully customizable,
> high-performance engine can run, compile, and edit directly on mobile devices.

**Mobile-first.** The engine is a local, native engine (not a web engine).
First target: Android. Then Windows, macOS, Linux.

---

## The one idea that matters

D's Luck is **an ABI, not a binary.**

The engine core is a `libdsluck.so` that exports a small, versioned C interface
(`core/source/api.d`, `DSL_ABI_VERSION = 1`). The hub, the editor, and every
plugin only ever speak that interface. Consequences:

- Replace the `.so` with any conforming one → you replaced the engine core.
- Renderer is a module (Filament via a C shim today — swap in your own tomorrow).
- Physics is a module (Box3D 3D / Box2D 2D — swap in Jolt if you prefer).
- Scripting is a module (Wren first — LuckScript/D later, same API request surface).

Nothing is welded. That is the entire design.

## Repo layout

```
dsluck/
├── core/                  # THE ENGINE CORE — D, -betterC, no GC, manual memory
│   ├── source/
│   │   ├── api.d          # ← the stable C ABI. The whole replaceability story.
│   │   └── dsluck/        # loop, time, events, entities, camera, memory,
│   │                      #   addons/ = .ds parser, validator, plugin loader
│   ├── contracts/         # family contracts as .ds files ("header" side)
│   ├── core.dsluck.ds     # the engine describing itself in its own format
│   ├── scripts/           # build_host.sh / build_android.sh / test_host.sh
│   └── tests/             # C smoke test driving the ABI
├── addons/                # everything that connects: plugins + extensions
│   ├── renderer-null/     #   reference plugin: loads + answers its probe
│   ├── physics3d-box3d/   #   "user writes new physics" spec (lib arrives M5)
│   └── fps-logger/        #   script extension example (Wren arrives M6)
├── hub/                   # Compose Multiplatform launcher (this app's M0)
│   └── src/               # commonMain (UI) · androidMain · desktopMain
├── docs/                  # ARCHITECTURE.md · ROADMAP.md · DECISIONS.md
└── .github/workflows/     # D → .so → APK, on every push
```

## What works today (M0)

- **Core**: compiled & smoke-tested — 60 Hz ticking, entity pool (box/capsule/cone),
  event bus, byte-exact memory accounting, zero GC.
- **Hub**: project launcher with templates (Empty 3D / Primitive Playground / 2D UI
  Sandbox), Cores tab showing module slots & the status of the bundled `libdsluck.so`.
- **CI**: GitHub Actions builds the D core for `arm64-v8a` and assembles the debug APK.

## Build it

**Core, host (Linux):**
```bash
# install ldc2, then:
core/scripts/test_host.sh          # builds libdsluck.so + runs the C ABI test
```

**Core, Android:**
```bash
core/scripts/build_android.sh /path/to/android-ndk-r26d release
# → core/build/android/arm64-v8a/libdsluck.so
```

**Hub APK:**
```bash
# copy the .so into hub/src/androidMain/jniLibs/<abi>/ (CI does this)
gradle :hub:assembleDebug          # JDK 17, Gradle 8.9+ (Android SDK required)
```

**Hub on desktop (Windows/macOS/Linux):**
```bash
gradle :hub:run                    # runs the same Compose UI on the desktop
```

**Core on Windows:** the CI job `core-windows` produces `dsluck.dll`
(LDC + MSVC on windows-latest). Every CI run uploads all three artifacts:
Android `.so`s, Windows `.dll`, and the debug APK.

Or just push to `main` — the workflow does all of it and uploads the APK.

## Design documents

- [`docs/PIPELINE.md`](docs/PIPELINE.md) — **THE MAP**: editor→device, shells, tiers, export
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — the ABI, module contracts, memory rules
- [`docs/DSPEC.md`](docs/DSPEC.md) — the `.ds` contract file (src/plugin/extension/contract)
- [`docs/EDITOR.md`](docs/EDITOR.md) — M2 blueprint: native editor, UI kit, contract v1.1
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — milestones M0 → M10
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — answers & adjustments to the original spec (D1–D14)

> Editor note (D12): the shipped editor is **native D, self-hosted** — the
> Kotlin app here is the Android launcher/shell, and the desktop Compose hub
> is an internal dev tool only.
