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
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
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

class MainActivity : FlutterActivity() {
    private val appInstanceLeaseEngineId = AppInstanceLeaseGuard.createEngineId()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingAgendaIntents = ArrayDeque<String>()
    private var initialAgendaIntentConsumed = false
    private var appInstanceLeaseChannel: MethodChannel? = null
    private var productivityChannel: MethodChannel? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var pendingExactAlarmPermissionResult: MethodChannel.Result? = null
    private var exactAlarmPermissionRequestLeftActivity = false
    private var pendingBatteryOptimizationResult: MethodChannel.Result? = null
    private var batteryOptimizationRequestLeftActivity = false
    private var batteryOptimizationFallbackOpened = false
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContent: String? = null
    private var pendingSaveFileName: String? = null

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
        resolveBatteryOptimizationRequest()
    }

    override fun onPause() {
        if (pendingExactAlarmPermissionResult != null) {
            exactAlarmPermissionRequestLeftActivity = true
        }
        if (pendingBatteryOptimizationResult != null) {
            batteryOptimizationRequestLeftActivity = true
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
            if (pendingBatteryOptimizationResult != null) {
                batteryOptimizationRequestLeftActivity = true
            }
        } else {
            resolveExactAlarmPermissionRequest()
            resolveBatteryOptimizationRequest()
        }
    }

    override fun onDestroy() {
        // Permission requests retain a MethodChannel.Result until Android
        // calls back.  A configuration/process teardown can happen before
        // that callback (for example when the permission dialog is dismissed
        // by the system), so release the result instead of retaining the
        // Activity through the channel bridge or attempting to reply later.
        pendingNotificationPermissionResult?.let { result ->
            pendingNotificationPermissionResult = null
            result.success(false)
        }
        pendingExactAlarmPermissionResult?.let { result ->
            pendingExactAlarmPermissionResult = null
            exactAlarmPermissionRequestLeftActivity = false
            result.success(false)
        }
        pendingBatteryOptimizationResult?.let { result ->
            pendingBatteryOptimizationResult = null
            batteryOptimizationRequestLeftActivity = false
            batteryOptimizationFallbackOpened = false
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXPORT_FILE_CHANNEL,
        ).setMethodCallHandler { call, result ->
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
        // A settings Activity can outlive the Flutter engine that initiated
        // it. Its MethodChannel.Result belongs to that old engine, so never
        // retain it until onResume() or the platform permission callback.
        // A newly attached engine must be free to issue a fresh request.
        pendingNotificationPermissionResult = null
        pendingExactAlarmPermissionResult = null
        exactAlarmPermissionRequestLeftActivity = false
        pendingBatteryOptimizationResult = null
        batteryOptimizationRequestLeftActivity = false
        batteryOptimizationFallbackOpened = false
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            isNotificationPermissionGranted()) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error("busy", "A notification permission request is already in progress.", null)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
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

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val manager = getSystemService(PowerManager::class.java) ?: return false
        return manager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            isIgnoringBatteryOptimizations()
        ) {
            result.success(true)
            return
        }
        if (pendingBatteryOptimizationResult != null) {
            result.error(
                "busy",
                "A battery optimization request is already in progress.",
                null,
            )
            return
        }
        pendingBatteryOptimizationResult = result
        batteryOptimizationRequestLeftActivity = false
        batteryOptimizationFallbackOpened = false
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (_: ActivityNotFoundException) {
            if (!openBatteryOptimizationSettingsFallback()) {
                pendingBatteryOptimizationResult = null
                result.success(false)
            }
        } catch (_: SecurityException) {
            if (!openBatteryOptimizationSettingsFallback()) {
                pendingBatteryOptimizationResult = null
                result.success(false)
            }
        }
    }

    /** Resolves only after returning from Android's request/settings surface. */
    private fun resolveBatteryOptimizationRequest() {
        val result = pendingBatteryOptimizationResult ?: return
        if (!batteryOptimizationRequestLeftActivity) return
        if (isIgnoringBatteryOptimizations()) {
            pendingBatteryOptimizationResult = null
            batteryOptimizationRequestLeftActivity = false
            batteryOptimizationFallbackOpened = false
            result.success(true)
            return
        }
        // OEM request dialogs can close without applying the allowlist change.
        // The public settings list is the only universal fallback; wait for its
        // return too and report the actual PowerManager state, never launch
        // success merely because an Activity could be started.
        if (!batteryOptimizationFallbackOpened &&
            openBatteryOptimizationSettingsFallback()
        ) {
            return
        }
        pendingBatteryOptimizationResult = null
        batteryOptimizationRequestLeftActivity = false
        batteryOptimizationFallbackOpened = false
        result.success(false)
    }

    private fun openBatteryOptimizationSettingsFallback(): Boolean {
        return try {
            batteryOptimizationFallbackOpened = true
            batteryOptimizationRequestLeftActivity = false
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return
        val result = pendingNotificationPermissionResult ?: return
        pendingNotificationPermissionResult = null
        result.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED &&
                isNotificationPermissionGranted(),
        )
    }

    private fun saveTextFile(
        fileName: String?,
        content: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        if (fileName.isNullOrBlank() || content == null) {
            result.error("invalidArguments", "Missing fileName or content.", null)
            return
        }

        pendingSaveResult = result
        pendingSaveContent = content
        pendingSaveFileName = fileName

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType?.takeIf { it.isNotBlank() } ?: "text/plain"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            startActivityForResult(intent, SAVE_TEXT_FILE_REQUEST_CODE)
        } catch (_: ActivityNotFoundException) {
            clearPendingSave()
            result.error("unsupported", "No document provider is available.", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_TEXT_FILE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingSaveResult ?: return
        val content = pendingSaveContent
        val fileName = pendingSaveFileName
        clearPendingSave()

        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || content == null) {
            result.success(null)
            return
        }

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: run {
                result.error("failed", "Unable to open output stream.", null)
                return
            }
            result.success(fileName)
        } catch (_: SecurityException) {
            result.error("permissionDenied", "Permission denied while saving file.", null)
        } catch (_: IOException) {
            result.error("failed", "Failed to save file.", null)
        }
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveContent = null
        pendingSaveFileName = null
    }

    private companion object {
        const val EXPORT_FILE_CHANNEL = "com.mashiro.sked/export_file"
        const val APP_INSTANCE_LEASE_CHANNEL = "com.mashiro.sked/app_instance_lease"
        const val SAVE_TEXT_FILE_REQUEST_CODE = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
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
