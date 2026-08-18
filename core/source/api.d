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
