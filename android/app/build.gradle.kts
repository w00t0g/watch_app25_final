plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.okn.watch_app25"
    compileSdk = flutter.compileSdkVersion

    // Fixe NDK-Version (wie gewünscht)
    ndkVersion = "29.0.13846066"

    defaultConfig {
        applicationId = "com.okn.watch_app25"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        // Debug: kein Shrinking
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // Release: für jetzt ebenfalls ohne Shrinking
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // leer – Flutter verwaltet seine Abhängigkeiten
}
