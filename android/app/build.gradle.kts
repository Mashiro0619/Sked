import java.util.Properties
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.ValueSource
import org.gradle.api.provider.ValueSourceParameters

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

abstract class RustlsAndroidVersion : ValueSource<String, RustlsAndroidVersion.Parameters> {
    interface Parameters : ValueSourceParameters {
        val cargoLock: RegularFileProperty
    }

    override fun obtain(): String {
        val lines = parameters.cargoLock.get().asFile.readLines()
        val packageIndex = lines.indexOfFirst {
            it.trim() == "name = \"rustls-platform-verifier-android\""
        }
        check(packageIndex >= 0) {
            "rustls-platform-verifier-android is missing from rust/Cargo.lock"
        }
        return lines.drop(packageIndex + 1)
            .takeWhile { it.trim() != "[[package]]" }
            .first { it.trimStart().startsWith("version = ") }
            .substringAfter('"')
            .substringBefore('"')
    }
}

val rustlsAndroidVersion = providers.of(RustlsAndroidVersion::class.java) {
    parameters.cargoLock.set(layout.projectDirectory.file("../../rust/Cargo.lock"))
}

repositories {
    maven {
        url = uri(
            "https://github.com/rustls/rustls-platform-verifier/raw/" +
                "maven-archive/android-release-support/maven/",
        )
        content { includeGroup("org.rustls") }
    }
}

configurations.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.rustls" && requested.name == "rustls-platform-verifier") {
            useVersion(rustlsAndroidVersion.get())
            because("The Android verifier must match rust/Cargo.lock")
        }
    }
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
    implementation("org.rustls:rustls-platform-verifier")
    testImplementation("junit:junit:4.13.2")
    // Own the streaming JSON dependency used by the filtered D2D artifact.
    // This is already the version resolved by flutter_local_notifications.
    implementation("com.google.code.gson:gson:2.12.0")
    // Own the Activity Result API dependency used by MainActivity explicitly.
    // Keep the version already resolved by Flutter's Android embedding.
    implementation("androidx.activity:activity:1.9.0")
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
