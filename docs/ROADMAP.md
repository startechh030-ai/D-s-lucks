# D's Luck — Roadmap

Order is deliberate: pipeline proof → talk to core → see pixels → touch physics
→ write scripts → feel like an engine.

| # | Milestone | Deliverable | Status |
|---|-----------|-------------|--------|
Direction: **Contract → Pixels → Forces.** The replaceable-core idea is not a
separate milestone — it's the ABI (M0) plus the module loader (M1). Filament is
the loader's first real passenger, physics rides the same loader later.

| # | Milestone | Deliverable | Status |
|---|-----------|-------------|--------|
| M0 | **Hub + core skeleton + CI** | D core (betterC) compiles to `.so` host + arm64/armv7 + windows dll; ABI smoke test passes; Hub app (projects/templates/cores tabs); GitHub Actions builds APK | ✅ done |
| M1 | **Bridge + module loader (the swap, made real)** | JNI bridge: Cores tab shows live `libdsluck.so` values (version, ABI, tick counter). **Module system v1**: manifest.json + loader + family headers; **null renderer** module; hub loads/swaps modules on-device without rebuild | next |
| M2 | **Pixels through the seam** | Editor shell (left file tree, bottom asset shelf, 2D UI canvas) + **Filament via `librenderer_filament.so`**: clear color → skybox. *On-device demo: swap null↔filament renderer, no rebuild* | |
| M3 | **First 3D** | Orbit camera; spawn cone/capsule/box; HDR environment; object select + move | |
| M4 | **Assets** | import `.glb/.gltf` (incl. renamed files — sniff magic bytes, not extensions); textures; `.mat` compile via matc; runtime conversion pipeline | |
| M5 | **Physics** | Box3D module (gravity, collisions on primitives) + Box2D for 2D; *swapability demo: same scene, Jolt `.so` dropped in* | |
| M6 | **Scripting** | Wren embedded; spawn/move/destroy entities from `.wren`; hot-reload on save; script-defined elements attach to live entities | |
| M7 | **Sound** | Oboe-backed `sound` module: load, play, loop, 3D pan | |
| M8 | **Game data** | `.anim` read/write (tweak-only, no editor); procedural cloud gen sample in D; scene save/load | |
| M9 | **Runner polish** | Standalone game runner mode inside editor app (no APK export yet, per spec); perf overlay v2; memory graphs | |

Post-M9 (outside first-stage scope, captured so we never design against them):

- APK/AAB export of games from the editor
- Rigged/skinned characters and full animation editing
- Minimal vertex/face/line editing plugin (intrude, extrude, scale) as a
  *separate, optional* lightweight core module
- Desktop editor builds (desktop hub target already exists)
- Multiplayer/net module

## The standing performance rule

Every milestone lands with: (1) host ABI test green, (2) APK green,
(3) the debug overlay's numbers staying honest — no GC pauses, no per-frame
heap growth. "10x on mobile" is an aspiration we *measure*, never a slogan.
