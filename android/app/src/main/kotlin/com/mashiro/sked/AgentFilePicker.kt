package com.mashiro.sked

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/** Per-engine platform UI owner; the ContentResolver service belongs to Application. */
internal class AgentFilePicker(
    activity: ComponentActivity,
    private val access: AgentFileAccess,
) {
    private enum class Kind { ACCESS, DOCUMENT, DIRECTORY }

    private class Selection(
        val ownerId: String,
        val kind: Kind,
        val epoch: Long,
        var result: MethodChannel.Result?,
    ) {
        val cancellation = CancellationSignal()
        val retired = AtomicBoolean(false)
        val completion = CompletableFuture<Unit>()
        var processing = false
    }

    private class Work(
        var result: MethodChannel.Result?,
        val cancelOnDetach: Boolean,
    ) {
        val cancellation = CancellationSignal()
        val completion = CompletableFuture<Unit>()
    }

    private var activity: ComponentActivity? = activity
    private val handler = Handler(Looper.getMainLooper())
    private val pending = PendingActivityRequest<Selection>()
    private val selections = mutableSetOf<Selection>()
    private val work = mutableSetOf<Work>()
    private var currentSelection: Selection? = null
    private var disposed = false
    private var clearing = false
    private var closeCompletion: CompletableFuture<Unit>? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            respondError(result, AgentFileFailure("unavailable", "The Android file access owner is closed."))
            return
        }
        try {
            when (call.method) {
                "status" -> runWork(result) { access.status(it) }
                "requestAccess" -> startRequest(call, result, Kind.ACCESS)
                "pickDocument" -> startRequest(call, result, Kind.DOCUMENT)
                "pickDirectory" -> startRequest(call, result, Kind.DIRECTORY)
                "cancelPending" -> {
                    val completions = retireSelections(call.requiredString("ownerId"), completeCall = true) +
                        access.pendingPickerCleanups()
                    runWork(result, cancelOnDetach = false, waitFor = completions) { null }
                }
                "releaseGrant" -> {
                    val id = call.requiredString("grantId")
                    runWork(result, cancelOnDetach = false) {
                        access.releaseGrant(id)
                        access.status(it)
                    }
                }
                "clearGrants" -> {
                    // Invalidate before scheduling I/O: an older picker worker
                    // cannot register a new grant behind this clear operation.
                    if (clearing) throw AgentFileFailure("busy", "The URI grants are already being cleared.")
                    clearing = true
                    access.invalidateSelections()
                    val completions = retireSelections(completeCall = true) + access.pendingPickerCleanups()
                    cancelReaders(completeCalls = true)
                    val clearedBefore = AtomicLong(-1)
                    runWork(
                        result,
                        cancelOnDetach = false,
                        waitFor = completions,
                        recoverWaitFailure = true,
                        onComplete = {
                            clearing = false
                            selections.removeAll { it.completion.isDone && it.epoch < clearedBefore.get() }
                        },
                    ) {
                        clearedBefore.set(access.clearGrants())
                        access.status(it)
                    }
                }
                else -> deliver(result) { it.notImplemented() }
            }
        } catch (error: Exception) {
            respondError(result, error)
        }
    }

    private fun startRequest(call: MethodCall, result: MethodChannel.Result, kind: Kind) {
        val owner = call.requiredString("ownerId")
        if (clearing) throw AgentFileFailure("busy", "The URI grants are being cleared.")
        val current = activity
        if (current == null || current.isFinishing || current.isDestroyed) {
            throw AgentFileFailure("cancelled", "The Android file access owner is closing.")
        }
        val selection = Selection(owner, kind, access.selectionEpoch(), result)
        val request = pending.begin(selection)
            ?: throw AgentFileFailure("busy", "Another Android file access request is open.")
        currentSelection = selection
        selections.add(selection)
        try {
            if (kind == Kind.ACCESS) {
                requestAccess(request, current)
                return
            }
            val intent = if (kind == Kind.DIRECTORY) {
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                }
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    val mimeTypes = call.argument<List<String>>("mimeTypes").orEmpty()
                    type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
                    if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                }
            }
            intent.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
            val launcher = current.activityResultRegistry.register(
                request.key,
                ActivityResultContracts.StartActivityForResult(),
            ) { returned ->
                val uri = returned.data?.data
                finishSelection(
                    request,
                    cancelled = returned.resultCode != Activity.RESULT_OK || uri == null,
                    uri = if (returned.resultCode == Activity.RESULT_OK) uri else null,
                    flags = returned.data?.flags ?: 0,
                )
            }
            pending.releaseWhenComplete(request) { handler.post { launcher.unregister() } }
            launcher.launch(intent)
        } catch (error: Exception) {
            finishError(request, error)
        }
    }

    private fun requestAccess(request: PendingActivityRequest.Request, current: ComponentActivity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                finishSelection(request, cancelled = false)
                return
            }
            val launcher = current.activityResultRegistry.register(
                request.key,
                ActivityResultContracts.StartActivityForResult(),
            ) {
                // Settings resultCode does not establish the permission state.
                finishSelection(request, cancelled = false)
            }
            pending.releaseWhenComplete(request) { handler.post { launcher.unregister() } }
            try {
                launcher.launch(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:${current.packageName}"),
                    ),
                )
            } catch (_: ActivityNotFoundException) {
                launcher.launch(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val launcher = current.activityResultRegistry.register(
                request.key,
                ActivityResultContracts.RequestMultiplePermissions(),
            ) { finishSelection(request, cancelled = false) }
            pending.releaseWhenComplete(request) { handler.post { launcher.unregister() } }
            launcher.launch(
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
            )
        } else {
            finishSelection(request, cancelled = false)
        }
    }

    private fun finishSelection(
        request: PendingActivityRequest.Request,
        cancelled: Boolean,
        uri: Uri? = null,
        flags: Int = 0,
    ) {
        val selection = pending.peek(request) ?: return
        if (selection.processing) return
        if (disposed || activity == null) {
            retireSelections(completeCall = false)
            return
        }
        selection.processing = true
        try {
            access.execute { processSelection(request, selection, cancelled, uri, flags) }
        } catch (error: Exception) {
            try {
                finishError(request, error)
            } finally {
                completeSelectionWork(selection)
            }
        }
    }

    private fun processSelection(
        request: PendingActivityRequest.Request,
        selection: Selection,
        cancelled: Boolean,
        uri: Uri?,
        flags: Int,
    ) {
        var registration: AgentFileGrantStore.Registration? = null
        try {
            selection.cancellation.throwIfCanceled()
            if (!cancelled && uri != null) {
                registration = access.rememberSelection(
                    uri = uri,
                    flags = flags,
                    directory = selection.kind == Kind.DIRECTORY,
                    epoch = selection.epoch,
                    cancellation = selection.cancellation,
                )
            }
            selection.cancellation.throwIfCanceled()
            val status = access.status(selection.cancellation)
            val id = registration?.record?.id
            val resource = (status["resources"] as? List<*>)
                ?.filterIsInstance<Map<*, *>>()?.firstOrNull { it["grantId"] == id }
            val response = linkedMapOf(
                "cancelled" to cancelled,
                "status" to status,
                "resource" to resource,
            )
            val completedRegistration = registration
            handler.post {
                if (disposed || selection.retired.get() || pending.peek(request) !== selection) {
                    if (completedRegistration == null) {
                        completeSelectionWork(selection)
                    } else {
                        rollbackRetired(selection, completedRegistration)
                    }
                } else {
                    pending.complete(request)
                    if (currentSelection === selection) currentSelection = null
                    val result = selection.result
                    selection.result = null
                    try {
                        deliver(result) { it.success(response) }
                    } finally {
                        completeSelectionWork(selection)
                    }
                }
            }
        } catch (error: Exception) {
            var failure = error
            var cleanupFailure: Exception? =
                error.takeIf { it is AgentFileFailure && it.cleanupIncomplete }
            registration?.let {
                try {
                    access.rollbackSelection(it)
                } catch (cleanup: Exception) {
                    failure = AgentFileFailure(
                        "storageFailure",
                        "The document selection failed and its new URI grant could not be released.",
                        cause = cleanup,
                        cleanupIncomplete = true,
                    )
                    cleanupFailure = failure
                }
            }
            handler.post {
                try {
                    finishError(request, failure)
                } finally {
                    completeSelectionWork(selection, cleanupFailure)
                }
            }
        }
    }

    private fun rollbackRetired(
        selection: Selection,
        registration: AgentFileGrantStore.Registration,
    ) {
        try {
            access.execute {
                val failure = try {
                    access.rollbackSelection(registration)
                    null
                } catch (error: Exception) {
                    AgentFileFailure(
                        "storageFailure",
                        "The retired document selection's URI grant could not be released.",
                        cause = error,
                        cleanupIncomplete = true,
                    )
                }
                handler.post { completeSelectionWork(selection, failure) }
            }
        } catch (error: Exception) {
            completeSelectionWork(
                selection,
                AgentFileFailure(
                    "storageFailure",
                    "The retired document selection's URI grant cleanup could not start.",
                    cause = error,
                    cleanupIncomplete = true,
                ),
            )
        }
    }

    private fun finishError(request: PendingActivityRequest.Request, error: Exception) {
        val selection = pending.complete(request) ?: return
        if (currentSelection === selection) currentSelection = null
        selection.retired.set(true)
        val result = selection.result
        selection.result = null
        try {
            result?.let { respondError(it, error) }
        } finally {
            if (!selection.processing) completeSelectionWork(selection)
        }
    }

    private fun retireSelections(
        ownerId: String? = null,
        completeCall: Boolean,
    ): List<CompletableFuture<Unit>> {
        // Only this engine's opaque request can be retired. A late registry
        // callback never sees the next request's MethodChannel.Result.
        val targets = selections.filter { ownerId == null || it.ownerId == ownerId }
        for (selection in targets) {
            if (currentSelection === selection) {
                pending.cancel()
                currentSelection = null
            }
            selection.retired.set(true)
            selection.cancellation.cancel()
            val result = selection.result
            selection.result = null
            if (completeCall) {
                deliver(result) { it.error("cancelled", "The Android file access request was cancelled.", null) }
            }
            if (!selection.processing) completeSelectionWork(selection)
        }
        return targets.map { it.completion }
    }

    private fun completeSelectionWork(selection: Selection, failure: Exception? = null) {
        if (selection.completion.isDone) return
        if (failure == null) {
            selections.remove(selection)
            selection.completion.complete(Unit)
        } else {
            selection.completion.completeExceptionally(failure)
        }
    }

    private fun runWork(
        result: MethodChannel.Result,
        cancelOnDetach: Boolean = true,
        waitFor: List<CompletableFuture<Unit>> = emptyList(),
        recoverWaitFailure: Boolean = false,
        onComplete: (() -> Unit)? = null,
        operation: (CancellationSignal) -> Any?,
    ) {
        val task = Work(result, cancelOnDetach)
        work.add(task)
        CompletableFuture.allOf(*waitFor.toTypedArray()).whenComplete { _, waitingError ->
            try {
                access.execute {
                    val outcome: Result<Any?> = try {
                        if (waitingError != null && !recoverWaitFailure) throw cleanupException(waitingError)
                        Result.success(operation(task.cancellation))
                    } catch (error: Exception) {
                        Result.failure(error)
                    }
                    handler.post { finishWork(task, outcome, onComplete) }
                }
            } catch (error: Exception) {
                handler.post { finishWork(task, Result.failure(error), onComplete) }
            }
        }
    }

    private fun finishWork(task: Work, outcome: Result<Any?>, onComplete: (() -> Unit)?) {
        work.remove(task)
        val callback = task.result
        task.result = null
        try {
            onComplete?.invoke()
            if (callback != null && (!disposed || !task.cancelOnDetach)) {
                outcome.fold(
                    { value -> deliver(callback) { it.success(value) } },
                    { error -> respondError(callback, cleanupException(error)) },
                )
            }
        } finally {
            task.completion.complete(Unit)
        }
    }

    private fun cancelReaders(completeCalls: Boolean) {
        for (task in work.toList()) {
            if (!task.cancelOnDetach) continue
            task.cancellation.cancel()
            val result = task.result
            task.result = null
            if (completeCalls) {
                deliver(result) { it.error("cancelled", "The Android file access request was cancelled.", null) }
            }
        }
    }

    fun close(completeCalls: Boolean): CompletableFuture<Unit> {
        disposed = true
        activity = null
        val completions = retireSelections(completeCall = completeCalls)
        cancelReaders(completeCalls)
        if (!completeCalls) {
            for (task in work) task.result = null
        }
        closeCompletion?.let { return it }
        val closing = CompletableFuture.allOf(
            *(completions + work.map { it.completion }).toTypedArray(),
        ).thenApply { Unit }
        closeCompletion = closing
        access.retainPickerCleanup(selections.maxOfOrNull { it.epoch } ?: -1, closing)
        return closing
    }

    private fun respondError(result: MethodChannel.Result, error: Exception) {
        val value = AgentFileAccess.errorJson(error)
        deliver(result) { it.error(value.getString("code"), value.getString("message"), value.toPlatformMap()) }
    }

    private fun deliver(result: MethodChannel.Result?, response: (MethodChannel.Result) -> Unit) {
        if (result == null) return
        try {
            response(result)
        } catch (_: Exception) {
            Log.w("SkedAgentFiles", "The file access result could not be delivered to its owner.")
        }
    }

    private fun cleanupException(failure: Throwable): Exception {
        var cause = failure
        while (cause is CompletionException && cause.cause != null) cause = cause.cause!!
        return cause as? Exception ?: AgentFileFailure("storageFailure", "The file access cleanup failed.")
    }

    companion object {
        const val CHANNEL = "com.mashiro.sked/agent_file_access"
    }
}

private fun MethodCall.requiredString(name: String): String = argument<String>(name)
    ?.takeIf { it.isNotEmpty() }
    ?: throw AgentFileFailure("invalidArgument", "The $name field must not be empty.")
