# `.ds` — D-Spec: the D's Luck contract file

> Almost like a header — but it travels. It says **what a module is, which API
> it serves, what it adds, and how it behaves**. One file, four kinds,
> one loader, zero engine surgery.

## Why it exists

When a user connects new logic — say their own physics — the engine needs to
know three things *before any code runs*:

1. **What API it serves** (which family contract it implements)
2. **What it adds** (new functions, scene elements, events, editor tools)
3. **How it moves** (lifecycle order, memory ownership, thread rules)

A C header can only express (1). A `.ds` covers all three, is machine-checked
by the core, and is honest by construction: the loader tests the file against
the actual shared library. If the spec lies, the module doesn't load.

## The three connection paths (plus one)

Everything that connects to D's Luck is described by a `.ds`:

| Kind | What it is | Compiled? | Power |
|---|---|---|---|
| **Src** (`core`) | Edit/replace engine source directly | Rebuild core | Total — you ARE the engine; keep `core.dsluck.ds` honest |
| **Plugin** (`plugin`) | Native library + `.ds` | Yes (any language exporting C) | Swaps/extends family slots: renderer, physics3d… |
| **Extension** (`extension`) | Script package + `.ds` | No (Wren) | Adds tools/elements using *existing* APIs; hot-reloadable |
| **Contract** (`contract`) | Family definition ("header side") | n/a | What a plugin must export; can introduce NEW families |

All four flow through the same parser → validator → loader in the core.

## Format

```ds
dspec 1 {
    kind:       plugin
    name:       "physics3d-jolt"
    version:    "1.0.0"
    abi:        1                  // core ABI built against (must be <= engine's)
    library:    physics_jolt       // base name; loader adds lib/.so/.dll per platform
    implements: physics3d@1        // the family contract this module serves

    provides {
        fn dsl_physics_step "(dt f32)"          // required by family contract
        fn raycast_world  "(origin v3, dir v3) -> hit"   // beyond the minimum

        element rigidbody                        // scene elements it adds
        element collision_volume
        event  contact_began = 2001              // events flow on the core bus
        tool   "Physics Probe"                   // editor tool contribution
    }

    lifecycle {
        setup:  "init(gravity) once per scene"
        frame:  "begin(dt) -> step(dt) -> end() per tick"
        memory: "owns its bodies; freed in shutdown()"
        thread: "engine thread"
    }
}
```

**Grammar (informal):** `dspec <int>` then a `{ }` block of declarations.
`//` line comments. Keys with values: `kind name version family abi library
script implements (@version)`. Two sections: `provides { fn|element|event|tool … }`
and `lifecycle { key: "free text" }`. Strings are double-quoted.
v1 caps: 24 provides entries, 12 lifecycle notes. Specs stay small; the
loader is fixed-memory by design (per D11 budgets).

## What the loader does with a `.ds`

```
scan dir → parse → validate → register by kind
                                 │
            plugin ── library file exists? ──no──> state: missing_library (graceful)
                 │yes
                 dlopen ── fails? ──> state: load_failed (error recorded)
                 │
                 family contract symbols all present? ──no──> load_failed
                 │yes
                 dsl_<family>_probe() if exported ──> result stored
                 │
                 state: loaded ◄── your renderer/physics/etc is LIVE
```

Plugin states at a glance: `1 registered · 2 loaded · 3 missing_library · 4 load_failed`
(`3` is not an error — Box3D's .ds proves it: spec valid, code not built yet.)

The **probe convention**: `uint dsl_<family>_probe()` — an optional health
check the loader calls once after a successful contract check. The null
renderer returns `0xD51C` ("DSLC"), and the host test asserts it. Self-describing
plugins that answer when called: that's the standard we keep.

## Contracts: the "header" side

`core/contracts/renderer.ds` is the renderer family written as a `.ds`
(`kind: contract`). Built-in families are also compiled into the core
(`families.d`); a *registered contract file overrides the built-in table* —
which is how a user introduces an entirely **new family** without touching
engine source: write `mycore_foo.ds` (contract) + `foo_impl.ds` (plugin) +
a `.so`. The loader matches them by `family:`/`implements:`.

## Naming

`.ds` won over `.s` deliberately: `.s` is assembly source in every C
toolchain on the planet. Also — dice. 🎲
