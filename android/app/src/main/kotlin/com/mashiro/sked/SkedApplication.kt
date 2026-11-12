package com.mashiro.sked

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File

class SkedApplication : Application() {
    val agentFileAccess: AgentFileAccess by lazy { AgentFileAccess(this) }
    private val agentPythonHost by lazy { AgentPythonHost(this) }

    override fun onCreate() {
        super.onCreate()
        System.loadLibrary("sked_agent_core")
        val processName = if (Build.VERSION.SDK_INT >= 28) Application.getProcessName()
            else File("/proc/self/cmdline").readText().substringBefore('\u0000')
        if (processName == "$packageName:agent_python") return
        initializeRustPlatformVerifier(this)
        initializeRustFileAccessBridge(agentFileAccess)
        initializeRustPythonHost(agentPythonHost)
        Log.i("SkedAgent", "Android platform certificate verifier initialized")
    }

    private external fun initializeRustPlatformVerifier(context: Context)
    private external fun initializeRustFileAccessBridge(access: AgentFileAccess)
    private external fun initializeRustPythonHost(host: AgentPythonHost)
}
