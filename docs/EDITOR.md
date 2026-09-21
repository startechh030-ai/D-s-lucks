# D's Luck — Editor Blueprint (M2 target)

> Status: **pre-code blueprint**. Written while M1's bridge is being verified
> on-device. Nothing here is implemented yet; everything here is decided
> enough to implement against.

## 1. What the editor is

A **native D application**, self-hosted: every pixel of its UI is drawn by
D's Luck's own renderer through the module seam. It sits on a thin platform
shell. It is *not* the Kotlin launcher — the launcher remains an Android-only
chameleon for project picking and quick info.

```
┌─────────────────────── shell (per platform) ───────────────────────┐
│  SDL (Windows/Linux/macOS)   ·   Kotlin SurfaceView host (Android) │
│  open surface · pump input · forward lifecycle events              │
└───────────────────────────────┬────────────────────────────────────┘
                                │ extern(C)
┌───────────────────────────────▼────────────────────────────────────┐
│  libdsluck.so — core (D, betterC)                                   │
│  owns: scene truth, project files, addon registry, edit state,      │
│        undo journal, selection                                      │
└──────┬──────────────────────┬───────────────────────┬──────────────┘
       ▼                      ▼                       ▼
  renderer module        editor UI module        play-preview core
  (Filament shim,        (immediate-mode kit,    (second DslCore
   Forward+/Normal/       panels drawn into       instance running
   Simple tiers)          the same frame)         the game)
```

The **play preview** is a second `DslCore` instance (already cheap: ~181 KB
live memory at rest). Editor and game literally tick side by side — preview
fidelity is free because preview *is* the runtime.

## 2. Layout — the spec, honored

Per the original interface spec, kept minimal and touch-friendly (the
reference device *is* a phone):

```
┌───────────────────────────────────────────────────────────────┐
│ top bar: project ▾ · play ▶ / stop ■ · tier [Forward+|N|S] · FPS│
├────────────┬─────────────────────────────────────┬────────────┤
│ file tree  │                                     │ inspector  │
│ (nested,   │          viewport                   │ (selected  │
│  left      │   (Filament surface + UI overlay)   │  entity's  │
│  sidebar)  │                                     │  elements) │
├────────────┴─────────────────────────────────────┴────────────┤
│ asset shelf: materials (.mat) · textures · models (.glb)      │
└───────────────────────────────────────────────────────────────┘
```

- **Left sidebar**: nested project file navigator (spec-compliant).
- **Bottom shelf**: assets — materials, textures, models (spec-compliant).
- **Inspector**: composition-first — an entity shows its *elements* as
  removable chips (Light, Collision Volume, Material Overlay), never an
  inheritance tree.
- **HUD line in top bar**: fps / frame ms / live KB — the debug overlay,
  always on in-editor.

Touch rules for Go phones: bottom shelf doubles as the action surface on
narrow screens; inspector becomes a sheet. Desktop keeps three columns.

## 3. The immediate-mode UI kit (`editor/ui`)

A small D module inside the editor app (not the core!): buttons, sliders,
trees, chips, text fields — each is a function called per frame with state
ids (no retained widget objects, no GC). Draw data routes through
`dsl_renderer_*` as 2D batches, the same calls the viewport uses. First
clients of the kit: the Cores/Addons panels ported from the hub's designs.

Why immediate mode: zero GC pressure (D11), one codebase across platforms,
and the engine eats its own cooking from day one.

## 4. Renderer contract v1.1 — what M2 needs from the seam

Extends `core/contracts/renderer.ds` with viewport & UI essentials
(contract additions are additive, ABI stays v1):

| Symbol | Purpose |
|---|---|
| `dsl_renderer_surface_attach(native_handle)` | create/attach device to a shell surface |
| `dsl_renderer_set_tier(tier)` / `dsl_renderer_get_tier()` | Forward+ / Normal / Simple at runtime |
| `dsl_renderer_set_clear(r,g,b)` | first pixels (proving pass-through) |
| `dsl_renderer_skybox(ibl_hdr)` | the M2 victory shot |
| `dsl_renderer_draw_ui(cmds, count)` | batched 2D for the editor kit |
| existing v1: `init / resize / submit / shutdown` | — |

The **null renderer** grows matching no-ops so the swap demo keeps working:
`-s tier` prints, clear ignored, skybox ignored — and the Cores-tab probe
keeps passing while the editor exists. Swap test in M2 acceptance:
`null ↔ filament` at runtime, scene unchanged, no rebuild.

## 5. M2 acceptance checklist

- [ ] editor launches from SDL shell (desktop) and Android host
- [ ] viewport fills with clear color → skybox (tier Simple, then Normal)
- [ ] top-bar HUD shows live fps/KB from `dsl_core_stats`
- [ ] tier switch applies live, reflected in renderer probe info
- [ ] play ▶ starts second core; fps stays within 10% of solo viewport
- [ ] runtime swap null↔filament without restart
- [ ] CI: editor artifacts join player templates per platform

## 6. Explicitly NOT in M2 (guardrails)

- No meshes/primitives yet (M3), no materials pipeline (M4),
  no file editing, no scene save (M8), no 2D UI canvas polish —
  layout scaffolding only.
- Android editor host ships *after* the SDL desktop shell proves the
  architecture — same code, second shell, per PIPELINE.md.
