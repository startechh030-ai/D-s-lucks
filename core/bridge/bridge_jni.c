/* ============================================================================
 * D's Luck — JNI bridge (Android shell ↔ libdsluck.so)
 *
 * Thin hand-written shim: Kotlin object DsluckBridge <-> core C ABI.
 *
 * NOTE (learned the hard way in CI): JNIEXPORT/JNICALL are linkage
 * attributes, NOT a return type. The return type must be stated per
 * function — hence the two-argument JNI_FN(ret, name) macro below.
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

/* Expands to: JNIEXPORT <ret> JNICALL Java_io_dsluck_hub_DsluckBridge_<name> */
#define JNI_FN(ret, name) JNIEXPORT ret JNICALL Java_io_dsluck_hub_DsluckBridge_##name

/* ---- identity ------------------------------------------------------------ */
JNI_FN(jint, abiVersion)(JNIEnv* env, jclass cls)
{
    (void)env; (void)cls;
    return (jint) dsl_abi_version();
}

JNI_FN(jstring, engineName)(JNIEnv* env, jclass cls)
{
    (void)cls;
    return (*env)->NewStringUTF(env, dsl_engine_name());
}

JNI_FN(jstring, engineVersion)(JNIEnv* env, jclass cls)
{
    (void)cls;
    return (*env)->NewStringUTF(env, dsl_engine_version());
}

/* ---- lifecycle (core pointer travels as a jlong handle) ------------------ */
JNI_FN(jlong, coreCreate)(JNIEnv* env, jclass cls)
{
    (void)env; (void)cls;
    return (jlong)(intptr_t) dsl_core_create();
}

JNI_FN(void, coreDestroy)(JNIEnv* env, jclass cls, jlong handle)
{
    (void)env; (void)cls;
    dsl_core_destroy((DslCore*)(intptr_t) handle);
}

JNI_FN(void, coreTick)(JNIEnv* env, jclass cls, jlong handle, jdouble dt)
{
    (void)env; (void)cls;
    dsl_core_tick((DslCore*)(intptr_t) handle, (double) dt);
}

/* ---- scene probe --------------------------------------------------------- */
JNI_FN(jint, spawn)(JNIEnv* env, jclass cls, jlong handle,
                    jint kind, jfloat x, jfloat y, jfloat z)
{
    (void)env; (void)cls;
    return (jint) dsl_entity_spawn((DslCore*)(intptr_t) handle,
                                   (int) kind, (float) x, (float) y, (float) z);
}

/* ---- stats batch (one JNI call per frame, not four) -----------------------
 * out[0] = frame · out[1] = entitiesAlive · out[2] = allocBytesLive
 * out[3] = fps * 1000 (fixed point, keeps everything in a LongArray)        */
JNI_FN(void, stats)(JNIEnv* env, jclass cls, jlong handle, jlongArray out)
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
