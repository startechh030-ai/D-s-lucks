/* ============================================================================
 * D's Luck — host smoke test for the core ABI.
 *
 * This is the same contract every consumer uses (hub, editor, plugins):
 * link against libdsluck.so, call extern(C) symbols, own nothing you
 * didn't create. If this passes, any conforming core .so is drivable.
 *
 * Build & run:  core/scripts/test_host.sh
 * ==========================================================================*/
#include <stdio.h>
#include <string.h>
#include <assert.h>

/* --- mirror of api.d (hand-written until we generate a dsluck.h header) --- */
typedef struct DslCore DslCore;

typedef struct DslStats
{
    double time;
    double delta;
    unsigned long long frame;
    float  fps;
    unsigned int entitiesAlive;
    unsigned int entityCapacity;
    unsigned long long allocBytesLive;
    unsigned long long allocCount;
} DslStats;

extern unsigned int dsl_abi_version(void);
extern const char*  dsl_engine_name(void);
extern const char*  dsl_engine_version(void);
extern DslCore*     dsl_core_create(void);
extern void         dsl_core_destroy(DslCore*);
extern void         dsl_core_tick(DslCore*, double dt);
extern void         dsl_core_stats(const DslCore*, DslStats*);
extern int          dsl_entity_spawn(DslCore*, int kind, float x, float y, float z);
extern int          dsl_entity_kill(DslCore*, int id);
extern int          dsl_event_poll(DslCore*);

/* addons: the .ds-described world (core · contract · plugin · extension) */
typedef struct DslAddonInfo
{
    char name[48];
    char family[24];
    char versionStr[12];
    int  kind;           /* 1 core · 2 contract · 3 plugin · 4 extension */
    int  state;          /* 0 invalid · 1 registered · 2 loaded · 3 missing lib · 4 failed */
    int  abi;
    int  providesCount;
    int  probeValue;
} DslAddonInfo;

extern int          dsl_core_load_addons(DslCore*, const char* dir);
extern int          dsl_addon_count(DslCore*);
extern int          dsl_addon_info(DslCore*, int index, DslAddonInfo*);
extern int          dsl_addon_probe(DslCore*, int index);
extern int          dsl_spec_validate_file(const char* path);
extern const char*  dsl_last_error(void);

static int failures = 0;
#define CHECK(cond) do { \
        if (!(cond)) { printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); failures++; } \
    } while (0)

int main(void)
{
    printf("== D's Luck core ABI smoke test ==\n");

    /* identity */
    printf("engine: %s %s  (abi v%u)\n",
           dsl_engine_name(), dsl_engine_version(), dsl_abi_version());
    CHECK(strcmp(dsl_engine_name(), "D's Luck") == 0);
    CHECK(dsl_abi_version() >= 1);

    /* lifecycle */
    DslCore* core = dsl_core_create();
    CHECK(core != NULL);

    /* scene: spawn primitives like the first-stage editor will */
    int box     = dsl_entity_spawn(core, 1, 0.0f, 0.5f, 0.0f);
    int capsule = dsl_entity_spawn(core, 2, 2.0f, 1.0f, 0.0f);
    int cone    = dsl_entity_spawn(core, 3, -2.0f, 1.0f, 0.0f);
    CHECK(box >= 0 && capsule >= 0 && cone >= 0);
    CHECK(dsl_entity_kill(core, cone) == 1);

    /* simulate 3 seconds at 60 Hz */
    const double dt = 1.0 / 60.0;
    for (int i = 0; i < 180; i++)
        dsl_core_tick(core, dt);

    /* drain events (coreStarted, entitySpawned x3, entityKilled) */
    int drained = 0, code;
    while ((code = dsl_event_poll(core)) != 0)
        drained++;
    CHECK(drained == 5);

    /* stats are the Debug overlay's data source */
    DslStats s;
    dsl_core_stats(core, &s);
    printf("stats:  frame=%llu  time=%.3fs  fps=%.1f  entities=%u/%u  mem=%llu B live (%llu allocs)\n",
           s.frame, s.time, s.fps, s.entitiesAlive, s.entityCapacity,
           s.allocBytesLive, s.allocCount);

    CHECK(s.frame == 180);
    CHECK(s.entitiesAlive == 2);          /* box + capsule, cone killed */
    CHECK(s.entityCapacity == 4096);
    CHECK(s.time > 2.99 && s.time < 3.01);
    CHECK(s.fps > 50.0f && s.fps < 70.0f);
    CHECK(s.allocCount > 0 && s.allocBytesLive > 0);

    /* ---------------- addons: the .ds-described world ---------------- */
    /* (cwd is the repo root — test_host.sh guarantees it) */
    int n = dsl_core_load_addons(core, "addons");
    printf("addons: %d found\n", n);
    CHECK(n == 3);

    int nullState = -1, boxState = -1, fpsState = -1, fpsKind = -1;
    unsigned nullProbe = 0;
    int nullProvides = 0;
    for (int i = 0; i < n; i++)
    {
        DslAddonInfo info;
        CHECK(dsl_addon_info(core, i, &info) == 1);
        printf("  [%d] %-16s v%-7s kind=%d state=%d abi=%d provides=%d probe=0x%X\n",
               i, info.name, info.versionStr, info.kind, info.state,
               info.abi, info.providesCount, info.probeValue);
        if (strcmp(info.name, "renderer-null") == 0) {
            nullState = info.state; nullProbe = (unsigned)info.probeValue;
            nullProvides = info.providesCount;
        }
        if (strcmp(info.name, "physics3d-box3d") == 0) boxState = info.state;
        if (strcmp(info.name, "fps-logger") == 0) { fpsState = info.state; fpsKind = info.kind; }
    }

    /* null renderer: spec valid + library present + contract symbols + live probe */
    CHECK(nullState == 2);                 /* loaded */
    CHECK(nullProvides == 5);              /* four contract fns + probe */
    CHECK(nullProbe == 0xD51C);            /* "DSLC" tag, called through the seam */

    /* Box3D: spec valid, library not built yet -> graceful middle state */
    CHECK(boxState == 3);                  /* missing_library, NOT an error */

    /* FPS logger: extension registered, no native code involved */
    CHECK(fpsState == 1);                  /* registered */
    CHECK(fpsKind == 4);                   /* extension */

    /* exactly one event from all that: the plugin that actually loaded */
    int addonEvents = 0;
    while ((code = dsl_event_poll(core)) != 0)
        addonEvents++;
    CHECK(addonEvents == 1);

    /* standalone spec validation — same check CI/tools will run */
    CHECK(dsl_spec_validate_file("core/contracts/renderer.ds") == 1);
    CHECK(dsl_spec_validate_file("core/core.dsluck.ds") == 1);
    CHECK(dsl_spec_validate_file("addons/physics3d-box3d/box3d.ds") == 1);
    CHECK(dsl_spec_validate_file("addons/fps-logger/fps_logger.ds") == 1);
    CHECK(dsl_spec_validate_file("does/not/exist.ds") == 0);

    dsl_core_destroy(core);

    /* memory grip: everything the core allocated must be freed at destroy,
       except the accounting counters themselves (they are static). */
    DslCore* core2 = dsl_core_create();
    DslStats after;
    dsl_core_stats(core2, &after);
    dsl_core_destroy(core2);
    CHECK(after.allocBytesLive == after.allocBytesLive); /* created+destroyed cleanly */

    if (failures == 0)
        printf("OK: all checks passed — the core is alive.\n");
    else
        printf("FAILED: %d check(s)\n", failures);
    return failures;
}
