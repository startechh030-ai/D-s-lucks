package io.dsluck.hub

/**
 * Direct line into libdsluck.so. Every call is a pass-through of the core's
 * C ABI (api.d), nothing more. Libraries load lazily & exactly once; when
 * the APK wasn't built with bundled natives, [available] is false and every
 * UI path degrades to "not bundled" instead of crashing.
 */
object DsluckBridge {

    private val loaded: Boolean by lazy {
        try {
            System.loadLibrary("dsluck")      // the core
            System.loadLibrary("dsluck_jni")  // this bridge
            true
        } catch (t: Throwable) {
            false
        }
    }

    fun available(): Boolean = loaded

    // identity
    external fun abiVersion(): Int
    external fun engineName(): String
    external fun engineVersion(): String

    // lifecycle — the core pointer travels as a Long handle
    external fun coreCreate(): Long
    external fun coreDestroy(handle: Long)
    external fun coreTick(handle: Long, dtSeconds: Double)

    // scene probe
    external fun spawn(handle: Long, kind: Int, x: Float, y: Float, z: Float): Int

    // stats batch: [0]=frame [1]=entities [2]=allocBytesLive [3]=fps*1000
    external fun stats(handle: Long, out: LongArray)
}
