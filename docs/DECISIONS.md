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

### D12 — The shipped editor is native D, self-hosted; Kotlin is shell-only
Spec: *"Other Windows, Linux, Mac editors are not supposed to use Kotlin —
it breaks professionalism and GC issues in editor."*
Decision: agreed and adopted. The editor's UI is rendered by the engine's
own renderer (immediate-mode, Godot/Unreal pattern) — one UI codebase, in D,
for every platform. Kotlin remains only as the Android launcher/host shell;
desktop gets a thin SDL shell; iOS an Xcode host shell. Shells open surfaces,
feed input, and call `dsl_core_*` — nothing more. The desktop Compose hub in
this repo is relegated to internal dev convenience, never shipped.

### D13 — Export = Godot-style player templates ("build files")
Spec: *"For building the game we have a build binary file… user downloads a
build file each for the device they target."*
Decision: CI publishes prebuilt player templates per platform
(`dsluck-player-*`); export = template + project data + baked manifest.
Android ships two layers exactly per spec: **Layer 1 Quick Build** (baseline
APK + scripts, no SDK/NDK needed) and **Layer 2 Full Build** (SDK/NDK native
compile, signed APK). iOS exports an Xcode-ready bundle (final sign = user's
Xcode; Apple's rule). Full detail in `docs/PIPELINE.md`.

### D14 — One renderer module, three tiers, vendored Filament (never forked)
Spec: *"Clone filament entirely… share into tiers… the 3 can be inside a
project."*
Decision: the Filament shim is ONE module exposing three presentation tiers:
**Forward+** (full features — desktops/flagships), **Normal** (the broad
middle), **Simple** (GLES3 floor — Android Go class). All tiers bundle per
export; selection is runtime device-capability detection + developer
override. `renderer/filament/` contains the shim + scripts fetching prebuilt
Filament binaries (vendored artifacts, no upstream source tree in our repo).
A user-written custom renderer module plugs into the same tier slots via
`core/contracts/renderer.ds`.
(Tier naming history: originally "Epic/Compatible/Simple"; renamed after a
sobering reminder about trademark gravity 💔. Forward+ / Normal / Simple is
final.)

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
