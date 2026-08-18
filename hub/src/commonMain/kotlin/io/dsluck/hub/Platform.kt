package io.dsluck.hub

/** Human-readable platform line, shown on the Cores tab. */
expect fun platformName(): String

/**
 * CPU ABIs the device actually runs, most-preferred first.
 * Vital on Android Go hardware: many ship a 32-bit userspace on 64-bit
 * silicon, in which case armeabi-v7a (not arm64-v8a) is what loads.
 */
expect fun deviceAbis(): String

/**
 * Attempts to load the bundled D core (libdsluck.so).
 * M0 proves the pipeline (D source → .so → inside the APK).
 * A real JNI bridge with dsl_engine_version() arrives in milestone M1.
 */
expect fun nativeCoreStatus(): String
