/**
 * ============================================================================
 * D's Luck — PUBLIC ABI  (the one stable contract)
 * ----------------------------------------------------------------------------
 * Everything the hub, editor, plugins, and scripting runtimes can see is
 * declared here as extern(C). Nothing else crosses the boundary.
 *
 * REPLACEABILITY RULE: any .so that exports these symbols at the matching
 * DSL_ABI_VERSION is a valid D's Luck core — ours, a fork, a minimal test
 * core, or a user's custom core written in another language entirely.
 *
 * Memory ownership: core creates it, core frees it (dsl_core_destroy).
 * Strings returned are borrowed: valid until the core is destroyed.
 * ============================================================================
 */
module api;

import dsluck.core.loop;
import dsluck.core.events;
import dsluck.scene.entity;
import dsluck.memory;
import dsluck.addons.dspec : DsSpec, dsParseFile, dsLastError;
import dsluck.addons.loader : AddonRegistry, dsScanAddons, dsUnloadAll, dsLoaderLastError;
import core.stdc.string : memcpy;

/// Bump on any breaking change to this file's layout or behavior.
enum uint DSL_ABI_VERSION = 1;

/// Frame/core snapshot consumed by the Debug overlay (hub shows FPS, memory).
extern (C) struct DslStats
{
    double time;
    double delta;
    ulong  frame;
    float  fps;
    uint   entitiesAlive;
    uint   entityCapacity;
    ulong  allocBytesLive;
    ulong  allocCount;
}

extern (C) @nogc nothrow:

// ---------------------------------------------------------------- identity
uint dsl_abi_version()
{
    return DSL_ABI_VERSION;
}

const(char)* dsl_engine_name()
{
    return "D's Luck";   // D string literals are null-terminated
}

const(char)* dsl_engine_version()
{
    return "0.0.1-alpha";
}

// ---------------------------------------------------------------- lifecycle
DslCore* dsl_core_create()
{
    auto core = cast(DslCore*) dslAlloc(DslCore.sizeof, "core");
    if (core is null)
        return null;
    *core = DslCore.init;
    core.start();
    return core;
}

void dsl_core_destroy(DslCore* core)
{
    if (core is null)
        return;
    core.stop();
    if (core.addons !is null)
    {
        dsUnloadAll(core.addons);
        dslFree(core.addons, AddonRegistry.sizeof);
        core.addons = null;
    }
    dslFree(core, DslCore.sizeof);
}

// ---------------------------------------------------------------- runtime
void dsl_core_tick(DslCore* core, double dt)
{
    if (core is null)
        return;
    core.tick(dt);
}

void dsl_core_stats(const(DslCore)* core, DslStats* outStats)
{
    if (core is null || outStats is null)
        return;
    outStats.time           = core.clock.time;
    outStats.delta          = core.clock.delta;
    outStats.frame          = core.clock.frame;
    outStats.fps            = core.clock.fps;
    outStats.entitiesAlive  = core.entities.aliveCount;
    outStats.entityCapacity = core.entities.capacity;
    outStats.allocBytesLive = dslBytesLive();
    outStats.allocCount     = dslAllocCount();
}

// ---------------------------------------------------------------- entities
/// Kind: 0=box-shaped caller error, use EntityKind: 1 box, 2 capsule, 3 cone.
int dsl_entity_spawn(DslCore* core, int kind, float x, float y, float z)
{
    if (core is null || kind < 1 || kind > 4)
        return -1;
    auto id = core.entities.spawn(cast(EntityKind) kind, x, y, z);
    if (id >= 0)
        core.events.push(DslEvent.entitySpawned);
    return id;
}

int dsl_entity_kill(DslCore* core, int id)
{
    if (core is null)
        return 0;
    if (core.entities.kill(id))
    {
        core.events.push(DslEvent.entityKilled);
        return 1;
    }
    return 0;
}

// ---------------------------------------------------------------- events
/// Pops the next pending event code (0 = none). UI/scripts poll per frame.
int dsl_event_poll(DslCore* core)
{
    if (core is null)
        return 0;
    return core.events.poll();
}

// ---------------------------------------------------------------- addons
/// A "module/addon" is anything described by a .ds spec:
/// core · contract · plugin · extension — one pattern, four kinds.
extern (C) struct DslAddonInfo
{
    char[48]  name;
    char[24]  family;
    char[12]  versionStr;
    int kind;           /// 1 core · 2 contract · 3 plugin · 4 extension
    int state;          /// 0 invalid · 1 registered · 2 loaded · 3 missing lib · 4 failed
    int abi;
    int providesCount;
    int probeValue;     /// dsl_<family>_probe() result when the plugin has one
}

/// Scans a directory (one subdir level) for .ds specs and registers/loads
/// everything found. Returns addon count (0 if the directory is absent).
int dsl_core_load_addons(DslCore* core, const(char)* dir)
{
    if (core is null || dir is null)
        return 0;
    if (core.addons is null)
    {
        core.addons = cast(AddonRegistry*) dslAlloc(AddonRegistry.sizeof, "addons");
        if (core.addons is null)
            return 0;
        *core.addons = AddonRegistry.init;
    }
    dsScanAddons(core.addons, &core.events, dir, DSL_ABI_VERSION);
    return core.addons.count;
}

int dsl_addon_count(DslCore* core)
{
    if (core is null || core.addons is null)
        return 0;
    return core.addons.count;
}

int dsl_addon_info(DslCore* core, int index, DslAddonInfo* outInfo)
{
    if (core is null || core.addons is null || outInfo is null)
        return 0;
    if (index < 0 || index >= core.addons.count)
        return 0;

    auto e = &core.addons.entries[index];
    memcpy(outInfo.name.ptr,       e.name.ptr,       48);
    memcpy(outInfo.family.ptr,     e.family.ptr,     24);
    memcpy(outInfo.versionStr.ptr, e.versionStr.ptr, 12);
    outInfo.kind          = e.kind;
    outInfo.state         = e.state;
    outInfo.abi           = e.abi;
    outInfo.providesCount = e.providesCount;
    outInfo.probeValue    = e.probeValue;
    return 1;
}

int dsl_addon_probe(DslCore* core, int index)
{
    if (core is null || core.addons is null)
        return 0;
    if (index < 0 || index >= core.addons.count)
        return 0;
    return core.addons.entries[index].probeValue;
}

/// Standalone .ds validation for tools and CI: 1 = valid spec, 0 = invalid
/// (see dsl_last_error for the reason).
int dsl_spec_validate_file(const(char)* path)
{
    if (path is null)
        return 0;
    DsSpec spec;
    return dsParseFile(path, &spec) ? 1 : 0;
}

/// Last parser/validation error ("no error" when clean).
const(char)* dsl_last_error()
{
    return dsLastError();
}

/// Last loader error (dlopen failures, missing symbols, ...).
const(char)* dsl_loader_last_error()
{
    return dsLoaderLastError();
}
