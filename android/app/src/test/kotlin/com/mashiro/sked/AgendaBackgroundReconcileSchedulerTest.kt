package com.mashiro.sked

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgendaBackgroundReconcileSchedulerTest {
    @Test
    fun backgroundCancelKeepsTheWorkerAliveUntilItCanReportSuccess() {
        val probe = SchedulingProbe()

        probe.cancel(AgendaBackgroundCancellationScope.RENEWAL_ONLY)

        probe.assertWaitingForCompletion()
        assertEquals(listOf("cancel renewal"), probe.operations)
        assertNull(probe.renewalAt)
        probe.completeSuccessfully()
    }

    @Test
    fun backgroundNullScheduleAlsoKeepsTheWorkerAliveUntilCompletion() {
        val probe = SchedulingProbe()

        probe.schedule(null, AgendaBackgroundCancellationScope.RENEWAL_ONLY)

        probe.assertWaitingForCompletion()
        assertEquals(listOf("cancel renewal"), probe.operations)
        assertNull(probe.renewalAt)
        probe.completeSuccessfully()
    }

    @Test
    fun foregroundClearCancelsRenewalAndStopsQueuedOrRunningWork() {
        val probe = SchedulingProbe()

        probe.cancel(AgendaBackgroundCancellationScope.RENEWAL_AND_WORK)

        probe.assertWorkCancelled()
    }

    @Test
    fun foregroundNullScheduleAlsoCancelsWorkWhenNoAlarmRemains() {
        val probe = SchedulingProbe().apply { renewalAt = null }

        probe.schedule(null, AgendaBackgroundCancellationScope.RENEWAL_AND_WORK)

        probe.assertWorkCancelled()
    }

    @Test
    fun replacingAFutureRenewalDoesNotStopActiveWorkForEitherCaller() {
        for (scope in AgendaBackgroundCancellationScope.entries) {
            val probe = SchedulingProbe()

            probe.schedule(SchedulingProbe.NOW + 60_000L, scope)

            probe.assertWaitingForCompletion()
            assertEquals(SchedulingProbe.NOW + 60_000L, probe.renewalAt)
            assertEquals(listOf("cancel renewal", "schedule renewal"), probe.operations)
        }
    }

    @Test
    fun dueRenewalEnqueuesWorkWithoutCancellingAnActiveWorker() {
        for (scope in AgendaBackgroundCancellationScope.entries) {
            val probe = SchedulingProbe()

            probe.schedule(SchedulingProbe.NOW + 1_000L, scope)

            probe.assertWaitingForCompletion()
            assertNull(probe.renewalAt)
            assertEquals(listOf("cancel renewal", "enqueue work"), probe.operations)
        }
    }

    private class SchedulingProbe {
        val session = AgendaBackgroundEngineSession()
        val operations = mutableListOf<String>()
        var renewalAt: Long? = NOW + 120_000L
        private var engineReleases = 0
        private var workCancelled = false

        init {
            assertTrue(session.registerEngine { engineReleases++ })
        }

        private val cancelRenewal: () -> Unit = {
            operations += "cancel renewal"
            renewalAt = null
        }
        private val cancelWork: () -> Unit = {
            operations += "cancel work"
            workCancelled = true
            // Model WorkManager's onStopped callback on the actual lifecycle
            // coordinator, including the release queued on the main thread.
            session.stop()
            session.releaseEngine()
        }

        fun cancel(scope: AgendaBackgroundCancellationScope) {
            AgendaBackgroundReconcileScheduler.cancel(scope, cancelRenewal, cancelWork)
        }

        fun schedule(at: Long?, scope: AgendaBackgroundCancellationScope) {
            AgendaBackgroundReconcileScheduler.schedule(
                epochMillis = at,
                nowMillis = NOW,
                cancellationScope = scope,
                cancelRenewal = cancelRenewal,
                cancelWork = cancelWork,
                enqueueNow = { operations += "enqueue work" },
                scheduleRenewal = {
                    operations += "schedule renewal"
                    renewalAt = it
                },
            )
        }

        fun assertWaitingForCompletion() {
            assertFalse(workCancelled)
            assertFalse(session.isStopped)
            assertEquals(1L, session.completion.count)
            assertEquals(0, engineReleases)
        }

        fun completeSuccessfully() {
            assertFalse(session.isStopped)
            session.completion.countDown()
            assertEquals(0L, session.completion.count)
            assertEquals(
                AgendaBackgroundReconcileOutcome.SUCCESS,
                AgendaBackgroundReconcilePolicy.outcome(0, true),
            )
            session.stop()
            session.releaseEngine()
            assertEquals(1, engineReleases)
        }

        fun assertWorkCancelled() {
            assertEquals(listOf("cancel renewal", "cancel work"), operations)
            assertNull(renewalAt)
            assertTrue(workCancelled)
            assertTrue(session.isStopped)
            assertEquals(0L, session.completion.count)
            assertEquals(1, engineReleases)
        }

        companion object {
            const val NOW = 1_000_000L
        }
    }
}
