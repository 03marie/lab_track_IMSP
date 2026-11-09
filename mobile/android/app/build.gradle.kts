plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "bj.imsp.labtrack"
    compileSdk = flutter.compileSdkVersion
    // NDK déjà installé sur le PC : évite le téléchargement de la version par défaut de Flutter (28.2, ~1,2 Go).
    ndkVersion = "27.0.12077973"
    buildToolsVersion = "35.0.0" // déjà installé (évite le téléchargement des Build-Tools 36)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "bj.imsp.labtrack"
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

    // Téléphones Android 64 bits uniquement (presque tous depuis 2017) : on retire de l'APK
    // les bibliothèques natives x86/x86_64/armeabi-v7a (dont celles de ML Kit, ~9 Mo).
    // (abiFilters était ignoré avec Flutter ; l'exclusion à l'empaquetage est fiable.)
    packaging {
        jniLibs {
            excludes += setOf("lib/x86/**", "lib/x86_64/**", "lib/armeabi-v7a/**")
        }
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
