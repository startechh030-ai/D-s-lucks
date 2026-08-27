/* ============================================================================
 * D's Luck — JNI bridge (Android shell ↔ libdsluck.so)
 *
 * Thin hand-written shim: Kotlin object DsluckBridge <-> core C ABI.
 * Compiled per ABI with the NDK clang together with the core, bundled into
 * the app's jniLibs. It translates nothing semantically — every function is
 * a straight pass through the api.d contract, handles are raw core pointers.
 * ==========================================================================*/
#include <jni.h>
#include <stdint.h>

/* ---- mirror of api.d (the C side of the seam) ---------------------------- */
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

extern unsigned int  dsl_abi_version(void);
extern const char*   dsl_engine_name(void);
extern const char*   dsl_engine_version(void);
extern DslCore*      dsl_core_create(void);
extern void          dsl_core_destroy(DslCore*);
extern void          dsl_core_tick(DslCore*, double dt);
extern void          dsl_core_stats(const DslCore*, DslStats*);
extern int           dsl_entity_spawn(DslCore*, int kind, float x, float y, float z);

#define JNI_FN(name) JNIEXPORT JNICALL Java_io_dsluck_hub_DsluckBridge_##name

/* ---- identity ------------------------------------------------------------ */
JNI_FN(abiVersion)(JNIEnv* env, jclass cls)
{
    (void)env; (void)cls;
    return (jint) dsl_abi_version();
}

JNI_FN(engineName)(JNIEnv* env, jclass cls)
{
    (void)cls;
    return (*env)->NewStringUTF(env, dsl_engine_name());
}

JNI_FN(engineVersion)(JNIEnv* env, jclass cls)
{
    (void)cls;
    return (*env)->NewStringUTF(env, dsl_engine_version());
}

/* ---- lifecycle (core pointer travels as a jlong handle) ------------------ */
JNI_FN(coreCreate)(JNIEnv* env, jclass cls)
{
    (void)env; (void)cls;
    return (jlong)(intptr_t) dsl_core_create();
}

JNI_FN(coreDestroy)(JNIEnv* env, jclass cls, jlong handle)
{
    (void)env; (void)cls;
    dsl_core_destroy((DslCore*)(intptr_t) handle);
}

JNI_FN(coreTick)(JNIEnv* env, jclass cls, jlong handle, jdouble dt)
{
    (void)env; (void)cls;
    dsl_core_tick((DslCore*)(intptr_t) handle, (double) dt);
}

/* ---- scene probe --------------------------------------------------------- */
JNI_FN(spawn)(JNIEnv* env, jclass cls, jlong handle,
              jint kind, jfloat x, jfloat y, jfloat z)
{
    (void)env; (void)cls;
    return (jint) dsl_entity_spawn((DslCore*)(intptr_t) handle,
                                   (int) kind, (float) x, (float) y, (float) z);
}

/* ---- stats batch (one JNI call per frame, not four) -----------------------
 * out[0] = frame · out[1] = entitiesAlive · out[2] = allocBytesLive
 * out[3] = fps * 1000 (fixed point, keeps everything in a LongArray)        */
JNI_FN(stats)(JNIEnv* env, jclass cls, jlong handle, jlongArray out)
{
    (void)cls;
    DslStats s;
    dsl_core_stats((const DslCore*)(intptr_t) handle, &s);

    jlong buf[4];
    buf[0] = (jlong) s.frame;
    buf[1] = (jlong) s.entitiesAlive;
    buf[2] = (jlong) s.allocBytesLive;
    buf[3] = (jlong)(s.fps * 1000.0f);

    (*env)->SetLongArrayRegion(env, out, 0, 4, buf);
}
