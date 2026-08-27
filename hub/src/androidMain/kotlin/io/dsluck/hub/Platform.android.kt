package io.dsluck.hub

import android.os.Build

actual fun platformName(): String =
    "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

actual fun deviceAbis(): String =
    Build.SUPPORTED_ABIS.joinToString(" · ")

actual fun nativeCoreStatus(): String =
    if (DsluckBridge.available()) {
        "${DsluckBridge.engineName()} ${DsluckBridge.engineVersion()} · " +
            "ABI v${DsluckBridge.abiVersion()} — LIVE on this device"
    } else {
        "not bundled in this build — CI job 'core' produces it"
    }
