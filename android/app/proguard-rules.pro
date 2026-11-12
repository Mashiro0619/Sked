# WorkManager opens its Room database implementation by reflection during
# AndroidX Startup. R8's full-mode optimisation can otherwise remove the
# generated no-argument constructor, causing the process to crash before the
# Flutter activity is created in release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}

# Rust calls the platform verifier through JNI, outside R8's call graph.
-keep,includedescriptorclasses class org.rustls.platformverifier.** { *; }
-keepclassmembers class com.mashiro.sked.SkedApplication {
    native <methods>;
}

# The application-owned file bridge is called by name from native workers.
-keep,includedescriptorclasses class com.mashiro.sked.AgentFileAccess {
    public java.lang.String call(java.lang.String);
    public void cancel(java.lang.String);
}

-keep,includedescriptorclasses class com.mashiro.sked.AgentPythonHost {
    public java.lang.String runtimeInfo();
    public java.lang.String call(java.lang.String);
    public void cancel(java.lang.String);
}
-keepclassmembers class com.mashiro.sked.AgentPythonService {
    native <methods>;
}
