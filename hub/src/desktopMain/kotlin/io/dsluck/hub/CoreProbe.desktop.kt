package io.dsluck.hub

/** Desktop stub until the desktop bridge lands (SDL shell milestone). */
actual class CoreProbeHandle actual constructor() {
    actual fun available(): Boolean = false
    actual fun start(): Boolean = false
    actual fun tick(dtSeconds: Double) {}
    actual fun snapshot(): ProbeSnapshot = ProbeSnapshot(0, 0f, 0, 0)
    actual fun stop() {}
}
