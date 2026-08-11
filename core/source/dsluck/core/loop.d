/**
 * D's Luck — core instance.
 *
 * This struct IS the core. The hub/editor loads libdsluck.so and calls
 * dsl_core_create() — swap the .so, swap the engine. The API in api.d
 * is the only contract, versioned by DSL_ABI_VERSION.
 */
module dsluck.core.loop;

import dsluck.core.time;
import dsluck.core.events;
import dsluck.scene.entity;
import dsluck.scene.camera;

struct DslCore
{
    FrameClock clock;
    EventBus   events;
    EntityPool entities;
    Camera     mainCamera;
    bool       running;

    void start() @nogc nothrow
    {
        running = true;
        events.push(DslEvent.coreStarted);
    }

    void stop() @nogc nothrow
    {
        running = false;
        events.push(DslEvent.coreShutdown);
    }

    void tick(double dt) @nogc nothrow
    {
        if (!running)
            return;
        clock.tick(dt);
        // per-frame systems update here: physics step, script dispatch,
        // render submit — each delegated to the loaded plugin module.
    }
}
