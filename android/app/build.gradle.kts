import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties =
    Properties().apply {
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

fun keystoreProperty(name: String): String? =
    (keystoreProperties[name] as String?)?.trim()?.takeIf { it.isNotEmpty() }

val hasReleaseKeystore =
    keystoreProperty("keyAlias") != null &&
        keystoreProperty("keyPassword") != null &&
        keystoreProperty("storeFile") != null &&
        keystoreProperty("storePassword") != null

fun isReleaseBuildTask(taskName: String): Boolean {
    return taskName.equals("assembleRelease", ignoreCase = true) ||
        taskName.equals("bundleRelease", ignoreCase = true)
}

android {
    namespace = "com.mashiro.sked"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mashiro.sked"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
                storeFile = keystoreProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Keep the app-specific R8 rules explicit. Flutter also adds this
            // file when resource shrinking is enabled, but declaring it here
            // keeps standalone Android release builds on the same contract.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.matching { isReleaseBuildTask(it.name) }.configureEach {
    doFirst {
        if (!hasReleaseKeystore) {
            throw GradleException(
                "Release builds require android/key.properties with keyAlias, " +
                    "keyPassword, storeFile, and storePassword.",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // A native WorkManager host keeps the rolling notification projection
    // current after boot and time-zone changes without parsing app data.
    implementation("androidx.work:work-runtime-ktx:2.10.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
