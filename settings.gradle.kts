pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}

rootProject.name = "dsluck"

include(":hub")
// Future modules (in dependency order):
//   :core-android   — JNI bridge to libdsluck.so        (milestone M1)
//   :editor         — the engine editor app              (milestone M2)
//   :renderer-filament — swappable render backend shim   (milestone M2+)
