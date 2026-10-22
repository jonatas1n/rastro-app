plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.appdistribution")
}

android {
    namespace = "com.jotadevsol.rastro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jotadevsol.rastro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            firebaseAppDistribution {
                releaseNotes = System.getenv("RELEASE_NOTES") ?: "Build de teste via Gradle."
                groups = System.getenv("FIREBASE_GROUPS") ?: "all"
                artifactType = "APK"
                artifactPath =
                    "${project.rootDir.parentFile}/build/app/outputs/flutter-apk/app-release.apk"
                // Auth: service account JSON path (do not commit). Example:
                // serviceCredentialsFile =
                //     System.getenv("FIREBASE_SERVICE_ACCOUNT_FILE") ?: ""
                // Or set GOOGLE_APPLICATION_CREDENTIALS to the service account path.
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase Android SDK — versões dos produtos vêm do BoM.
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-analytics")
}
