import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing.
//
// Credentials live in android/key.properties, which is gitignored; the keystore
// itself is deliberately NOT committed either (see .gitignore). Both are
// required to sign, so a fresh clone falls back to the debug key rather than
// failing the build outright - that fallback is what lets CI and a fresh clone
// still produce an installable debug-signed release for local testing.
//
// NOTE: `storeFile` is resolved relative to the *app module* (android/app), not
// to rootProject (android/). Resolving it against rootProject silently points at
// android/<name>.jks, the existence check fails, and the build falls back to the
// debug key - producing a "release" APK signed with CN=Android Debug, which
// looks fine and installs fine but cannot be published. Always confirm the
// signer with apksigner after changing this.
//
// Warning: the upload key is effectively permanent. Android will not let you
// update an installed app with a different key; a lost key means the app must be
// uninstalled before reinstalling. Back up android/app/upload-keystore.jks
// together with key.properties somewhere durable.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let {
    file(it)   // relative to android/app/
} ?: null
val hasReleaseKey = releaseStoreFile != null && releaseStoreFile.exists()

android {
    namespace = "com.mobiletel.incomingcall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mobiletel.incomingcall"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no upload key is configured, so a
            // fresh clone can still produce an installable artefact. A
            // debug-signed release will NOT install over a properly signed one
            // and cannot be published - check the build output for which key was
            // actually used before shipping.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 shrinks the Dart AOT snapshot too, so a bad keep rule shows up
            // as a runtime crash that no unit test catches. See proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
