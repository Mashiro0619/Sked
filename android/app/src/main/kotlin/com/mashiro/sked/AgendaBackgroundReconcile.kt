package com.mashiro.sked

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Receives the next projection boundary and protected system broadcasts, then
 * gives WorkManager a bounded window to start a headless Flutter engine.
 */
class AgendaBackgroundReconcileReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AgendaBackgroundReconcileScheduler.enqueue(
            context,
            intent?.action ?: AndroidProductivityContract.ACTION_AGENDA_RECONCILE,
        )
    }
}

/** Native scheduling shell for the Dart background projection. */
object AgendaBackgroundReconcileScheduler {
    private const val UNIQUE_WORK = "sked.agenda.background.reconcile"
    private const val REQUEST_CODE = 9302
    private const val MIN_DELAY_MILLIS = 1_000L

    fun schedule(context: Context, epochMillis: Long?) {
        val appContext = context.applicationContext
        val alarmManager = appContext.getSystemService(AlarmManager::class.java) ?: return
        val pending = pendingIntent(appContext)
        alarmManager.cancel(pending)
        val triggerAt = epochMillis
        if (triggerAt == null) {
            // A foreground reconciliation can legitimately have no next
            // boundary. Do not leave a retry work item from an earlier
            // system broadcast alive in that case.
            WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_WORK)
            return
        }
        val now = System.currentTimeMillis()
        if (triggerAt <= now + MIN_DELAY_MILLIS) {
            enqueue(context, AndroidProductivityContract.ACTION_AGENDA_RECONCILE)
            return
        }
        // This is only rolling-window maintenance, never user-facing reminder
        // delivery. Do not use allow-while-idle here: Android quotas those
        // wakeups per UID and a maintenance alarm can otherwise delay the
        // actual course/event reminder that uses exactAllowWhileIdle.
        alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pending)
    }

    fun cancel(context: Context) {
        val appContext = context.applicationContext
        appContext.getSystemService(AlarmManager::class.java)
            ?.cancel(pendingIntent(appContext))
        // Clearing Agenda runtime state must also remove work that was queued
        // by boot/time-zone broadcasts, not just the next AlarmManager wake.
        WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_WORK)
    }

    fun enqueue(context: Context, reason: String) {
        val request = OneTimeWorkRequestBuilder<AgendaBackgroundReconcileWorker>()
            .setInputData(
                androidx.work.Data.Builder()
                    .putString("reason", reason)
                    .build(),
            )
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                15,
                TimeUnit.MINUTES,
            )
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            UNIQUE_WORK,
            ExistingWorkPolicy.KEEP,
            request,
        )
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AgendaBackgroundReconcileReceiver::class.java).apply {
            action = AndroidProductivityContract.ACTION_AGENDA_RECONCILE
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/**
 * Hosts one headless Flutter execution. Dart reports completion over the same
 * productivity channel used by the foreground bridge; no native component
 * reads or interprets Sked_data.json.
 */
class AgendaBackgroundReconcileWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        val completion = CountDownLatch(1)
        val succeeded = AtomicBoolean(false)
        val started = AtomicBoolean(false)
        val engineRef = AtomicReference<FlutterEngine?>(null)
        val mainHandler = Handler(Looper.getMainLooper())

        mainHandler.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)

                val engine = FlutterEngine(applicationContext)
                engineRef.set(engine)
                // FlutterEngine registers generated plugins by default. A
                // second manual registration produces duplicate-plugin
                // warnings and can leave background plugin state device
                // dependent.
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    AndroidProductivityContract.CHANNEL,
                ).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "scheduleAgendaReconciliation" -> {
                            AgendaBackgroundReconcileScheduler.schedule(
                                applicationContext,
                                call.epochMillisArgument(),
                            )
                            result.success(null)
                        }
                        "cancelAgendaReconciliation" -> {
                            AgendaBackgroundReconcileScheduler.cancel(applicationContext)
                            result.success(null)
                        }
                        "completeBackgroundAgendaReconciliation" -> {
                            succeeded.set(call.argument<Boolean>("success") == true)
                            result.success(null)
                            completion.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
                started.set(true)
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:sked/services/agenda_background_reconciler.dart",
                        "agendaBackgroundReconcile",
                    ),
                )
            } catch (_: Exception) {
                completion.countDown()
            }
        }

        val completed = try {
            completion.await(MAX_EXECUTION_SECONDS, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            false
        } finally {
            mainHandler.post {
                engineRef.getAndSet(null)?.destroy()
            }
        }
        return when {
            !started.get() -> Result.retry()
            completed && succeeded.get() -> Result.success()
            else -> Result.retry()
        }
    }

    private companion object {
        const val MAX_EXECUTION_SECONDS = 90L
    }
}

private fun MethodCall.epochMillisArgument(): Long? {
    val value = argument<Any>("atEpochMillis")
    return when (value) {
        is Number -> value.toLong().takeIf { it > 0L }
        else -> null
    }
}
