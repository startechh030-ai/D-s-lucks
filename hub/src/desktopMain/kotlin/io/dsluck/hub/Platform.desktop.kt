package io.dsluck.hub

actual fun platformName(): String =
    "${System.getProperty("os.name")} ${System.getProperty("os.arch")} (desktop dev loop)"

actual fun deviceAbis(): String =
    System.getProperty("os.arch")

actual fun nativeCoreStatus(): String =
    "host build — run core/scripts/test_host.sh for ABI validation"
