# D's Luck — Full Pipeline: From Editor to a Running Game

> This is the map of everything between opening the editor and a player
> tapping your icon. Written before the code (per project law), so every
> later implementation decision has a home.

## 1. The shape of the whole system

```
        ┌────────────────────────── EDITOR SIDE ──────────────────────────┐
        │                                                                 │
        │   Platform shell (thin, per-OS, swappable)                      │
        │   ├─ Android   : Kotlin shell (launcher + editor host)          │
        │   ├─ Desktop   : SDL shell (Windows/Linux/macOS)                │
        │   └─ iOS       : Xcode host shell (from our exported bundle)    │
        │                     │                                           │
        │                     ▼  extern(C), the only language spoken      │
        │   ┌──────────────────────────────────────────────────┐          │
        │   │  libdsluck.so — THE CORE (D, betterC, no GC)     │          │
        │   │  loop · time · events · scene · assets · addons  │          │
        │   └──────┬───────────────┬───────────────┬───────────┘          │
        │          ▼               ▼               ▼                      │
        │   renderer module   physics module   scripting module  …        │
        │   (Filament shim)   (Box3D/Box2D)    (Wren)                     │
        │   ALL .ds-DECLARED, ALL SWAPPABLE                               │
        └─────────────────────────────────────────────────────────────────┘
        ┌────────────────────────── GAME SIDE ────────────────────────────┐
        │   project.ds   · main script (Wren first; D later)              │
        │   scenes · assets (.glb/.gltf/.mat/.anim) · target profiles     │
        └─────────────────────────────────────────────────────────────────┘
```

**Rule zero:** the engine is never one shared library. It is a core `.so` plus
module `.so`s (already true today), plus a shell. Games are *data and scripts*;
players are *templates*.

## 2. The editor is native, self-hosted, and D

- Editor UI is rendered **by the engine's own renderer** (immediate-mode
  style). The Godot/Unreal pattern: the tool is built with the thing it builds.
- No JVM in the shipped editor, on any platform. (Kotlin stays only as the
  Android launcher/editor *shell* — the platform's native glue.)
- Desktop hub module in this repo = internal dev convenience, never shipped.
- **Play-in-editor preview**: the editor hosts a second core instance running
  your game "live" — iterating without export. The *main script* is the game's
  declared entry point; the editor just loads it the same way the final player
  template will. Preview fidelity = export fidelity, by construction.

## 3. Renderer module: one module, three tiers

Per the design session — the renderer is **not limited to one per project**;
one Filament-shim module carries three presentation tiers, all bundled per
export, with runtime device detection + developer override:

| Tier (working name*) | Backend target | For |
|---|---|---|
| **Epic*** | Vulkan, full feature set | desktops, flagship phones |
| **Compatible** | Vulkan conservative / GLES3 high | the broad middle |
| **Simple** | GLES3 minimum, lean formats | Go-edition devices, 4GB RAM |

\* *Working names. "Epic" in particular needs a rebrand before public release
(trademark gravity). Candidates: Prime / Balanced / Feather.*

- **Filament is vendored, not forked**: `renderer/filament/` = our C-shim +
  scripts fetching prebuilt Filament binaries per platform/ABI. No upstream
  source tree in our repo, no 20-minute CI.
- Developers choose either an explicit tier ("present as Simple") or
  `auto` (device capability → best tier that fits; Simple on Android Go).
- A user's *own* renderer module (written against `core/contracts/renderer.ds`)
  plugs into the same tier slots — tiers are a presentation concept, not a
  Filament-only concept.

## 4. Export: Godot-style "build files" (player templates)

The engine never compiles your game itself — it **ships prebuilt player
templates** and bundles your project into them.

```
CI (GitHub Actions) ──produces every push──> dsluck-player artifacts
    dsluck-player-android.apk   (baseline runtime, unsigned)
    dsluck-player-windows.zip   (.exe shell + dlls)
    dsluck-player-linux.tar.gz
    dsluck-player-macos.zip     (later; mac runner)
    dsluck-player-ios-xcode.zip (Xcode-ready bundle, unsigned)
            │
            ▼  editor downloads the template for the chosen target
Your export = template + project data + baked manifest (+ native code on full builds)
```

### Per-target build flow

| Target | Flow | Needs from the user |
|---|---|---|
| **Windows / Linux** | One-click: bundler merges template + project → bytecode-native player | nothing — just our build file |
| **Android · Layer 1 “Quick Build”** | Project scripts/assets packed into baseline APK with embedded runtime → install & test in seconds. **No SDK/NDK on the user's side**; `.wren` scripts run as-is (the “`.d`-as-scripts” idea lives here as: scripts tracked raw, compiled on-device only by the *embedded compiler subsystem* when it exists) | nothing |
| **Android · Layer 2 “Full Build”** | Traditional production chain: gameplay compiled to machine code, assets packed, APK **signed** with release keys | Android SDK + NDK (+keystore) |
| **iOS** | Export produces an **Xcode-ready bundle** (project + libs + assets); user opens in Xcode to sign/run — the industry-standard flow | a Mac + Xcode (Apple's rule, not ours) |
| **macOS** | app bundle via template | mac runner in CI |
| **VR** | Android path + OpenXR family module | device |
| **Consoles** | vendor shell + platform modules behind the same ABI | vendor SDK access (NDA-gated, future) |

### The two bake phases (from the spec: "multiple phases")

Every export runs two phases, and both are *visible and explained* to the user
(no magic):

1. **Script bake** — main script + all `.wren` files are resolved and packed;
   on full builds, a D bootstrap module is generated so the player's entry
   logic is native. Output: a `game manifest` (itself a `.ds`, kind: contract —
   the game describing what it needs: families, elements, events, min tier).
2. **Profile bake** — the target profile is resolved and *explained*: chosen
   renderer tier(s), fallback chain, memory budget, input map. If the game
   manifest demands something the tier can't do (e.g. Simple + heavy HDR
   bloom), the bake **says so in plain language** — this is the
   "how it should work, feel, and look" phase.. Not an error, a contract.

## 5. Platform & compiler truth table

| Platform | LDC compiles | In our CI | Blocks on |
|---|---|---|---|
| Android arm64 / armv7 | ✅ today | ✅ today | nothing |
| Linux x86_64 | ✅ today | ✅ today | nothing |
| Windows x86_64 | ✅ today | ✅ job added | nothing |
| macOS arm64 | ✅ | later (mac runner) | nothing technical |
| iOS | ✅ (static lib) | later | final link+sign = Xcode, always |
| Quest-class VR | ✅ (= Android) | later | OpenXR module |
| Xbox / PS / Switch | LLVM can | no | vendor SDK/NDA — business gate |

## 6. What this means for the next milestones (unchanged order!)

- **M1 bridge** (in progress): Cores tab reads live values + addon list on-device.
- **M2**: editor shell arrives as a *native D app on the SDL shell* —
  the Kotlin hub remains the Android launcher; first pixels come through the
  seam with the three renderer tiers already first-class in settings.
- **M9→M10**: player templates + the bundler + two-phase bake = the export
  system described above.
