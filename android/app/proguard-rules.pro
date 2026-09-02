# WorkManager opens its Room database implementation by reflection during
# AndroidX Startup. R8's full-mode optimisation can otherwise remove the
# generated no-argument constructor, causing the process to crash before the
# Flutter activity is created in release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
