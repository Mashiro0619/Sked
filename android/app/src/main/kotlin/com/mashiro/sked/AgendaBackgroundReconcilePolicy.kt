package com.mashiro.sked

/** Permission restoration can race with another revocation before delivery. */
internal object AgendaBackgroundReconcilePolicy {
    private const val EXACT_ALARM_PERMISSION_CHANGED =
        "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"

    fun shouldEnqueue(action: String?, canScheduleExactAlarms: () -> Boolean): Boolean {
        return action != EXACT_ALARM_PERMISSION_CHANGED || canScheduleExactAlarms()
    }

    fun outcome(runAttemptCount: Int, succeeded: Boolean): AgendaBackgroundReconcileOutcome {
        return when {
            succeeded -> AgendaBackgroundReconcileOutcome.SUCCESS
            runAttemptCount < MAX_RETRIES -> AgendaBackgroundReconcileOutcome.RETRY
            else -> AgendaBackgroundReconcileOutcome.FAILURE
        }
    }

    // WorkManager starts at zero: the initial attempt may be followed by three retries.
    private const val MAX_RETRIES = 3
}

internal enum class AgendaBackgroundReconcileOutcome { SUCCESS, RETRY, FAILURE }
