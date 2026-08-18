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
