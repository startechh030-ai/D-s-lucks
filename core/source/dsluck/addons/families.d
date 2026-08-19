/**
 * D's Luck — built-in module family contracts.
 *
 * A family is a named set of extern(C) symbols. A plugin implementing a
 * family must export every required symbol — that's what "replaceable"
 * means mechanically. Contracts can also be shipped as .ds files
 * (kind: contract) to override or extend this table; the loader checks
 * registered contracts first, then falls back here.
 */
module dsluck.addons.families;

struct FamilyContract
{
    string name;
    immutable(string)[] requiredSymbols;
}

/// Renderer v1 — Filament shim ships this; any custom renderer must too.
private __gshared immutable string[] RENDERER_SYMS = [
    "dsl_renderer_init",
    "dsl_renderer_resize",
    "dsl_renderer_submit",
    "dsl_renderer_shutdown",
];

/// Declared now, enforced when their milestones land (M5+). Empty = plugin
/// is validated by spec only until the family contract is finalized.
private __gshared immutable string[] EMPTY_SYMS = [];

__gshared immutable FamilyContract[] FAMILY_CONTRACTS = [
    FamilyContract("renderer",  cast(immutable(string)[]) RENDERER_SYMS),
    FamilyContract("physics3d", cast(immutable(string)[]) EMPTY_SYMS),
    FamilyContract("physics2d", cast(immutable(string)[]) EMPTY_SYMS),
    FamilyContract("scripting", cast(immutable(string)[]) EMPTY_SYMS),
    FamilyContract("sound",     cast(immutable(string)[]) EMPTY_SYMS),
    FamilyContract("assets",    cast(immutable(string)[]) EMPTY_SYMS),
];

/// Null when the family is custom (allowed: plugin declares its own
/// symbols under `provides { fn ... }` and no check is enforced yet).
public const(FamilyContract)* findContract(const(char)[] family) nothrow @nogc
{
    foreach (ref c; FAMILY_CONTRACTS)
        if (c.name == family)
            return &c;
    return null;
}
