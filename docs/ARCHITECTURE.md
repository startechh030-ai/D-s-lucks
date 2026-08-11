# D's Luck — Architecture

> **The engine is an ABI, not a binary.** Everything below exists to protect that.

## 1. Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Apps    │  Hub (launcher)  ·  Editor  ·  Game runner       │
├─────────────────────────────────────────────────────────────┤
│  Bridge  │  JNI (Android) · plain C linkage (desktop)       │
├────────────────────── THE SEAM (api.d) ─────────────────────┤
│  Core    │  libdsluck.so — loop, time, events, scene,       │
│          │  memory, asset tables        [REPLACEABLE]       │
├─────────────────────────────────────────────────────────────┤
│  Modules │  renderer (Filament via C shim) · physics 3D/2D  │
│          │  (Box3D/Box2D) · scripting (Wren) · sound · ...  │
│          │                                  [ALL SWAPPABLE] │
└─────────────────────────────────────────────────────────────┘
```

Two seams, both plain C:

1. **Core seam** — `api.d` exports (`dsl_core_create`, `dsl_core_tick`, …).
   Versioned by `DSL_ABI_VERSION`. Any conforming `.so` is a valid core.
2. **Module seam** — one small C header per module family
   (`dsl_renderer_*`, `dsl_physics_*`, `dsl_script_*`). The core resolves
   modules by loading shared libraries exporting that family's symbols.

This is how a user replaces Filament with a self-written renderer, or Box3D
with Jolt: ship a different `.so` with the same exports. No engine rebuild.

## 2. Core rules (hard constraints)

| Rule | Why |
|---|---|
| `-betterC` always | No druntime, no GC, tiny binary, trivially static-analysis friendly |
| Manual memory only | Counters in `dsluck/memory.d` feed the Debug overlay truth |
| Fixed-capacity pools | No heap churn mid-frame on mobile (entity pool: 4096 slots) |
| No exceptions across the ABI | Return codes / null, never unwind through C |
| Everything versioned | ABI bump = breaking change, documented and deliberate |
| The core never calls module-specific symbols directly | Only through the module family's C header |

Custom GC stays available per spec — as a *module-level* choice (e.g. Wren's
own collector, which the core schedules at frame end), never in core systems.

## 3. Module families (contracts)

Each family is a C header + a loader name. Implementations register via a
manifest (JSON) beside the `.so`: name, version, abiVersion, exports.

| Family | Default | Swap examples |
|---|---|---|
| `renderer` | Filament (C shim over its C++/Java APIs) | custom Vulkan/GLES/soft renderer |
| `physics3d` | Box3D | Jolt, custom |
| `physics2d` | Box2D | script-driven custom 2D |
| `scripting` | Wren | LuckScript, D, anything callable |
| `sound` | Oboe (Android) | AAudio, custom mixer |
| `assets` | glTF/GLB importer + `.mat` shaders | runtime converters (any source format) |

## 4. Scene model

Composition over inheritance, per spec. An **entity** is a pool slot id.
**Elements** attach to any entity:

```
Camera (entity)
├── Light element
├── Collision-volume element
└── Material overlay element (.mat)
```

M0 ships entity pool + camera + transforms. Elements arrive with their
module (physics brings collision, renderer brings material/light).

## 5. Renderer path (the Filament shim)

Filament on Android exposes C++/Java APIs — not D. So:

- `librenderer_filament.so` (C++/JNI, loaded by the D core) exports
  `dsl_renderer_*`: `init(surface)`, `submit(scene snapshot)`, `resize`,
  `shutdown`, plus `.mat` material compilation via matc.
- The D core owns scene truth (entities, camera, transforms).
- Each frame, core → shim passes a compact read-only snapshot.
- Shader pipeline: `.mat` files, compiled with Filament's matc, cached
  per-device in the asset tables.

Writing your own renderer = implementing `dsl_renderer_*` in your `.so`.

## 6. Scripting path

Wren embeds as plain C inside the same native build. Core exposes the
public API to scripts through generated Wren bindings — the same flat,
un-nested call surface the C ABI has. Because it all bottoms out at the
core seam, a later LuckScript/D runtime is a peer implementation.

Script-defined elements: a script class can declare a new element type and
attach it to any entity in a live scene (per spec: dynamic, live adding).

## 7. Memory & debug truth

- Every allocation passes through `dslAlloc/dslFree` (counted, tagged).
- Core exports `DslStats` each frame: frame, dt, fps, entities, live bytes.
- Debug overlay (hub/editor) renders FPS / memory / logs straight from
  `dsl_core_stats` + event stream polling. No instrumentation magic.

## 8. Threading (initial)

- Main/engine thread: core tick, scene truth, module calls.
- Platform layer may stream asset decode on worker threads, publishing
  results via the event bus. Modules keep their own threads internal.
- Determinism at the core: same inputs + same dt sequence ⇒ same scene state.
