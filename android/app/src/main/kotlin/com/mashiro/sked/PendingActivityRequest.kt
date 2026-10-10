package com.mashiro.sked

import java.util.UUID

/** A single main-thread platform request whose callback may outlive its Flutter owner. */
internal class PendingActivityRequest<T : Any> {
    internal class Request {
        // Android restores registry keys across Activity/process recreation. A
        // restored result must never be delivered to a new Flutter call.
        val key: String = "sked:${UUID.randomUUID()}"
    }

    private class Pending<T>(
        val request: Request,
        val value: T,
        var release: (() -> Unit)? = null,
    )

    private var pending: Pending<T>? = null

    val isPending: Boolean
        get() = pending != null

    fun begin(value: T): Request? {
        if (isPending) return null
        return Request().also { pending = Pending(it, value) }
    }

    fun releaseWhenComplete(request: Request, release: () -> Unit) {
        val current = pending
        if (current?.request !== request) {
            release()
            return
        }
        check(current.release == null)
        current.release = release
    }

    fun complete(request: Request): T? {
        val current = pending ?: return null
        if (current.request !== request) return null
        // Drop the payload before releasing the launcher. A late callback only
        // retains the opaque Request, never a retired MethodChannel.Result or
        // the content of a cancelled export.
        pending = null
        current.release?.invoke()
        return current.value
    }

    fun cancel(): T? = pending?.request?.let(::complete)
}
