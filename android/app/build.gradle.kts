import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Charge android/key.properties (généré en CI depuis les secrets, ou en
// local si le dev a créé son propre keystore). Absent en local par défaut
// -> le build release retombe sur le debug keystore (comportement Flutter
// standard), mais en CI ce fichier est toujours présent.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
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
            // Utilise le keystore release (key.properties, généré en CI
            // depuis les secrets GitHub) s'il est présent, sinon retombe
            // sur le debug keystore pour que `flutter run --release`
            // fonctionne en local sans config supplémentaire.
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Flutter active R8 par défaut sur les builds release (même sans
            // isMinifyEnabled explicite ici) : on branche nos règles pour
            // éviter que R8 ne strippe le constructeur sans-argument de
            // WorkDatabase_Impl (cf. proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Requis par installSplashScreen() dans MainActivity.kt (splash natif
    // Android 12+ via l'API Theme.SplashScreen).
    implementation("androidx.core:core-splashscreen:1.0.1")
}

flutter {
    source = "../.."
}

// Workaround: Flutter Gradle plugin declares two @OutputFiles on the same
// task (outputFiles + getDependenciesFiles), which breaks Gradle 9.x strict
// validation. Disable state tracking as suggested by the error message.
// See: https://docs.gradle.org/9.1.0/userguide/incremental_build.html#sec:disable-state-tracking
afterEvaluate {
    tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
        doNotTrackState(
            "Flutter Gradle plugin has duplicate @OutputFiles annotations",
        )
    }
}
