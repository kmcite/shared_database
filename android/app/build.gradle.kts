plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android_file_picker (file_picker's Android impl) is compiled from the pub
// cache — this project registers plugins manually instead of using the
// generated plugin registrant, so its sources are added here directly.
val pubCacheHosted = File(
    System.getenv("LOCALAPPDATA")
        ?: "${System.getProperty("user.home")}/AppData/Local",
    "Pub/Cache/hosted/pub.dev",
)
val filePickerAndroidSrcDir = pubCacheHosted
    .listFiles()
    ?.firstOrNull { it.name.startsWith("android_file_picker-") }
    ?.resolve("android/src/main/kotlin")
    ?.absolutePath
    ?: error("android_file_picker not found in pub cache — run flutter pub get")

android {
    namespace = "dev.loner.shared_database"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.loner.shared_database"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs(
                "src/main/kotlin",
                "../../shared_database_android/android/src/main/kotlin",
                filePickerAndroidSrcDir,
            )
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("androidx.lifecycle:lifecycle-runtime:2.10.0")
    implementation("androidx.annotation:annotation:1.11.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
