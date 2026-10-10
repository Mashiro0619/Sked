package com.mashiro.sked

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingActivityRequestTest {
    @Test
    fun rejectsConcurrentRequestWithoutReplacingTheFirstCaller() {
        val pending = PendingActivityRequest<Any>()
        val caller = Any()
        val request = pending.begin(caller)!!

        assertNull(pending.begin(Any()))
        assertTrue(pending.isPending)
        assertSame(caller, pending.complete(request))
        assertFalse(pending.isPending)
    }

    @Test
    fun lateCallbackFromRetiredEngineCannotConsumeItsReplacement() {
        val pending = PendingActivityRequest<Any>()
        val oldCaller = Any()
        val oldRequest = pending.begin(oldCaller)!!
        assertSame(oldCaller, pending.cancel())

        val newCaller = Any()
        val newRequest = pending.begin(newCaller)!!
        assertNotEquals(oldRequest.key, newRequest.key)
        assertNull(pending.complete(oldRequest))
        assertTrue(pending.isPending)
        assertSame(newCaller, pending.complete(newRequest))
    }

    @Test
    fun completionAndDuplicateCallbackReleaseLauncherExactlyOnce() {
        val pending = PendingActivityRequest<String>()
        val request = pending.begin("saved")!!
        var releases = 0
        pending.releaseWhenComplete(request) { releases++ }

        assertEquals("saved", pending.complete(request))
        assertNull(pending.complete(request))
        assertNull(pending.cancel())
        assertEquals(1, releases)
    }

    @Test
    fun ownerTeardownDropsPendingCallAndLateResult() {
        val pending = PendingActivityRequest<Any>()
        val caller = Any()
        val request = pending.begin(caller)!!
        var releases = 0
        pending.releaseWhenComplete(request) { releases++ }

        assertSame(caller, pending.cancel())
        assertNull(pending.cancel())
        assertNull(pending.complete(request))
        assertFalse(pending.isPending)
        assertEquals(1, releases)
    }

    @Test
    fun registrationCompletedAfterCancellationIsReleasedImmediately() {
        val pending = PendingActivityRequest<String>()
        val oldRequest = pending.begin("old")!!
        pending.cancel()
        val newRequest = pending.begin("new")!!
        var oldReleases = 0
        pending.releaseWhenComplete(oldRequest) { oldReleases++ }

        assertEquals(1, oldReleases)
        assertEquals("new", pending.complete(newRequest))
    }

    @Test
    fun recreatedOwnerDoesNotReuseRegistryKeyOrAcceptPreviousOwnersToken() {
        val oldOwner = PendingActivityRequest<String>()
        val oldRequest = oldOwner.begin("old")!!
        oldOwner.cancel()
        val newOwner = PendingActivityRequest<String>()
        val newRequest = newOwner.begin("new")!!

        assertNotEquals(oldRequest.key, newRequest.key)
        assertNull(newOwner.complete(oldRequest))
        assertEquals("new", newOwner.complete(newRequest))
    }

    @Test
    fun launchFailureLeavesSlotAvailableForRetry() {
        val pending = PendingActivityRequest<String>()
        val failedRequest = pending.begin("failed")!!
        var releases = 0
        pending.releaseWhenComplete(failedRequest) { releases++ }
        assertEquals("failed", pending.complete(failedRequest))

        val retryRequest = pending.begin("retry")!!
        assertEquals(1, releases)
        assertNull(pending.complete(failedRequest))
        assertEquals("retry", pending.complete(retryRequest))
    }
}
