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

### D5 — Mobile-first, dual ABI (arm64-v8a + armeabi-v7a)
Spec: *"run test on mobile… GitHub Actions to build apk."*
Decision: CI builds the D core and assembles a debug APK each push.
`arm64-v8a` is the primary target, and `armeabi-v7a` ships alongside it
from day one because the reference test device (see D11) is Android Go
class — and many Go devices run a **32-bit userspace on 64-bit silicon**,
where an arm64-only `.so` would never load. `x86_64` stays one commented
line away in `build_android.sh`.

### D11 — Reference test hardware: Android Go, 4 GB RAM
Decision: the first hardware profile we optimize against is the owner's
low-end Android Go phone (arm64 SoC, 4 GB RAM, 128 GB storage). Practical
consequences:

- **Ship price is truth**: if it doesn't hit budget on this device, it
  isn't done — the debug overlay reports real numbers, we tune to them.
- **Budgets for first-stage**: 60 fps on simple primitive scenes at native
  res (GLES3 backend for Filament — Vulkan on Go devices is rare);
  game heap target ≤ 256 MB live; APK stays lean (dual-ABI universal
  debug APK is fine until M9).
- The Hub prints the device's `SUPPORTED_ABIS` on the Cores tab so the
  32/64-bit userspace question is answered by the app itself on first run.

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
