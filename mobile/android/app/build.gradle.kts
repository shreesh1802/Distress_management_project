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
// It only exists on the machine that signs store releases.
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
    namespace = "com.distress.roadmanager"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The id of the app that is already published on Google Play and registered in Firebase. Never change it.
        applicationId = "com.distress.roadmanager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Without key.properties, fall back to the debug key so everyone else can still build and test an APK
    // (bundleRelease refuses, see above).
    val hasReleaseKey = keystorePropertiesFile.exists()

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            // Keep rules of the USB webcam library (its native code calls these classes by name).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Opens a UVC (USB webcam) directly through the phone's USB port. Android's normal camera system does not
    // list most USB webcams, so the live screen's "USB webcam" option goes through this instead.
    // A copy of com.herohan:UVCAndroid:1.0.13 whose native libuvc was rebuilt with a more tolerant stream
    // negotiation (some cheap webcams answer the format probe slightly differently and were refused with
    // "could not negotiate with camera: err=-51"). Its own dependencies are listed by hand because a local
    // .aar does not bring them along.
    implementation(files("libs/UVCAndroid-1.0.13-patched.aar"))
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.annotation:annotation:1.8.0")
    implementation("androidx.legacy:legacy-support-v4:1.0.0")
    implementation("cn.hutool:hutool-core:5.8.35")
}

flutter {
    source = "../.."
}
