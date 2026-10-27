package com.mashiro.sked

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
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

    @Test
    fun initialFailureAndFirstTwoRetriesCanRetryButThirdRetryIsTerminal() {
        for (attempt in 0..2) {
            assertEquals(
                AgendaBackgroundReconcileOutcome.RETRY,
                AgendaBackgroundReconcilePolicy.outcome(attempt, succeeded = false),
            )
        }
        for (attempt in 3..6) {
            assertEquals(
                AgendaBackgroundReconcileOutcome.FAILURE,
                AgendaBackgroundReconcilePolicy.outcome(attempt, succeeded = false),
            )
        }
    }

    @Test
    fun successfulReconciliationStillSucceedsOnTheLastAllowedAttempt() {
        for (attempt in 0..3) {
            assertEquals(
                AgendaBackgroundReconcileOutcome.SUCCESS,
                AgendaBackgroundReconcilePolicy.outcome(attempt, succeeded = true),
            )
        }
    }
}
