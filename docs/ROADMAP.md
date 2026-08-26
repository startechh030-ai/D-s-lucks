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
| M1 | **Module system + bridge (the swap, made real)** | ✅ **Core side done**: `.ds` spec format (core·contract·plugin·extension), parser/validator/loader in D, family contracts, **null renderer** plugin loads + probes live, Box3D + FPS-logger example specs. **Next**: JNI bridge → Cores tab shows live values + addon list on-device | core ✅ / bridge next |
| M2 | **Pixels through the seam** | Editor shell arrives **native (SDL shell + engine-rendered UI, per D12)**: left file tree, bottom asset shelf, 2D UI canvas; **Filament via `librenderer_filament.so`** with the three tiers (D14) selectable in settings; play-in-editor preview runs the main script on a second core instance. *On-device demo: swap null↔filament renderer, no rebuild* | |
| M3 | **First 3D** | Orbit camera; spawn cone/capsule/box; HDR environment; object select + move | |
| M4 | **Assets** | import `.glb/.gltf` (incl. renamed files — sniff magic bytes, not extensions); textures; `.mat` compile via matc; runtime conversion pipeline | |
| M5 | **Physics** | Box3D module (gravity, collisions on primitives) + Box2D for 2D; *swapability demo: same scene, Jolt `.so` dropped in* | |
| M6 | **Scripting** | Wren embedded; spawn/move/destroy entities from `.wren`; hot-reload on save; script-defined elements attach to live entities | |
| M7 | **Sound** | Oboe-backed `sound` module: load, play, loop, 3D pan | |
| M8 | **Game data** | `.anim` read/write (tweak-only, no editor); procedural cloud gen sample in D; scene save/load | |
| M9 | **Runner polish** | Standalone game runner mode inside editor app; perf overlay v2; memory graphs | |
| M10 | **Export system** | Player templates (`dsluck-player-*`) published by CI; bundler + two-phase bake (script bake → manifest, profile bake → explained tier choice); Android Layer 1 (quick, no SDK) + Layer 2 (full, signed); win/linux one-click; iOS Xcode bundle (D13) | |

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
