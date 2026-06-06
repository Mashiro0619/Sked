import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mashiro.sked"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

pluginManager.withPlugin("org.jetbrains.kotlin.android") {
    extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>("kotlin") {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
}

flutter {
    source = "../.."
}
