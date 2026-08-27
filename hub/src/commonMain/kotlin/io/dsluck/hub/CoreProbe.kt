package io.dsluck.hub

/** One frame of truth from a live core, as shown on the Cores tab. */
data class ProbeSnapshot(
    val frame: Long,
    val fps: Float,
    val entities: Int,
    val memBytes: Long,
)

/**
 * Owns a temporary DslCore instance for the on-screen live probe.
 * Implementations: JNI bridge on Android; stubs elsewhere (until the
 * desktop bridge lands).
 *
 * Contract: call [available] first; [start] before [tick]/[snapshot];
 * [stop] releases the core. Failure to bundle natives must never crash.
 */
expect class CoreProbeHandle() {
    fun available(): Boolean
    fun start(): Boolean
    fun tick(dtSeconds: Double)
    fun snapshot(): ProbeSnapshot
    fun stop()
}
