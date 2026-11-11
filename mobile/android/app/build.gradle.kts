import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (git-ignored, see key.properties.example and ../ANDROID_RELEASE.md).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// A Play Store bundle must never be signed with the debug key: fail instead of producing one by accident.
gradle.taskGraph.whenReady {
    if (!keystorePropertiesFile.exists() && allTasks.any { it.name == "bundleRelease" }) {
        throw GradleException(
            "android/key.properties not found: refusing to build a release app bundle signed with the debug key. " +
                "See mobile/ANDROID_RELEASE.md."
        )
    }
}

android {
    // The code package (kept so MainActivity does not have to move). The Play / Firebase id is applicationId below.
    namespace = "com.thapar.roaddistress"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The id of the app that is already published on Google Play (and registered in Firebase). Never change it.
        applicationId = "com.distress.roadmanager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Upload key when android/key.properties exists; otherwise the debug key, so that
            // `flutter run --release` / a test APK still work (bundleRelease refuses, see above).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
