plugins {
    kotlin("multiplatform")
    id("com.android.application")
    id("org.jetbrains.compose")
    id("org.jetbrains.kotlin.plugin.compose")
}

kotlin {
    jvmToolchain(17)

    androidTarget()
    jvm("desktop")

    sourceSets {
        // jvm("desktop") is declared imperatively above, so its source-set
        // accessors are NOT auto-generated — pull it in explicitly.
        // (commonMain/androidMain accessors come free from the AGP + KGP plugins.)
        val desktopMain by getting

        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.materialIconsExtended)
            implementation(compose.ui)
            implementation(compose.components.resources)
        }
        androidMain.dependencies {
            implementation("androidx.activity:activity-compose:1.9.2")
            implementation("androidx.core:core-ktx:1.13.1")
        }
        desktopMain.dependencies {
            implementation(compose.desktop.currentOs)
        }
    }
}

android {
    namespace = "io.dsluck.hub"
    compileSdk = 34

    defaultConfig {
        applicationId = "io.dsluck.hub"
        minSdk = 26              // Vulkan-era devices; mobile-first per spec
        targetSdk = 34
        versionCode = 1
        versionName = "0.0.1-alpha"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets["main"].jniLibs.srcDir("src/androidMain/jniLibs")
}

// Desktop (Windows/macOS/Linux) hub — same UI code, `gradle :hub:run`.
compose.desktop {
    application {
        mainClass = "io.dsluck.hub.MainKt"
    }
}
