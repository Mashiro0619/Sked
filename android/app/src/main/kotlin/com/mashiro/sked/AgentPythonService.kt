package com.mashiro.sked

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.os.Parcel
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.Os
import android.system.OsConstants
import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import org.json.JSONObject
import java.io.File
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

/** One interpreter process serves one admitted execution and is then retired. */
class AgentPythonService : Service() {
    private var processGroup = 0
    private var preparationError: String? = null
    private var caller: IBinder? = null
    private var directory: File? = null
    private var cwd: ParcelFileDescriptor? = null
    private val bindings = mutableSetOf<String>()
    private var owner: String? = null
    private var started = false
    private val initialized = CompletableFuture<PyObject>()
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "sked-agent-python")
    }
    private fun endpoint(callId: String) = object : Binder() {
        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            if (code == INTERFACE_TRANSACTION) {
                reply!!.writeString(AgentPythonProtocol.DESCRIPTOR)
                return true
            }
            data.enforceInterface(AgentPythonProtocol.DESCRIPTOR)
            when (code) {
                AgentPythonProtocol.HELLO -> {
                    prepare(callId, data)
                    reply!!.writeNoException()
                    reply.writeInt(Process.myPid())
                    reply.writeInt(processGroup)
                }
                AgentPythonProtocol.READY -> {
                    bootstrap(callId)
                    reply!!.writeNoException()
                }
                AgentPythonProtocol.START -> {
                    start(callId)
                    reply!!.writeNoException()
                }
                AgentPythonProtocol.STOP -> stop(callId)
                else -> return super.onTransact(code, data, reply, flags)
            }
            return true
        }
    }

    override fun onCreate() {
        super.onCreate()
        val result = prepareProcess()
        if (result > 0) processGroup = result
        else preparationError = "The Python process group could not be created: ${Os.strerror(-result)}"
    }

    override fun onBind(intent: Intent): IBinder {
        val callId = intent.action!!
        synchronized(this) { bindings.add(callId) }
        return endpoint(callId)
    }

    override fun onUnbind(intent: Intent): Boolean {
        stop(intent.action!!)
        return false
    }

    override fun onDestroy() {
        super.onDestroy()
        terminateGroup()
    }

    private fun stop(callId: String) = synchronized<Unit>(this) {
        bindings.remove(callId)
        if (owner == callId) terminateGroup()
        // The framework destroys an idle service after its last binding ends.
    }

    private fun prepare(callId: String, data: Parcel) = synchronized(this) {
        check(callId in bindings) { "The Python call is no longer bound." }
        check(owner == null) { "This Python service has already received an execution." }
        owner = callId
        caller = data.readStrongBinder()!!
        directory = File(data.readString()!!)
        cwd = data.readFileDescriptor()!!
        try {
            caller!!.linkToDeath({ terminateGroup() }, 0)
            preparationError?.let { throw IllegalStateException(it) }
            worker.execute {
                try {
                    redirectOutput(directory!!)
                    Python.start(AndroidPlatform(this))
                    initialized.complete(Python.getInstance().getModule("android_bootstrap"))
                } catch (error: Throwable) {
                    fail(error)
                }
            }
        } catch (error: Exception) {
            fail(error)
        }
    }

    private fun bootstrap(callId: String): PyObject {
        synchronized(this) { check(owner == callId) { "This Python call does not own the interpreter." } }
        return try {
            initialized.get()
        } catch (error: ExecutionException) {
            throw IllegalStateException(error.cause?.message ?: error.message, error.cause)
        }
    }

    private fun start(callId: String) = synchronized(this) {
        check(owner == callId) { "This Python call does not own the interpreter." }
        check(!started) { "Python was already started for this execution." }
        started = true
        worker.execute {
            try {
                cwd!!.use { descriptor ->
                    bootstrap(callId).callAttr("run", directory!!.absolutePath, descriptor.fd)
                }
                cwd = null
                val result = waitForChildren()
                check(result == 0) { "Python child processes could not be collected: ${Os.strerror(result)}" }
                Os.fsync(FileDescriptor.out)
                Os.fsync(FileDescriptor.err)
                writeResult(JSONObject().put("ok", true))
                Process.killProcess(Process.myPid())
            } catch (error: Throwable) {
                fail(error)
            }
        }
    }

    private fun redirectOutput(root: File) {
        FileOutputStream(File(root, "stdout.txt")).use { Os.dup2(it.fd, 1) }
        FileOutputStream(File(root, "stderr.txt")).use { Os.dup2(it.fd, 2) }
    }

    private fun writeResult(result: JSONObject) {
        val root = directory!!
        val temporary = File(root, "service-result.json.tmp")
        FileOutputStream(temporary).use {
            it.write(result.toString().toByteArray(Charsets.UTF_8))
            it.fd.sync()
        }
        Os.rename(temporary.absolutePath, File(root, "service-result.json").absolutePath)
        val rootFd = Os.open(root.absolutePath, OsConstants.O_RDONLY or OsConstants.O_DIRECTORY, 0)
        try { Os.fsync(rootFd) } finally { Os.close(rootFd) }
    }

    private fun fail(error: Throwable) {
        try {
            writeResult(JSONObject().put("ok", false).put("error", error.message ?: error.javaClass.simpleName))
        } finally {
            initialized.completeExceptionally(error)
            terminateGroup()
        }
    }

    private fun terminateGroup() {
        if (processGroup > 0) Os.kill(-processGroup, OsConstants.SIGKILL)
        else Process.killProcess(Process.myPid())
    }

    private external fun prepareProcess(): Int
    private external fun waitForChildren(): Int
}
