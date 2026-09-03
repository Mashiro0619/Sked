package com.mashiro.sked

/** Stable names shared by the Flutter bridge and notification scheduler. */
object AndroidProductivityContract {
    const val CHANNEL = "com.mashiro.sked/android_productivity"
    const val ACTION_OPEN_AGENDA = "com.mashiro.sked.action.OPEN_AGENDA"
    const val EXTRA_AGENDA_TARGET = "com.mashiro.sked.extra.AGENDA_TARGET"
    const val ACTION_AGENDA_RECONCILE = "com.mashiro.sked.action.AGENDA_RECONCILE"
    const val METHOD_GET_NOTIFICATION_DIAGNOSTICS = "getNotificationDiagnostics"
}
