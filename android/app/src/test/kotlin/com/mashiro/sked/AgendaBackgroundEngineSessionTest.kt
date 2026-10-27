package com.mashiro.sked

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgendaBackgroundEngineSessionTest {
    @Test
    fun stoppingReleasesTheWaitingWorkerWithoutWaitingForTheExecutionTimeout() {
        val session = AgendaBackgroundEngineSession()
        assertEquals(1L, session.completion.count)

        session.stop()

        assertTrue(session.isStopped)
        assertEquals(0L, session.completion.count)
    }

    @Test
    fun engineCreatedAfterCancellationIsReleasedBeforeDartCanStart() {
        val session = AgendaBackgroundEngineSession()
        session.stop()
        var releases = 0

        assertFalse(session.registerEngine { releases++ })
        session.releaseEngine()

        assertEquals(1, releases)
    }

    @Test
    fun stopAndFinallyCleanupReleaseAnAlreadyRunningEngineOnlyOnce() {
        val session = AgendaBackgroundEngineSession()
        var releases = 0
        assertTrue(session.registerEngine { releases++ })

        session.stop()
        session.releaseEngine()
        session.stop()
        session.releaseEngine()

        assertEquals(1, releases)
    }
}
