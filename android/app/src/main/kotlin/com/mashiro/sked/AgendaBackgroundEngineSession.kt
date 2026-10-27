package com.mashiro.sked

import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Coordinates Worker cancellation with engine creation queued on the main thread. */
internal class AgendaBackgroundEngineSession {
    val completion = CountDownLatch(1)
    private val stopped = AtomicBoolean(false)
    private val release = AtomicReference<(() -> Unit)?>(null)

    val isStopped: Boolean get() = stopped.get()

    // Called on the main thread, as is releaseEngine. If cancellation won the
    // initialization race, dispose the late engine without starting Dart.
    fun registerEngine(disposeEngine: () -> Unit): Boolean {
        check(release.compareAndSet(null, disposeEngine))
        if (!isStopped) return true
        releaseEngine()
        return false
    }

    fun stop() {
        stopped.set(true)
        completion.countDown()
    }

    fun releaseEngine() {
        release.getAndSet(null)?.invoke()
    }
}
