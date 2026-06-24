plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Le plugin Google Services (Firebase) n'est appliqué que si
// google-services.json est présent. Tant que le projet Firebase n'est pas
// créé (story 1.1), le build doit rester fonctionnel sans ce fichier —
// voir AnalyticsService.initialize() pour le mode dégradé côté Dart.
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "⚠️  android/app/google-services.json absent — plugin Google " +
            "Services non appliqué, Firebase Analytics/Crashlytics désactivés.",
    )
}

android {
    namespace = "fr.junade.hex_haven"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.junade.hex_haven"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk forcé à 23 : requis par google_mobile_ads et games_services
        // (Play Games Services v2) — flutter.minSdkVersion serait insuffisant.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
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
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
