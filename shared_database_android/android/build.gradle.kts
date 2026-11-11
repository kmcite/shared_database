// Flutter Android *plugin* module (library). Do NOT apply
// dev.flutter.flutter-gradle-plugin here — the app's plugin loader already
// registers the `flutter` extension on this project; applying the plugin again
// breaks consumer builds ("extension flutter already registered").
//
// App modules (:app) should use flutter-gradle-plugin; this file should not.

group = "dev.loner.shared_database"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}

android {
    namespace = "dev.loner.shared_database"

    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
