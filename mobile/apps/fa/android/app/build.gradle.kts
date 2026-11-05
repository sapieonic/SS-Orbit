import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties (gitignored; see mobile/README.md, "Release signing").
// storeFile is an absolute path, or relative to android/app:
//   storeFile=/home/me/keys/orbit-upload.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// Without the file, dev release builds use the debug key (so `flutter run --release` works) and
// staging/prod release builds fail. Debug builds never need it.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val missingKeyFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .filter { keyProperties.getProperty(it).isNullOrBlank() }
val hasReleaseKey = keyPropertiesFile.exists() && missingKeyFields.isEmpty()

android {
    namespace = "com.shanmukhaagritec.orbit.fa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.shanmukhaagritec.orbit.fa"
        // Android 8+ (mobile/implementation-plan.md, "Low-end phones").
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // dev and staging get their own application IDs so all three install side by side.
    // Dart reads the flavour through `appFlavor` (package:flutter/services.dart).
    buildFeatures {
        resValues = true
    }
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Orbit FA Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Orbit FA Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Orbit FA")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The upload key when key.properties is complete, else the debug key. Only dev release
            // may ship with the debug key; the check below stops staging and prod.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

// Stop release builds that would be signed wrongly: staging/prod without key.properties, or any
// release with an incomplete key.properties. The guarded tasks depend on a check task that has no
// outputs, so it runs every time (never UP-TO-DATE) but only when a guarded release task is in the
// build. Configuring the project and debug builds, e.g. `flutter build apk --debug --flavor dev`,
// are not affected.
val releaseSigningError: String? =
    when {
        !keyPropertiesFile.exists() ->
            "Staging and prod release builds need the upload key in android/key.properties " +
                "(storeFile, storePassword, keyAlias, keyPassword). See mobile/README.md, " +
                "\"Release signing\". Only the dev flavour may use the debug key."
        missingKeyFields.isNotEmpty() ->
            "android/key.properties is missing ${missingKeyFields.joinToString()}. " +
                "See mobile/README.md, \"Release signing\"."
        else -> null
    }
releaseSigningError?.let { message ->
    val signingCheck = tasks.register("checkReleaseSigning") {
        description = "Fails the build: release signing is not set up for this flavour."
        doLast { throw GradleException(message) }
    }
    val flavors =
        if (keyPropertiesFile.exists()) listOf("Dev", "Staging", "Prod") else listOf("Staging", "Prod")
    // pre<Variant>Build starts every APK and app bundle build; the packaging and bundle signing
    // tasks are a second anchor.
    val guarded = flavors.flatMap { f ->
        listOf("pre${f}ReleaseBuild", "package${f}Release", "sign${f}ReleaseBundle")
    }.toSet()
    tasks.configureEach {
        if (name in guarded) dependsOn(signingCheck)
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
