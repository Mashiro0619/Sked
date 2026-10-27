package com.mashiro.sked

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Build
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.mashiro.sked.androidproductivity.BatteryOptimizationStatus
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Receives the next projection boundary and protected system broadcasts, then
 * gives WorkManager a bounded window to start a headless Flutter engine.
 */
class AgendaBackgroundReconcileReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val shouldEnqueue = AgendaBackgroundReconcilePolicy.shouldEnqueue(intent?.action) {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                context.getSystemService(AlarmManager::class.java)
                    ?.canScheduleExactAlarms() == true
        }
        if (!shouldEnqueue) return
        // A restored exact-alarm grant follows the same reconciliation path as
        // boot/time changes. KEEP coalesces broadcasts with an active worker.
        AgendaBackgroundReconcileScheduler.enqueue(
            context,
            intent?.action ?: AndroidProductivityContract.ACTION_AGENDA_RECONCILE,
        )
    }
}

enum class AgendaBackgroundCancellationScope {
    RENEWAL_ONLY,
    RENEWAL_AND_WORK,
}

/** Native scheduling shell for the Dart background projection. */
object AgendaBackgroundReconcileScheduler {
    private const val UNIQUE_WORK = "sked.agenda.background.reconcile"
    private const val REQUEST_CODE = 9302
    private const val MIN_DELAY_MILLIS = 1_000L

    fun schedule(
        context: Context,
        epochMillis: Long?,
        cancellationScope: AgendaBackgroundCancellationScope =
            AgendaBackgroundCancellationScope.RENEWAL_AND_WORK,
    ) {
        val appContext = context.applicationContext
        val alarmManager = appContext.getSystemService(AlarmManager::class.java)
        schedule(
            epochMillis = epochMillis,
            nowMillis = System.currentTimeMillis(),
            cancellationScope = cancellationScope,
            cancelRenewal = { alarmManager?.cancel(pendingIntent(appContext)) },
            cancelWork = { WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_WORK) },
            enqueueNow = {
                enqueue(appContext, AndroidProductivityContract.ACTION_AGENDA_RECONCILE)
            },
            scheduleRenewal = { triggerAt ->
                // This best-effort renewal must not use allow-while-idle and
                // consume the Android quota needed by user-facing reminders.
                alarmManager?.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent(appContext),
                )
            },
        )
    }

    fun cancel(
        context: Context,
        cancellationScope: AgendaBackgroundCancellationScope =
            AgendaBackgroundCancellationScope.RENEWAL_AND_WORK,
    ) {
        val appContext = context.applicationContext
        cancel(
            cancellationScope = cancellationScope,
            cancelRenewal = {
                appContext.getSystemService(AlarmManager::class.java)
                    ?.cancel(pendingIntent(appContext))
            },
            cancelWork = { WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_WORK) },
        )
    }

    internal fun schedule(
        epochMillis: Long?,
        nowMillis: Long,
        cancellationScope: AgendaBackgroundCancellationScope,
        cancelRenewal: () -> Unit,
        cancelWork: () -> Unit,
        enqueueNow: () -> Unit,
        scheduleRenewal: (Long) -> Unit,
    ) {
        cancel(
            cancellationScope = if (epochMillis == null) {
                cancellationScope
            } else {
                AgendaBackgroundCancellationScope.RENEWAL_ONLY
            },
            cancelRenewal = cancelRenewal,
            cancelWork = cancelWork,
        )
        if (epochMillis == null) return
        if (epochMillis <= nowMillis + MIN_DELAY_MILLIS) {
            enqueueNow()
        } else {
            scheduleRenewal(epochMillis)
        }
    }

    internal fun cancel(
        cancellationScope: AgendaBackgroundCancellationScope,
        cancelRenewal: () -> Unit,
        cancelWork: () -> Unit,
    ) {
        cancelRenewal()
        if (cancellationScope == AgendaBackgroundCancellationScope.RENEWAL_AND_WORK) {
            // Foreground clear must remove queued work as well as its alarm.
            // A Worker publishing no next renewal must survive to report success.
            cancelWork()
        }
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
    private val session = AgendaBackgroundEngineSession()
    private val failureReason = AtomicReference("execution_timed_out")
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun doWork(): Result {
        val succeeded = AtomicBoolean(false)

        mainHandler.post {
            if (session.isStopped) return@post
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)

                val engine = FlutterEngine(applicationContext)
                if (!session.registerEngine { engine.destroy() }) return@post
                // FlutterEngine registers generated plugins by default. A
                // second manual registration produces duplicate-plugin
                // warnings and can leave background plugin state device
                // dependent.
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    AndroidProductivityContract.CHANNEL,
                ).setMethodCallHandler { call, result ->
                    if (session.isStopped) {
                        result.error("background_reconciliation_stopped", null, null)
                        return@setMethodCallHandler
                    }
                    when (call.method) {
                        AndroidProductivityContract.METHOD_IS_IGNORING_BATTERY_OPTIMIZATIONS -> {
                            result.success(
                                BatteryOptimizationStatus.isIgnoringOptimizations(
                                    applicationContext,
                                ),
                            )
                        }
                        "scheduleAgendaReconciliation" -> {
                            AgendaBackgroundReconcileScheduler.schedule(
                                applicationContext,
                                call.epochMillisArgument(),
                                AgendaBackgroundCancellationScope.RENEWAL_ONLY,
                            )
                            result.success(null)
                        }
                        "cancelAgendaReconciliation" -> {
                            AgendaBackgroundReconcileScheduler.cancel(
                                applicationContext,
                                AgendaBackgroundCancellationScope.RENEWAL_ONLY,
                            )
                            result.success(null)
                        }
                        "completeBackgroundAgendaReconciliation" -> {
                            succeeded.set(call.argument<Boolean>("success") == true)
                            if (!succeeded.get()) failureReason.set("reconciliation_failed")
                            result.success(null)
                            session.completion.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
                if (session.isStopped) return@post
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:sked/services/agenda_background_reconciler.dart",
                        "agendaBackgroundReconcile",
                    ),
                )
            } catch (_: Exception) {
                failureReason.set("engine_start_failed")
                session.completion.countDown()
            }
        }

        val completed = try {
            session.completion.await(MAX_EXECUTION_SECONDS, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            failureReason.set("interrupted")
            Thread.currentThread().interrupt()
            false
        } finally {
            // Also stop queued initialization after a timeout, so an engine
            // created late cannot continue after this Worker has returned.
            session.stop()
            mainHandler.post { session.releaseEngine() }
        }
        return when (
            AgendaBackgroundReconcilePolicy.outcome(
                runAttemptCount,
                completed && succeeded.get(),
            )
        ) {
            AgendaBackgroundReconcileOutcome.SUCCESS -> Result.success()
            AgendaBackgroundReconcileOutcome.RETRY -> Result.retry()
            AgendaBackgroundReconcileOutcome.FAILURE -> Result.failure(
                Data.Builder()
                    .putString("failureReason", failureReason.get())
                    .putInt("runAttemptCount", runAttemptCount)
                    .putString("trigger", inputData.getString("reason"))
                    .build(),
            )
        }
    }

    override fun onStopped() {
        failureReason.set("stopped")
        session.stop()
        mainHandler.post { session.releaseEngine() }
        super.onStopped()
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
