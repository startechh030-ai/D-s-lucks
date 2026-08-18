package io.dsluck.hub

import android.os.Build

actual fun platformName(): String =
    "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

actual fun deviceAbis(): String =
    Build.SUPPORTED_ABIS.joinToString(" · ")

actual fun nativeCoreStatus(): String = try {
    System.loadLibrary("dsluck")
    "libdsluck.so loaded — ABI bridge arrives in M1"
} catch (e: UnsatisfiedLinkError) {
    "not bundled in this build — CI job 'core' produces it"
}
