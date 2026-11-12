package com.mashiro.sked

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import com.chaquo.python.internal.Common
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutionException

internal object AgentPythonProtocol {
    const val DESCRIPTOR = "com.mashiro.sked.AgentPythonService"
    const val HELLO = IBinder.FIRST_CALL_TRANSACTION
    const val READY = HELLO + 1
    const val START = HELLO + 2
    const val STOP = HELLO + 3
}

private class PythonHostFailure(val code: String, message: String) : Exception(message)

/** JNI calls run on Rust's blocking workers; connection callbacks use the app thread. */
class AgentPythonHost(context: Context) {
    private val application = context.applicationContext
    private val calls = ConcurrentHashMap<String, Call>()

    fun runtimeInfo(): String = reply {
        val info = application.applicationInfo
        val installed = application.packageManager.getPackageInfo(application.packageName, 0)
        val is64Bit = Process.is64Bit()
        val abis = if (is64Bit) Build.SUPPORTED_64_BIT_ABIS else Build.SUPPORTED_32_BIT_ABIS
        val selectedAbi = abis.first { abi ->
            try {
                application.assets.open(
                    "${Common.ASSET_DIR}/${Common.assetZip(Common.ASSET_STDLIB, abi)}",
                ).use { }
                true
            } catch (_: IOException) {
                false
            }
        }
        JSONObject()
            .put("pythonVersion", "3.11.17")
            .put("chaquopyVersion", "17.2.0")
            .put("selectedAbi", selectedAbi)
            .put("osArch", System.getProperty("os.arch"))
            .put("is64Bit", is64Bit)
            .put("packageName", application.packageName)
            .put("versionCode", if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong())
            .put("lastUpdateTime", installed.lastUpdateTime)
            .put("apkPaths", JSONArray(listOf(info.sourceDir) + (info.splitSourceDirs?.toList() ?: emptyList())))
            .put("nativeLibraryDir", info.nativeLibraryDir)
            .put("filesDir", application.filesDir.absolutePath)
            .put("cacheDir", application.cacheDir.absolutePath)
    }

    fun call(requestJson: String): String = reply {
        val request = JSONObject(requestJson)
        val id = request.getString("callId")
        when (request.getString("op")) {
            "beginCall" -> {
                val call = Call(
                    id,
                    File(request.getString("runDirectory")),
                    ParcelFileDescriptor.fromFd(request.getInt("cwdFd")),
                )
                if (calls.putIfAbsent(id, call) != null) {
                    call.releaseDirectory()
                    throw PythonHostFailure("admissionFailed", "This Python call is already registered.")
                }
                JSONObject()
            }
            "ready" -> requiredCall(id).ready()
            "start" -> requiredCall(id).start()
            "wait" -> requiredCall(id).waitForExit()
            "endCall" -> {
                val call = calls.remove(id)
                call?.close()
                JSONObject()
            }
            else -> throw PythonHostFailure("invalidSpec", "Unknown Python host operation.")
        }
    }

    fun cancel(callId: String) {
        calls[callId]?.cancel()
    }

    private fun requiredCall(id: String): Call = calls[id]
        ?: throw PythonHostFailure("admissionFailed", "The Python call is not registered.")

    private inner class Call(
        private val id: String,
        private val directory: File,
        private val cwd: ParcelFileDescriptor,
    ) {
        private val caller = Binder()
        private val connected = CompletableFuture<IBinder>()
        private val death = CompletableFuture<Unit>()
        private var binding = false
        private var service: IBinder? = null
        private var processGroup: Int? = null
        private var started = false
        private var cancelled = false
        private var failure: String? = null
        private var exit: JSONObject? = null

        private val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                try {
                    synchronized(this@Call) {
                        if (cancelled || !binding || death.isDone) {
                            stop(binder)
                            return
                        }
                        service = binder
                        binder.linkToDeath({ died() }, 0)
                        connected.complete(binder)
                    }
                } catch (error: Exception) {
                    connectionFailed(error.message ?: error.javaClass.simpleName)
                    if (!binder.isBinderAlive) died()
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                connectionFailed("The Python service connection was lost.")
            }

            override fun onBindingDied(name: ComponentName) {
                connectionFailed("The Python service binding ended.")
            }

            override fun onNullBinding(name: ComponentName) {
                connectionFailed("The Python service did not provide a connection.")
            }
        }

        fun ready(): JSONObject {
            synchronized(this) {
                if (cancelled) throw cancelledFailure()
                if (!binding && !connected.isDone) {
                    binding = true
                    try {
                        if (!application.bindService(
                                Intent(application, AgentPythonService::class.java).setAction(id),
                                connection,
                                Context.BIND_AUTO_CREATE,
                            )) {
                            connectionFailed("The Python service could not be bound.")
                        }
                    } catch (error: Exception) {
                        binding = false
                        connectionFailed(error.message ?: error.javaClass.simpleName)
                    }
                }
            }
            val remote = await(connected)
            synchronized(this) { if (cancelled) throw cancelledFailure() }
            val identity = transaction(remote, AgentPythonProtocol.HELLO, { parcel ->
                parcel.writeStrongBinder(caller)
                parcel.writeString(directory.absolutePath)
                parcel.writeFileDescriptor(cwd.fileDescriptor)
            }) { parcel ->
                val pid = parcel.readInt()
                val group = parcel.readInt()
                synchronized(this) { processGroup = group }
                JSONObject().put("pid", pid).put("processGroup", group)
            }
            synchronized(this) {
                if (cancelled) {
                    killGroup(processGroup!!)
                    throw cancelledFailure()
                }
            }
            transaction(remote, AgentPythonProtocol.READY) { Unit }
            synchronized(this) { if (cancelled) throw cancelledFailure() }
            return identity
        }

        fun start(): JSONObject = synchronized(this) {
            if (cancelled || death.isDone) return@synchronized JSONObject().put("started", false)
            if (started) throw PythonHostFailure("admissionFailed", "Python was already started for this call.")
            // Once GO is sent, a lost reply must not be reported as definitely unstarted.
            started = true
            transaction(service!!, AgentPythonProtocol.START) { Unit }
            JSONObject().put("started", true)
        }

        fun cancel() {
            synchronized<Unit>(this) {
                if (exit != null) return
                cancelled = true
                connected.completeExceptionally(cancelledFailure())
                val group = processGroup
                val remote = service
                when {
                    group != null -> killGroup(group)
                    remote != null && remote.isBinderAlive -> stop(remote)
                }
            }
            unbind()
        }

        fun waitForExit(): JSONObject {
            synchronized(this) { exit?.let { return it } }
            val shouldWait = synchronized(this) { service != null }
            if (shouldWait) await(death)
            val group = synchronized(this) { processGroup }
            if (group != null) {
                killGroup(group)
                while (groupExists(group)) Thread.sleep(20)
                synchronized(this) { processGroup = null }
            }
            val outputError = syncOutput()
            val serviceResult = File(directory, "service-result.json")
            val result = if (serviceResult.isFile) JSONObject(serviceResult.readText()) else null
            return synchronized(this) {
                val resultError = when {
                    result != null && !result.getBoolean("ok") -> result.getString("error")
                    started && !cancelled && result == null -> "The Python service exited before platform cleanup completed."
                    else -> null
                }
                JSONObject()
                    .put("started", started)
                    .put("cancelled", cancelled)
                    .put("groupGone", true)
                    .apply {
                        val errors = listOfNotNull(
                            resultError ?: failure?.takeIf { result == null && !cancelled },
                            outputError,
                        )
                        if (errors.isNotEmpty()) put("error", errors.joinToString("\n"))
                    }
                    .also { exit = it }
            }
        }

        fun close() {
            try {
                if (!death.isDone) cancel()
                waitForExit()
            } finally {
                try { unbind() } finally { releaseDirectory() }
            }
        }

        fun releaseDirectory() = cwd.close()

        private fun syncOutput(): String? {
            val errors = mutableListOf<String>()
            val didStart = synchronized(this) { started }
            for (name in listOf("stdout.txt", "stderr.txt")) {
                try {
                    val descriptor = Os.open(
                        File(directory, name).absolutePath,
                        OsConstants.O_WRONLY or OsConstants.O_CLOEXEC,
                        0,
                    )
                    try { Os.fsync(descriptor) } finally { Os.close(descriptor) }
                } catch (error: ErrnoException) {
                    if (didStart || error.errno != OsConstants.ENOENT) {
                        errors.add("$name: ${error.message}")
                    }
                }
            }
            return errors.takeIf { it.isNotEmpty() }?.joinToString("\n")
        }

        private fun died() {
            synchronized(this) {
                connected.completeExceptionally(
                    if (cancelled) cancelledFailure()
                    else PythonHostFailure("admissionFailed", "The Python service process exited."),
                )
                death.complete(Unit)
            }
            unbind()
        }

        private fun connectionFailed(reason: String) {
            synchronized(this) {
                if (!death.isDone) failure = reason
                connected.completeExceptionally(PythonHostFailure("admissionFailed", reason))
                val remote = service
                if (remote != null && !remote.isBinderAlive) death.complete(Unit)
            }
            // A dead binding must not let Android reconnect and repeat this execution.
            unbind()
        }

        private fun unbind() {
            val owned = synchronized(this) {
                if (!binding) false else { binding = false; true }
            }
            if (owned) application.unbindService(connection)
        }
    }
}

private fun cancelledFailure() = PythonHostFailure("cancelledBeforeStart", "Python execution was cancelled.")

private fun killGroup(group: Int) {
    try {
        Os.kill(-group, OsConstants.SIGKILL)
    } catch (error: ErrnoException) {
        if (error.errno != OsConstants.ESRCH) throw error
    }
}

private fun groupExists(group: Int): Boolean = try {
    Os.kill(-group, 0)
    true
} catch (error: ErrnoException) {
    if (error.errno != OsConstants.ESRCH) throw error
    false
}

private fun stop(remote: IBinder) {
    val parcel = Parcel.obtain()
    try {
        parcel.writeInterfaceToken(AgentPythonProtocol.DESCRIPTOR)
        remote.transact(AgentPythonProtocol.STOP, parcel, null, IBinder.FLAG_ONEWAY)
    } finally {
        parcel.recycle()
    }
}

private fun <T> transaction(
    remote: IBinder,
    operation: Int,
    write: (Parcel) -> Unit = {},
    read: (Parcel) -> T,
): T {
    val request = Parcel.obtain()
    val response = Parcel.obtain()
    try {
        request.writeInterfaceToken(AgentPythonProtocol.DESCRIPTOR)
        write(request)
        check(remote.transact(operation, request, response, 0)) { "The Python service rejected its host protocol." }
        response.readException()
        return read(response)
    } finally {
        request.recycle()
        response.recycle()
    }
}

private fun <T> await(future: CompletableFuture<T>): T = try {
    future.get()
} catch (error: ExecutionException) {
    throw error.cause ?: error
}

private fun reply(action: () -> JSONObject): String = try {
    JSONObject().put("ok", true).put("value", action()).toString()
} catch (error: Exception) {
    JSONObject().put("ok", false).put("error", JSONObject()
        .put("code", if (error is PythonHostFailure) error.code else "outcomeUnknown")
        .put("message", error.message ?: error.javaClass.simpleName)).toString()
}
