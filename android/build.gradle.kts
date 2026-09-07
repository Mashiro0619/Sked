allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// The upstream Android 15 edge-to-edge fix is currently published only as an
// immutable Git commit. That commit references Build.VERSION in
// TrustedWebActivity.java without importing android.os.Build. Patch that
// source only when the missing import is present so the dependency remains
// buildable, and make the operation idempotent for cached Gradle builds.
subprojects {
    if (name == "flutter_inappwebview_android") {
        afterEvaluate {
            val trustedWebActivity = file(
                "src/main/java/com/pichillilorenzo/flutter_inappwebview_android/" +
                    "chrome_custom_tabs/TrustedWebActivity.java",
            )
            if (!trustedWebActivity.isFile) return@afterEvaluate
            val source = trustedWebActivity.readText()
            if (
                source.contains("Build.VERSION.SDK_INT") &&
                !source.contains("import android.os.Build;")
            ) {
                trustedWebActivity.writeText(
                    source.replace(
                        "import android.net.Uri;",
                        "import android.net.Uri;\nimport android.os.Build;",
                    ),
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
