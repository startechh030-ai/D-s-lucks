package io.dsluck.hub

actual class CoreProbeHandle actual constructor() {

    private var handle: Long = 0L
    private val batch = LongArray(4)

    actual fun available(): Boolean = DsluckBridge.available()

    actual fun start(): Boolean {
        if (!available()) return false
        if (handle == 0L) {
            handle = DsluckBridge.coreCreate()
            if (handle != 0L) {
                // same story as the host smoke test: box + capsule on a grid
                DsluckBridge.spawn(handle, /*kind=*/1, 0f, 0.5f, 0f)
                DsluckBridge.spawn(handle, /*kind=*/2, 2f, 1f, 0f)
            }
        }
        return handle != 0L
    }

    actual fun tick(dtSeconds: Double) {
        if (handle != 0L) DsluckBridge.coreTick(handle, dtSeconds)
    }

    actual fun snapshot(): ProbeSnapshot {
        if (handle == 0L) return ProbeSnapshot(0, 0f, 0, 0)
        DsluckBridge.stats(handle, batch)
        return ProbeSnapshot(
            frame = batch[0],
            entities = batch[1].toInt(),
            memBytes = batch[2],
            fps = batch[3] / 1000f,
        )
    }

    actual fun stop() {
        if (handle != 0L) {
            DsluckBridge.coreDestroy(handle)
            handle = 0L
        }
    }
}
