package com.mashiro.sked

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgendaBackgroundReconcilePolicyTest {
    @Test
    fun rechecksExactAlarmGrantWhenRestorationBroadcastArrives() {
        val action = "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
        assertTrue(AgendaBackgroundReconcilePolicy.shouldEnqueue(action) { true })
        assertFalse(AgendaBackgroundReconcilePolicy.shouldEnqueue(action) { false })
    }

    @Test
    fun otherBroadcastsKeepTheirExistingReconciliationPath() {
        for (action in listOf(null, "android.intent.action.BOOT_COMPLETED", "android.intent.action.TIME_SET")) {
            assertTrue(
                AgendaBackgroundReconcilePolicy.shouldEnqueue(action) {
                    throw AssertionError("Unrelated broadcasts must not query the exact-alarm grant")
                },
            )
        }
    }
}
