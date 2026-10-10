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

private data class SaveTextFileRequest(
    val fileName: String,
    val content: String,
    val result: MethodChannel.Result,
)

class MainActivity : FlutterFragmentActivity() {
    private val appInstanceLeaseEngineId = AppInstanceLeaseGuard.createEngineId()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingAgendaIntents = ArrayDeque<String>()
    private var initialAgendaIntentConsumed = false
    private var exportFileChannel: MethodChannel? = null
    private var appInstanceLeaseChannel: MethodChannel? = null
    private var productivityChannel: MethodChannel? = null
    private val pendingNotificationPermission = PendingActivityRequest<MethodChannel.Result>()
    private var pendingExactAlarmPermissionResult: MethodChannel.Result? = null
    private var exactAlarmPermissionRequestLeftActivity = false
    private val pendingSave = PendingActivityRequest<SaveTextFileRequest>()
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

    override fun onResume() {
        super.onResume()
        // ACTION_REQUEST_SCHEDULE_EXACT_ALARM returns through the activity
        // lifecycle rather than a result intent. Resolve the Flutter call only
        // after the user has left Settings so the caller observes the actual
        // permission state and can reconcile existing alarms immediately.
        resolveExactAlarmPermissionRequest()
    }

    override fun onPause() {
        if (pendingExactAlarmPermissionResult != null) {
            exactAlarmPermissionRequestLeftActivity = true
        }
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Some OEM request surfaces are dialogs rather than a full Activity.
        // They can take focus without consistently producing a pause/resume
        // pair, so use focus loss as the same evidence that the request UI was
        // actually shown. Do not resolve merely because the launch call returned.
        if (!hasFocus) {
            if (pendingExactAlarmPermissionResult != null) {
                exactAlarmPermissionRequestLeftActivity = true
            }
        } else {
            resolveExactAlarmPermissionRequest()
        }
    }

    override fun onDestroy() {
        activityDestroying = true
        // Complete live calls before Flutter detaches. Activity recreation
        // cannot carry a MethodChannel.Result or an export payload to the new
        // engine, even when Android restores a pending platform result.
        pendingNotificationPermission.cancel()?.success(false)
        pendingSave.cancel()?.result?.success(null)
        pendingExactAlarmPermissionResult?.let { result ->
            pendingExactAlarmPermissionResult = null
            exactAlarmPermissionRequestLeftActivity = false
            result.success(false)
        }
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
                    "requestNotificationPermission" ->
                        requestNotificationPermission(result)
                    "isNotificationPermissionGranted" ->
                        result.success(isNotificationPermissionGranted())
                    "canScheduleExactAlarms" ->
                        result.success(canScheduleExactAlarms())
                    "requestExactAlarmPermission" ->
                        requestExactAlarmPermission(result)
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
        pendingNotificationPermission.cancel()
        pendingSave.cancel()
        pendingExactAlarmPermissionResult = null
        exactAlarmPermissionRequestLeftActivity = false
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

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (activityDestroying || isFinishing || isDestroyed) {
            result.success(false)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            isNotificationPermissionGranted()) {
            result.success(true)
            return
        }
        val request = pendingNotificationPermission.begin(result)
        if (request == null) {
            result.error("busy", "A notification permission request is already in progress.", null)
            return
        }
        try {
            val launcher = activityResultRegistry.register(
                request.key,
                ActivityResultContracts.RequestPermission(),
            ) { granted ->
                pendingNotificationPermission.complete(request)?.success(
                    !activityDestroying && !isFinishing && !isDestroyed &&
                        granted && isNotificationPermissionGranted(),
                )
            }
            pendingNotificationPermission.releaseWhenComplete(request) {
                // Registry 1.9 clears its launched key after invoking this
                // callback. Unregister on the next main-loop turn so the key
                // is removed as well as the callback.
                mainHandler.post { launcher.unregister() }
            }
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } catch (_: RuntimeException) {
            pendingNotificationPermission.complete(request)?.success(false)
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return try {
            getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun resolveExactAlarmPermissionRequest() {
        if (pendingExactAlarmPermissionResult == null ||
            !exactAlarmPermissionRequestLeftActivity
        ) {
            return
        }
        val result = pendingExactAlarmPermissionResult!!
        pendingExactAlarmPermissionResult = null
        exactAlarmPermissionRequestLeftActivity = false
        result.success(canScheduleExactAlarms())
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

    private fun requestExactAlarmPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || canScheduleExactAlarms()) {
            result.success(true)
            return
        }
        if (pendingExactAlarmPermissionResult != null) {
            result.error("busy", "An exact alarm permission request is already in progress.", null)
            return
        }
        pendingExactAlarmPermissionResult = result
        exactAlarmPermissionRequestLeftActivity = false
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (_: ActivityNotFoundException) {
            pendingExactAlarmPermissionResult = null
            exactAlarmPermissionRequestLeftActivity = false
            result.success(false)
        } catch (_: SecurityException) {
            pendingExactAlarmPermissionResult = null
            exactAlarmPermissionRequestLeftActivity = false
            result.success(false)
        }
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
        if (pendingSave.isPending) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        if (fileName.isNullOrBlank() || content == null) {
            result.error("invalidArguments", "Missing fileName or content.", null)
            return
        }

        val request = pendingSave.begin(SaveTextFileRequest(fileName, content, result))!!

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType?.takeIf { it.isNotBlank() } ?: "text/plain"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            // Register per call rather than reusing a launcher: an old picker
            // may still return after engine cleanup and a new Flutter call.
            // Direct registration also permits an engine attached after STARTED.
            val launcher = activityResultRegistry.register(
                request.key,
                ActivityResultContracts.StartActivityForResult(),
            ) { activityResult -> completeSaveTextFile(request, activityResult) }
            pendingSave.releaseWhenComplete(request) {
                mainHandler.post { launcher.unregister() }
            }
            launcher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            pendingSave.complete(request)?.result?.error(
                "unsupported", "No document provider is available.", null,
            )
        } catch (_: SecurityException) {
            pendingSave.complete(request)?.result?.error(
                "permissionDenied", "Permission denied while opening document provider.", null,
            )
        } catch (_: RuntimeException) {
            pendingSave.complete(request)?.result?.error(
                "failed", "Unable to open document provider.", null,
            )
        }
    }

    private fun completeSaveTextFile(
        request: PendingActivityRequest.Request,
        activityResult: ActivityResult,
    ) {
        val pending = pendingSave.complete(request) ?: return
        val result = pending.result

        val uri = activityResult.data?.data
        if (activityDestroying || isFinishing || isDestroyed ||
            activityResult.resultCode != Activity.RESULT_OK || uri == null
        ) {
            result.success(null)
            return
        }

        val streamOpened = try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(pending.content.toByteArray(Charsets.UTF_8))
                output.flush()
                true
            } ?: false
        } catch (_: SecurityException) {
            result.error("permissionDenied", "Permission denied while saving file.", null)
            return
        } catch (_: IOException) {
            result.error("failed", "Failed to save file.", null)
            return
        } catch (_: RuntimeException) {
            result.error("failed", "Document provider failed while saving file.", null)
            return
        }
        if (streamOpened) {
            result.success(pending.fileName)
        } else {
            result.error("failed", "Unable to open output stream.", null)
        }
    }

    private companion object {
        const val EXPORT_FILE_CHANNEL = "com.mashiro.sked/export_file"
        const val APP_INSTANCE_LEASE_CHANNEL = "com.mashiro.sked/app_instance_lease"
        const val MAX_PENDING_AGENDA_INTENTS = 16
    }
}

private fun MethodCall.epochMillisArgument(): Long? {
    val value = argument<Any>("atEpochMillis")
    return when (value) {
        is Number -> value.toLong().takeIf { it > 0L }
        else -> null
    }
}
