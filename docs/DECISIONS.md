# D's Luck — Decisions on the original spec

Clarifications and firm engineering calls made while turning the concept into
the repo. Each lists the spec note it answers.

### D1 — The "replaceable core" is an ABI seam
Spec: *"users can change any part… replace Filament with their own renderer,
Box3D with Jolt."*
Decision: the core is `libdsluck.so` behind a versioned C ABI (`api.d`).
Modules are separate `.so`s behind per-family C headers. This is the only way
"replace anything without breaking the rest" survives contact with reality.

### D2 — Core is D in `-betterC` mode
Spec: *"Uses D as core lang… manual memory… no default runtime GC."*
Decision: BetterC = no druntime, no GC, tiny binary, clean NDK linkage. It is
exactly the philosophy the spec asks for, and it makes Android cross-compiles
boring (the best thing a toolchain can be). A customizable GC remains possible
*as a module's internal choice* (e.g. Wren's), never in core systems.

### D3 — Wren is the first scripting language
Spec: *"For simple code will introduce just 1 — Wren."*
Decision: Wren is ~6k lines of C, embeds in the same native binary, and reads
friendly to newcomers. Later LuckScript/D plugs into the same flat API surface.
Everything script-visible is generated from the ABI, so languages stay peers.

### D4 — Filament stays at arm's length through a C shim
Spec: *"Graphics Renderer: Google Filament… one backend."*
Decision: the D core never links Filament directly. `librenderer_filament.so`
(C++/JNI shim) exports `dsl_renderer_*`. Benefit: the day someone writes their
own renderer, the engine literally cannot notice.

### D5 — Mobile-first, arm64-v8a first
Spec: *"run test on mobile… GitHub Actions to build apk."*
Decision: CI builds the D core for `arm64-v8a` and assembles a debug APK each
push. `armeabi-v7a` and `x86_64` are one line each in `build_android.sh` when
we need them.

### D6 — No 3D model editing in the engine
Spec: *"No 3d editing tool… basic moves (intrude/extrude/scale) only as a
later, separate lightweight C++/core plugin."*
Decision: agreed and locked in post-M9. The engine imports and converts
(glTF/GLB), it does not sculpt.

### D7 — Animation is `.anim` data, read/tweak only
Spec: *"skip animation editing for now… can generate a .anim or read it."*
Decision: the core treats animations as extractable, re-targetable data files
(M8). Editing tools come later if ever; the file format comes first.

### D8 — "10× faster than Godot on mobile" is a benchmark, not a slogan
Spec: performance goals / low-power core.
Decision: we bake the Debug overlay (FPS, memory, logs) into the core's ABI
from M0 so every claim is measurable on real devices. Aspiration kept; hype cut.

### D9 — Hub first, editor second, in Kotlin Multiplatform
Spec: *"First let's build our hub… Kotlin multiplatform… Unreal-style hub,
normal engine-style editor."*
Decision: one repo, `:hub` today, `:editor` lands as a sibling module in M2.
Compose Multiplatform gives Android now and desktop later from the same UI.

### D10 — Renamed `.glb` files still load
Spec: *"can rename a glb but engine can still read its data."*
Decision: asset import sniffs magic bytes/structure, never file extensions.
Captured for M4's importer and covered by its tests.
