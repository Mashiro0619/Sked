package com.mashiro.sked

import android.app.Activity
import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import com.mashiro.sked.androidproductivity.BatteryOptimizationStatus
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

private data class AppInstanceLeaseOwner(
    val engineId: Long,
    val ownerId: String,
)

private object AppInstanceLeaseGuard {
    private val nextEngineId = AtomicLong()
    private var owner: AppInstanceLeaseOwner? = null

    fun createEngineId(): Long = nextEngineId.incrementAndGet()

    @Synchronized
    fun tryAcquire(engineId: Long, ownerId: String): Boolean {
        val candidate = AppInstanceLeaseOwner(engineId, ownerId)
        val current = owner
        if (current != null && current != candidate) return false
        owner = candidate
        return true
    }

    @Synchronized
    fun release(engineId: Long, ownerId: String) {
        if (owner == AppInstanceLeaseOwner(engineId, ownerId)) {
            owner = null
        }
    }

    @Synchronized
    fun releaseEngine(engineId: Long) {
        if (owner?.engineId == engineId) {
            owner = null
        }
    }
}

private class SaveFileRequest(
    val fileName: String,
    val content: String? = null,
    val binary: BinaryExportStaging.Prepared? = null,
    var result: MethodChannel.Result?,
) {
    val cancelled = AtomicBoolean(false)
    var copyStarted = false
}

private sealed interface SaveFileOutcome {
    data object Saved : SaveFileOutcome
    data object Cancelled : SaveFileOutcome
    data class Failure(val code: String, val message: String) : SaveFileOutcome
}

class MainActivity : FlutterFragmentActivity() {
    private val appInstanceLeaseEngineId = AppInstanceLeaseGuard.createEngineId()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingAgendaIntents = ArrayDeque<String>()
    private var initialAgendaIntentConsumed = false
    private var exportFileChannel: MethodChannel? = null
    private var appInstanceLeaseChannel: MethodChannel? = null
    private var productivityChannel: MethodChannel? = null
    private val pendingSave = PendingActivityRequest<SaveFileRequest>()
    private val binaryExportStaging by lazy { BinaryExportStaging(cacheDir) }
    private var binaryCopyInFlight: SaveFileRequest? = null
    private var activityDestroying = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAgendaIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAgendaIntent(intent)
    }

    override fun onDestroy() {
        activityDestroying = true
        // Picker cancellation can complete now. An accepted stream copy must
        // first close on its worker; teardown never reports it saved early.
        cancelFileExports(completeCall = true)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A Flutter engine can be torn down and recreated while the Activity
        // remains alive (for example after a renderer restart). The initial
        // intent must be consumed once for each engine, while the bounded
        // queue itself is retained so intents received during the gap survive.
        synchronized(pendingAgendaIntents) {
            initialAgendaIntentConsumed = false
        }
        exportFileChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXPORT_FILE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveTextFile" -> saveTextFile(
                        fileName = call.argument<String>("fileName"),
                        content = call.argument<String>("content"),
                        mimeType = call.argument<String>("mimeType"),
                        result = result,
                    )
                    "prepareBinaryFile" -> prepareBinaryFile(
                        fileName = call.argument<String>("fileName"),
                        mimeType = call.argument<String>("mimeType"),
                        byteLength = when (val length = call.argument<Any>("byteLength")) {
                            is Int -> length.toLong()
                            is Long -> length
                            else -> null
                        },
                        result = result,
                    )
                    "savePreparedBinaryFile" -> savePreparedBinaryFile(
                        id = call.argument<String>("id"),
                        result = result,
                    )
                    "discardBinaryFile" -> discardBinaryFile(
                        id = call.argument<String>("id"),
                        result = result,
                    )
                    else -> result.notImplemented()
                }
            }
        }
        appInstanceLeaseChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_INSTANCE_LEASE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val ownerId = call.argument<String>("ownerId")
                if (ownerId.isNullOrBlank()) {
                    result.error("invalidArguments", "Missing lease owner ID.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "tryAcquire" -> result.success(
                        AppInstanceLeaseGuard.tryAcquire(
                            appInstanceLeaseEngineId,
                            ownerId,
                        ),
                    )
                    "release" -> {
                        AppInstanceLeaseGuard.release(appInstanceLeaseEngineId, ownerId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        productivityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AndroidProductivityContract.CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialAgendaIntent" -> {
                        val pending = synchronized(pendingAgendaIntents) {
                            val value = pendingAgendaIntents.pollFirst()
                            initialAgendaIntentConsumed = true
                            value
                        }
                        result.success(pending)
                        // Android can deliver several launcher/notification
                        // intents before Dart installs its stream listener.
                        // Return one through the legacy method result and drain
                        // the remaining bounded queue through the event channel
                        // after the result has reached Flutter.
                        mainHandler.post { drainPendingAgendaIntents() }
                    }
                    "isNotificationPermissionGranted" ->
                        result.success(isNotificationPermissionGranted())
                    "canScheduleExactAlarms" ->
                        result.success(canScheduleExactAlarms())
                    AndroidProductivityContract.METHOD_IS_IGNORING_BATTERY_OPTIMIZATIONS ->
                        result.success(isIgnoringBatteryOptimizations())
                    AndroidProductivityContract.METHOD_OPEN_BATTERY_OPTIMIZATION_SETTINGS ->
                        openBatteryOptimizationSettings(result)
                    AndroidProductivityContract.METHOD_GET_AUTOSTART_SUPPORT ->
                        result.success(AndroidAutostartSettings.support(this))
                    AndroidProductivityContract.METHOD_OPEN_AUTOSTART_SETTINGS ->
                        result.success(AndroidAutostartSettings.open(this))
                    AndroidProductivityContract.METHOD_GET_NOTIFICATION_DIAGNOSTICS ->
                        result.success(notificationDiagnostics())
                    "scheduleAgendaReconciliation" -> {
                        AgendaBackgroundReconcileScheduler.schedule(
                            this,
                            call.epochMillisArgument(),
                        )
                        result.success(null)
                    }
                    "cancelAgendaReconciliation" -> {
                        AgendaBackgroundReconcileScheduler.cancel(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Platform surfaces can outlive their initiating engine. Invalidate
        // the request tokens as well as dropping their results/content so a
        // late callback cannot consume a new engine's pending request.
        cancelFileExports(completeCall = false)
        exportFileChannel?.setMethodCallHandler(null)
        exportFileChannel = null
        appInstanceLeaseChannel?.setMethodCallHandler(null)
        appInstanceLeaseChannel = null
        productivityChannel?.setMethodCallHandler(null)
        productivityChannel = null
        synchronized(pendingAgendaIntents) {
            initialAgendaIntentConsumed = false
        }
        AppInstanceLeaseGuard.releaseEngine(appInstanceLeaseEngineId)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleAgendaIntent(intent: Intent?) {
        if (intent?.action != AndroidProductivityContract.ACTION_OPEN_AGENDA) return
        val target = intent.getStringExtra(AndroidProductivityContract.EXTRA_AGENDA_TARGET)
            ?.takeIf { it.isNotBlank() && it.toByteArray(Charsets.UTF_8).size <= 16 * 1024 }
            ?: return
        synchronized(pendingAgendaIntents) {
            if (!pendingAgendaIntents.contains(target)) {
                while (pendingAgendaIntents.size >= MAX_PENDING_AGENDA_INTENTS) {
                    pendingAgendaIntents.removeFirst()
                }
                pendingAgendaIntents.addLast(target)
            }
        }
        drainPendingAgendaIntents()
    }

    private fun drainPendingAgendaIntents() {
        val channel = productivityChannel ?: return
        // Keep the queue until getInitialAgendaIntent() has installed the Dart
        // listener. That call consumes the first item and then drains all
        // remaining, already de-duplicated targets through the event channel.
        if (!synchronized(pendingAgendaIntents) { initialAgendaIntentConsumed }) {
            return
        }
        val pending = synchronized(pendingAgendaIntents) {
            buildList {
                while (pendingAgendaIntents.isNotEmpty()) {
                    add(pendingAgendaIntents.removeFirst())
                }
            }
        }
        for (target in pending) {
            channel.invokeMethod("agendaIntent", target)
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return try {
            getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean =
        BatteryOptimizationStatus.isIgnoringOptimizations(this)

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            isIgnoringBatteryOptimizations()
        ) {
            result.success(true)
            return
        }
        try {
            // Open Sked's app-details surface so the user can choose the
            // vendor's actual battery policy manually. There is no public,
            // cross-OEM intent for the nested battery page.
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
            // Opening Android settings is not a grant. Return immediately; the
            // caller queries PowerManager again after the app resumes.
            result.success(false)
        } catch (_: ActivityNotFoundException) {
            if (!openBatteryOptimizationSettingsFallback()) {
                result.success(false)
                return
            }
            result.success(false)
        } catch (_: SecurityException) {
            if (!openBatteryOptimizationSettingsFallback()) {
                result.success(false)
                return
            }
            result.success(false)
        }
    }

    private fun openBatteryOptimizationSettingsFallback(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Reports the Android-owned part of notification delivery. Scheduling and
     * test notifications remain in the existing Flutter agenda service; this
     * method deliberately never creates a channel or posts a notification.
     */
    private fun notificationDiagnostics(): Map<String, Any?> {
        val manager = getSystemService(NotificationManager::class.java)
        val channels: List<Map<String, Any?>> = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null
        ) {
            manager.notificationChannels
                .asSequence()
                .filter { channel -> channel.id.startsWith("sked_") }
                .sortedBy { channel -> channel.id }
                .map { channel ->
                    mapOf(
                        "id" to channel.id,
                        "name" to channel.name.toString(),
                        "exists" to true,
                        "enabled" to (channel.importance != NotificationManager.IMPORTANCE_NONE),
                        "importance" to channel.importance,
                    )
                }
                .toList()
        } else {
            emptyList()
        }
        val activeNotifications = if (manager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.activeNotifications.map { status ->
                mapOf(
                    "id" to status.id,
                    "tag" to status.tag,
                    "postTimeMillis" to status.postTime,
                )
            }
        } else {
            emptyList()
        }
        return mapOf(
            "supported" to true,
            "appNotificationsEnabled" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "postNotificationsGranted" to isNotificationPermissionGranted(),
            "exactAlarmsAllowed" to canScheduleExactAlarms(),
            "batteryOptimizationIgnored" to isIgnoringBatteryOptimizations(),
            "channels" to channels,
            "activeNotifications" to activeNotifications,
        )
    }

    private fun saveTextFile(
        fileName: String?,
        content: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (activityDestroying || isFinishing || isDestroyed) {
            result.success(null)
            return
        }
        if (pendingSave.isPending || binaryExportStaging.isPending || binaryExportCopyActive.get()) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        if (fileName.isNullOrBlank() || content == null) {
            result.error("invalidArguments", "Missing fileName or content.", null)
            return
        }

        val request = pendingSave.begin(
            SaveFileRequest(fileName = fileName, content = content, result = result),
        )!!
        launchSaveFile(request, fileName, mimeType?.takeIf { it.isNotBlank() } ?: "text/plain")
    }

    private fun prepareBinaryFile(
        fileName: String?,
        mimeType: String?,
        byteLength: Long?,
        result: MethodChannel.Result,
    ) {
        if (activityDestroying || isFinishing || isDestroyed) {
            result.success(null)
            return
        }
        if (pendingSave.isPending || binaryExportStaging.isPending || binaryExportCopyActive.get()) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        if (fileName.isNullOrBlank() || byteLength == null || byteLength < 0) {
            result.error("invalidArguments", "Missing fileName or byteLength.", null)
            return
        }
        try {
            val prepared = binaryExportStaging.prepare(
                fileName,
                mimeType?.takeIf { it.isNotBlank() } ?: "application/octet-stream",
                byteLength,
            )!!
            result.success(mapOf("id" to prepared.id, "path" to prepared.path))
        } catch (_: SecurityException) {
            result.error("permissionDenied", "Permission denied while preparing the export.", null)
        } catch (_: IOException) {
            result.error("failed", "Unable to prepare the export.", null)
        }
    }

    private fun savePreparedBinaryFile(id: String?, result: MethodChannel.Result) {
        if (activityDestroying || isFinishing || isDestroyed) {
            result.success(null)
            return
        }
        if (pendingSave.isPending || binaryExportCopyActive.get()) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        // Only an opaque token allocated by prepareBinaryFile is accepted.
        // No method on this channel accepts a source path to read.
        val prepared = binaryExportStaging.find(id)
        if (prepared == null) {
            result.error("invalidArguments", "The prepared export is no longer available.", null)
            return
        }
        val request = pendingSave.begin(
            SaveFileRequest(fileName = prepared.fileName, binary = prepared, result = result),
        )!!
        try {
            prepared.verify()
        } catch (_: SecurityException) {
            finishSaveFile(
                request,
                SaveFileOutcome.Failure("permissionDenied", "Unable to read the export."),
            )
            return
        } catch (_: IOException) {
            finishSaveFile(
                request,
                SaveFileOutcome.Failure("failed", "The prepared export is incomplete."),
            )
            return
        }
        launchSaveFile(request, prepared.fileName, prepared.mimeType)
    }

    private fun discardBinaryFile(id: String?, result: MethodChannel.Result) {
        if (binaryExportStaging.find(id) != null &&
            (pendingSave.isPending || binaryCopyInFlight != null)
        ) {
            result.error("busy", "The prepared export is still in use.", null)
            return
        }
        try {
            // Idempotent for a completed/retired token; an old Dart finally
            // block must not discard another engine's new preparation.
            binaryExportStaging.discard(id)
            result.success(null)
        } catch (_: Exception) {
            result.error("failed", "Unable to remove the prepared export.", null)
        }
    }

    private fun launchSaveFile(
        request: PendingActivityRequest.Request,
        fileName: String,
        mimeType: String,
    ) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            // Register per call rather than reusing a launcher: an old picker
            // may still return after engine cleanup and a new Flutter call.
            // Direct registration also permits an engine attached after STARTED.
            val launcher = activityResultRegistry.register(
                request.key,
                ActivityResultContracts.StartActivityForResult(),
            ) { activityResult -> completeSaveFile(request, activityResult) }
            pendingSave.releaseWhenComplete(request) {
                mainHandler.post { launcher.unregister() }
            }
            launcher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            finishSaveFile(
                request,
                SaveFileOutcome.Failure("unsupported", "No document provider is available."),
            )
        } catch (_: SecurityException) {
            finishSaveFile(
                request,
                SaveFileOutcome.Failure(
                    "permissionDenied", "Permission denied while opening document provider.",
                ),
            )
        } catch (_: RuntimeException) {
            finishSaveFile(
                request,
                SaveFileOutcome.Failure("failed", "Unable to open document provider."),
            )
        }
    }

    private fun completeSaveFile(
        request: PendingActivityRequest.Request,
        activityResult: ActivityResult,
    ) {
        val pending = pendingSave.peek(request) ?: return
        if (pending.copyStarted) return

        val uri = activityResult.data?.data
        if (activityDestroying || isFinishing || isDestroyed ||
            activityResult.resultCode != Activity.RESULT_OK || uri == null
        ) {
            finishSaveFile(request, SaveFileOutcome.Cancelled)
            return
        }

        val binary = pending.binary
        if (binary != null) {
            // A recreated Activity must also wait for an older owner's worker
            // to close, even though it owns a different request registry.
            if (!binaryExportCopyActive.compareAndSet(false, true)) {
                finishSaveFile(
                    request,
                    SaveFileOutcome.Failure("busy", "Another file export is still finishing."),
                )
                return
            }
            pending.copyStarted = true
            binaryCopyInFlight = pending
            val resolver = applicationContext.contentResolver
            try {
                Thread({
                    val outcome = try {
                        val copied = copyExportStream(
                            byteLength = binary.byteLength,
                            openInput = binary::openInput,
                            openOutput = { resolver.openOutputStream(uri) },
                            isCancelled = pending.cancelled::get,
                        )
                        if (copied) SaveFileOutcome.Saved else SaveFileOutcome.Cancelled
                    } catch (_: SecurityException) {
                        SaveFileOutcome.Failure(
                            "permissionDenied", "Permission denied while saving file.",
                        )
                    } catch (_: IOException) {
                        SaveFileOutcome.Failure("failed", "Failed to save file.")
                    } catch (_: RuntimeException) {
                        SaveFileOutcome.Failure("failed", "Document provider failed while saving file.")
                    }
                    mainHandler.post {
                        try {
                            if (binaryCopyInFlight === pending) binaryCopyInFlight = null
                            if (pendingSave.peek(request) === pending) {
                                finishSaveFile(request, outcome)
                            } else {
                                // The old Flutter owner has detached. Close/copy
                                // completion still owns cleanup, never a new call.
                                try {
                                    binaryExportStaging.discard(binary.id)
                                } catch (_: Exception) {
                                    Log.w("SkedExport", "Unable to remove a retired export preparation.")
                                }
                            }
                        } finally {
                            binaryExportCopyActive.set(false)
                        }
                    }
                }, "sked-file-export").start()
            } catch (_: RuntimeException) {
                binaryCopyInFlight = null
                binaryExportCopyActive.set(false)
                finishSaveFile(
                    request,
                    SaveFileOutcome.Failure("failed", "Unable to start file export."),
                )
            }
            return
        }

        val outcome = try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(pending.content!!.toByteArray(Charsets.UTF_8))
                output.flush()
                SaveFileOutcome.Saved
            } ?: SaveFileOutcome.Failure("failed", "Unable to open output stream.")
        } catch (_: SecurityException) {
            SaveFileOutcome.Failure("permissionDenied", "Permission denied while saving file.")
        } catch (_: IOException) {
            SaveFileOutcome.Failure("failed", "Failed to save file.")
        } catch (_: RuntimeException) {
            SaveFileOutcome.Failure("failed", "Document provider failed while saving file.")
        }
        finishSaveFile(request, outcome)
    }

    private fun finishSaveFile(
        request: PendingActivityRequest.Request,
        outcome: SaveFileOutcome,
    ) {
        val pending = pendingSave.peek(request) ?: return
        val completedOutcome = try {
            pending.binary?.let { binaryExportStaging.discard(it.id) }
            outcome
        } catch (_: Exception) {
            SaveFileOutcome.Failure("failed", "Unable to remove the prepared export.")
        }
        pendingSave.complete(request)
        val result = pending.result ?: return
        pending.result = null
        when (completedOutcome) {
            SaveFileOutcome.Saved -> result.success(pending.fileName)
            SaveFileOutcome.Cancelled -> result.success(null)
            is SaveFileOutcome.Failure ->
                result.error(completedOutcome.code, completedOutcome.message, null)
        }
    }

    private fun cancelFileExports(completeCall: Boolean) {
        val pending = pendingSave.cancel()
        pending?.cancelled?.set(true)
        val result = pending?.result
        pending?.result = null
        if (binaryCopyInFlight != null) {
            // Keep the busy slot until the worker actually closes its streams.
            // There is no truthful completed result to send before that point.
            return
        }
        try {
            binaryExportStaging.discardCurrent()
            if (completeCall) result?.success(null)
        } catch (_: Exception) {
            if (completeCall) {
                result?.error("failed", "Unable to remove the prepared export.", null)
            }
            Log.w("SkedExport", "Unable to remove an interrupted export preparation.")
        }
    }

    private companion object {
        const val EXPORT_FILE_CHANNEL = "com.mashiro.sked/export_file"
        const val APP_INSTANCE_LEASE_CHANNEL = "com.mashiro.sked/app_instance_lease"
        const val MAX_PENDING_AGENDA_INTENTS = 16
        val binaryExportCopyActive = AtomicBoolean(false)
    }
}

private fun MethodCall.epochMillisArgument(): Long? {
    val value = argument<Any>("atEpochMillis")
    return when (value) {
        is Number -> value.toLong().takeIf { it > 0L }
        else -> null
    }
}
