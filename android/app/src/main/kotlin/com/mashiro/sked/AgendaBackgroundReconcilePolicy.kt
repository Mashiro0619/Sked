package com.mashiro.sked

/** Permission restoration can race with another revocation before delivery. */
internal object AgendaBackgroundReconcilePolicy {
    private const val EXACT_ALARM_PERMISSION_CHANGED =
        "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"

    fun shouldEnqueue(action: String?, canScheduleExactAlarms: () -> Boolean): Boolean {
        return action != EXACT_ALARM_PERMISSION_CHANGED || canScheduleExactAlarms()
    }
}
