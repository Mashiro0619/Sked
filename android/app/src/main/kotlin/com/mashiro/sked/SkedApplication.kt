package com.mashiro.sked

import android.app.Application
import android.content.Context
import android.util.Log

class SkedApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        System.loadLibrary("sked_agent_core")
        initializeRustPlatformVerifier(this)
        Log.i("SkedAgent", "Android platform certificate verifier initialized")
    }

    private external fun initializeRustPlatformVerifier(context: Context)
}
