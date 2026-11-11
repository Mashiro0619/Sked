package com.mashiro.sked

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.OperationCanceledException
import android.os.ParcelFileDescriptor
import android.os.Process
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.FileNotFoundException
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

internal class AgentFileFailure(
    val code: String,
    override val message: String,
    val osCode: Int? = null,
    cause: Throwable? = null,
    val cleanupIncomplete: Boolean = false,
) : Exception(message, cause)

private class CursorCleanupFailure(cause: Exception? = null) :
    Exception("The provider cursor could not be closed.", cause)

/** Application-owned JNI bridge. No Activity or Flutter result crosses this boundary. */
class AgentFileAccess(context: Context) {
    private class CallState {
        val cancellation = CancellationSignal()
        val running = AtomicBoolean(false)
    }

    private class DirectoryLease(
        val parent: Uri,
        val cursor: Cursor,
        val queryCancellation: CancellationSignal,
    ) {
        val id = UUID.randomUUID().toString()
        val lock = ReentrantLock()
        var closing = false
        var closed = false
        var done = false
    }

    private class QueryScope {
        val cursorIds = linkedSetOf<String>()
    }

    private class FdLease(val descriptor: ParcelFileDescriptor) {
        val lock = ReentrantLock()
        var closed = false
    }

    private data class PickerCleanup(val epoch: Long, val completion: CompletableFuture<Unit>)

    private val application = context.applicationContext
    private val resolver = application.contentResolver
    private val grantStore = AgentFileGrantStore(application)
    private val calls = ConcurrentHashMap<String, CallState>()
    private val directories = ConcurrentHashMap<String, DirectoryLease>()
    private val descriptors = ConcurrentHashMap<String, FdLease>()
    private val queryScope = ThreadLocal<QueryScope>()
    private val pendingPickerCursors = ConcurrentHashMap<String, String>()
    private val retiredPickerCleanups = ConcurrentHashMap<String, PickerCleanup>()
    private val clearedSelectionEpoch = AtomicLong(-1)
    private val workers = Executors.newCachedThreadPool { task ->
        Thread(task, "sked-agent-file-access").apply { isDaemon = true }
    }

    /** Rust brackets each call with beginCall/endCall before installing its cancel watcher. */
    fun call(requestJson: String): String {
        val scope = QueryScope()
        return withQueryScope(scope) {
            val reply = try {
                JSONObject().put("ok", true).put("value", performCall(requestJson))
            } catch (error: Exception) {
                JSONObject().put("ok", false).put("error", errorJson(error))
            }
            if (scope.cursorIds.isNotEmpty()) {
                reply.put("pendingCursorIds", JSONArray(scope.cursorIds.toList()))
            }
            reply.toString()
        }
    }

    private fun performCall(requestJson: String): JSONObject {
        val request = JSONObject(requestJson)
        val callId = request.requiredString("callId")
        val operation = request.requiredString("op")
        return when (operation) {
            "beginCall" -> {
                if (calls.putIfAbsent(callId, CallState()) != null) {
                    throw AgentFileFailure("busy", "The native file call is already registered.")
                }
                JSONObject()
            }
            "endCall" -> {
                val state = calls[callId]
                if (state != null) {
                    if (state.running.get()) {
                        throw AgentFileFailure("busy", "The native file call is still running.")
                    }
                    calls.remove(callId, state)
                }
                JSONObject()
            }
            else -> {
                val state = calls[callId]
                    ?: throw AgentFileFailure("invalidArgument", "The native file call was not registered.")
                if (!state.running.compareAndSet(false, true)) {
                    throw AgentFileFailure("busy", "The native file call is already running.")
                }
                try {
                    dispatch(operation, request, state.cancellation)
                } finally {
                    state.running.set(false)
                }
            }
        }
    }

    fun cancel(callId: String) {
        calls[callId]?.cancellation?.cancel()
    }

    private fun dispatch(
        operation: String,
        request: JSONObject,
        cancellation: CancellationSignal,
    ): JSONObject {
        // Close operations remain usable after cancellation and wait for the actual close.
        when (operation) {
            "closeFd" -> {
                closeFd(request.requiredString("fdLease"))
                return JSONObject()
            }
            "closeCursor" -> {
                closeCursor(request.requiredString("cursorId"))
                return JSONObject()
            }
        }
        cancellation.throwIfCanceled()
        return when (operation) {
            "describe" -> describe(parseResource(request.requiredString("uri")), cancellation)
            "openDirectory" -> openDirectory(parseResource(request.requiredString("uri")), cancellation)
            "nextDirectory" -> nextDirectory(
                request.requiredString("cursorId"),
                request.getLong("pageSize"),
                cancellation,
            )
            "openRead" -> openDescriptor(parseResource(request.requiredString("uri")), "r", cancellation)
            "openWrite" -> openDescriptor(
                parseResource(request.requiredString("uri")),
                request.nullableString("mode") ?: "wt",
                cancellation,
            )
            "createDocument" -> createDocument(
                parseResource(request.requiredString("parentUri")),
                request.getString("name"),
                request.getString("mimeType"),
                cancellation,
            )
            else -> throw AgentFileFailure("unsupported", "The native file operation is not supported.")
        }
    }

    private fun describe(uri: Uri, cancellation: CancellationSignal): JSONObject {
        cancellation.throwIfCanceled()
        val document = DocumentsContract.isDocumentUri(application, uri)
        val projection = if (document) DOCUMENT_COLUMNS else OPENABLE_COLUMNS
        val mimeType = if (document) null else resolver.getType(uri)
        val lease = queryCursor(uri, uri, projection, cancellation)
        var failure: Exception? = null
        try {
            cancellation.throwIfCanceled()
            if (!lease.cursor.moveToFirst()) throw FileNotFoundException("The requested URI no longer exists.")
            return metadata(uri, lease.cursor, document, mimeType)
        } catch (error: Exception) {
            failure = error
            throw error
        } finally {
            closeQueryCursor(lease.id, failure)
        }
    }

    private fun queryCursor(
        parent: Uri,
        queryUri: Uri,
        projection: Array<String>,
        cancellation: CancellationSignal,
    ): DirectoryLease {
        val scope = checkNotNull(queryScope.get()) { "A provider query requires a cleanup scope." }
        val cursor = resolver.query(queryUri, projection, null, null, null, cancellation)
            ?: throw IOException("The provider returned no query cursor.")
        val lease = DirectoryLease(parent, cursor, cancellation)
        directories[lease.id] = lease
        scope.cursorIds.add(lease.id)
        return lease
    }

    private fun closeQueryCursor(id: String, failure: Exception? = null) {
        try {
            closeCursor(id)
        } catch (cleanup: Exception) {
            throw CursorCleanupFailure(cleanup).apply { failure?.let { addSuppressed(it) } }
        }
    }

    private fun <T> withQueryScope(scope: QueryScope, operation: () -> T): T {
        val previous = queryScope.get()
        queryScope.set(scope)
        try {
            return operation()
        } finally {
            if (previous == null) queryScope.remove() else queryScope.set(previous)
        }
    }

    internal fun <T> withPickerQueries(ownerId: String, operation: () -> T): T {
        val scope = QueryScope()
        return withQueryScope(scope) {
            try {
                val result = operation()
                if (scope.cursorIds.isNotEmpty()) throw CursorCleanupFailure()
                result
            } finally {
                // Publish before the worker completion that a cleanup barrier waits for.
                for (id in scope.cursorIds) pendingPickerCursors[id] = ownerId
            }
        }
    }

    private fun metadata(
        uri: Uri,
        cursor: Cursor,
        document: Boolean,
        fallbackMimeType: String? = null,
    ): JSONObject {
        val mimeType = if (document) {
            cursor.stringOrNull(DocumentsContract.Document.COLUMN_MIME_TYPE)
        } else {
            fallbackMimeType
        }
        val documentId = if (document) {
            cursor.stringOrNull(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                ?: DocumentsContract.getDocumentId(uri)
        } else {
            null
        }
        val name = cursor.stringOrNull(OpenableColumns.DISPLAY_NAME)
            ?: uri.lastPathSegment ?: uri.toString()
        val flags = if (document) {
            cursor.longOrNull(DocumentsContract.Document.COLUMN_FLAGS) ?: 0L
        } else {
            0L
        }
        val directory = document && mimeType == DocumentsContract.Document.MIME_TYPE_DIR
        val virtual = document && flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT.toLong() != 0L
        val file = !directory && (!document || mimeType != null)
        val readPermission = hasUriAccess(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val writePermission = hasUriAccess(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        val size = cursor.longOrNull(OpenableColumns.SIZE)?.takeIf { it >= 0 }
        val modified = if (document) {
            cursor.longOrNull(DocumentsContract.Document.COLUMN_LAST_MODIFIED)?.takeIf { it > 0 }
        } else {
            null
        }
        return JSONObject()
            .put("uri", uri.toString())
            .put("authority", uri.authority)
            .put("documentId", documentId ?: JSONObject.NULL)
            .put("name", name)
            .put("kind", if (directory) "directory" else if (file) "file" else "other")
            .put("mimeType", mimeType ?: JSONObject.NULL)
            .put("size", size ?: JSONObject.NULL)
            .put("modifiedAtMs", modified ?: JSONObject.NULL)
            .put("flags", flags)
            .put("read", file && !virtual && readPermission)
            .put("list", directory && readPermission)
            .put(
                "create",
                directory && writePermission &&
                    flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE.toLong() != 0L,
            )
            .put(
                "modify",
                file && !virtual && writePermission &&
                    (!document || flags and DocumentsContract.Document.FLAG_SUPPORTS_WRITE.toLong() != 0L),
            )
    }

    private fun openDirectory(uri: Uri, cancellation: CancellationSignal): JSONObject {
        val directory = describe(uri, cancellation)
        if (directory.getString("kind") != "directory") {
            throw AgentFileFailure("invalidArgument", "The requested URI is not a document directory.")
        }
        val documentId = DocumentsContract.getDocumentId(uri)
        val children = if (DocumentsContract.isTreeUri(uri)) {
            DocumentsContract.buildChildDocumentsUriUsingTree(uri, documentId)
        } else {
            DocumentsContract.buildChildDocumentsUri(uri.authority, documentId)
        }
        val lease = queryCursor(uri, children, DOCUMENT_COLUMNS, cancellation)
        try {
            requireDirectoryReady(lease.cursor)
            val result = JSONObject().put("cursorId", lease.id).put("directory", directory)
            // Once returned, Rust owns this cursor even if cancellation has just arrived.
            queryScope.get().cursorIds.remove(lease.id)
            return result
        } catch (error: Exception) {
            closeQueryCursor(lease.id, error)
            throw error
        }
    }

    private fun nextDirectory(
        id: String,
        pageSize: Long,
        cancellation: CancellationSignal,
    ): JSONObject {
        if (pageSize <= 0 || pageSize > Int.MAX_VALUE) {
            throw AgentFileFailure("invalidArgument", "The directory page size is outside the cursor range.")
        }
        val lease = directories[id]
            ?: throw AgentFileFailure("notFound", "The directory cursor is closed.")
        cancellation.setOnCancelListener { lease.queryCancellation.cancel() }
        try {
            return lease.lock.withLock {
                if (lease.closing || lease.closed) {
                    throw AgentFileFailure("notFound", "The directory cursor is closed.")
                }
                cancellation.throwIfCanceled()
                lease.queryCancellation.throwIfCanceled()
                val entries = JSONArray()
                while (!lease.done && entries.length() < pageSize) {
                    cancellation.throwIfCanceled()
                    if (!lease.cursor.moveToNext()) {
                        requireDirectoryReady(lease.cursor)
                        lease.done = true
                        break
                    }
                    val documentId = lease.cursor.stringOrNull(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                        ?: throw IOException("The provider returned a directory entry without an identity.")
                    val child = if (DocumentsContract.isTreeUri(lease.parent)) {
                        DocumentsContract.buildDocumentUriUsingTree(lease.parent, documentId)
                    } else {
                        DocumentsContract.buildDocumentUri(lease.parent.authority, documentId)
                    }
                    entries.put(metadata(child, lease.cursor, true))
                }
                JSONObject().put("entries", entries).put("done", lease.done)
            }
        } finally {
            cancellation.setOnCancelListener(null)
        }
    }

    private fun closeCursor(id: String) {
        val lease = directories[id]
        if (lease != null) {
            lease.lock.withLock {
                lease.closing = true
                if (!lease.closed) {
                    lease.cursor.close()
                    lease.closed = true
                }
            }
            directories.remove(id, lease)
        }
        queryScope.get()?.cursorIds?.remove(id)
        pendingPickerCursors.remove(id)
    }

    private fun requireDirectoryReady(cursor: Cursor) {
        val extras = cursor.extras
        extras.getString(DocumentsContract.EXTRA_ERROR)?.let {
            throw AgentFileFailure("storageFailure", it)
        }
        if (extras.getBoolean(DocumentsContract.EXTRA_LOADING, false)) {
            throw AgentFileFailure("busy", "The document provider is still loading this directory.")
        }
    }

    private fun openDescriptor(
        uri: Uri,
        mode: String,
        cancellation: CancellationSignal,
    ): JSONObject {
        ParcelFileDescriptor.parseMode(mode)
        val resource = describe(uri, cancellation)
        val original = resolver.openFileDescriptor(uri, mode, cancellation)
            ?: throw IOException("The provider returned no file descriptor.")
        var duplicate: ParcelFileDescriptor? = null
        val id = UUID.randomUUID().toString()
        try {
            duplicate = ParcelFileDescriptor.dup(original.fileDescriptor)
            val descriptorFlags = Os.fcntlInt(duplicate.fileDescriptor, OsConstants.F_GETFD, 0)
            Os.fcntlInt(
                duplicate.fileDescriptor,
                OsConstants.F_SETFD,
                descriptorFlags or OsConstants.FD_CLOEXEC,
            )
            val result = JSONObject().put("fdLease", id).put("resource", resource)
            descriptors[id] = FdLease(original)
            val fd = duplicate.detachFd()
            return result.put("fd", fd)
        } catch (error: Exception) {
            descriptors.remove(id)
            try {
                duplicate?.close()
            } catch (cleanup: Exception) {
                error.addSuppressed(cleanup)
            }
            try {
                original.close()
            } catch (cleanup: Exception) {
                error.addSuppressed(cleanup)
            }
            throw error
        }
    }

    private fun closeFd(id: String) {
        val lease = descriptors[id] ?: return
        try {
            lease.lock.withLock {
                if (lease.closed) return@withLock
                var failure: Exception? = null
                try {
                    if (lease.descriptor.canDetectErrors()) lease.descriptor.checkError()
                } catch (error: Exception) {
                    failure = error
                }
                try {
                    lease.descriptor.close()
                } catch (error: Exception) {
                    if (failure == null) failure = error else failure.addSuppressed(error)
                } finally {
                    lease.closed = true
                }
                failure?.let { throw it }
            }
        } finally {
            descriptors.remove(id, lease)
        }
    }

    private fun createDocument(
        parent: Uri,
        name: String,
        mimeType: String,
        cancellation: CancellationSignal,
    ): JSONObject {
        val directory = describe(parent, cancellation)
        if (directory.getString("kind") != "directory") {
            throw AgentFileFailure("invalidArgument", "A new document requires an existing parent directory.")
        }
        cancellation.throwIfCanceled()
        val created = DocumentsContract.createDocument(resolver, parent, mimeType, name)
            ?: throw IOException("The provider did not return the created document URI.")
        // Rust persists this identity before issuing any further provider call.
        return JSONObject().put("uri", created.toString())
    }

    internal fun execute(work: () -> Unit) {
        workers.execute { work() }
    }

    internal fun retainPickerCleanup(
        ownerId: String,
        epoch: Long,
        completion: CompletableFuture<Unit>,
    ): CompletableFuture<Unit> {
        val cleanup = PickerCleanup(epoch, completion)
        retiredPickerCleanups[ownerId] = cleanup
        val closing = CompletableFuture<Unit>()
        completion.whenComplete { _, failure ->
            try {
                execute {
                    try {
                        retryPickerQueries(ownerId)
                        if (failure != null && epoch >= clearedSelectionEpoch.get()) {
                            closing.completeExceptionally(failure)
                        } else {
                            retiredPickerCleanups.remove(ownerId, cleanup)
                            closing.complete(Unit)
                        }
                    } catch (error: Exception) {
                        failure?.let { error.addSuppressed(it) }
                        closing.completeExceptionally(error)
                    }
                }
            } catch (error: Exception) {
                closing.completeExceptionally(error)
            }
        }
        return closing
    }

    // These are the original worker/rollback completions. The caller retries
    // their retained query cursors after this wait, including after a failed close.
    internal fun pendingPickerCleanups(): List<CompletableFuture<Unit>> =
        retiredPickerCleanups.values.map { cleanup ->
            cleanup.completion.handle { _, failure ->
                if (failure != null && cleanup.epoch >= clearedSelectionEpoch.get()) throw failure
                Unit
            }
        }

    internal fun retryPickerQueries(ownerId: String, includeRetired: Boolean = false) {
        val owners = mutableSetOf(ownerId)
        if (includeRetired) {
            owners.addAll(retiredPickerCleanups.filterValues { it.completion.isDone }.keys)
        }
        var failure: Exception? = null
        val pending = pendingPickerCursors.filterValues { it in owners }.keys
        for (id in pending) {
            try {
                closeCursor(id)
            } catch (error: Exception) {
                if (failure == null) failure = error else failure.addSuppressed(error)
            }
        }
        failure?.let { throw CursorCleanupFailure(it) }
        if (pendingPickerCursors.values.any { it in owners }) throw CursorCleanupFailure()
        retiredPickerCleanups.entries.removeIf { entry ->
            val cleanup = entry.value
            entry.key in owners && cleanup.completion.isDone &&
                (!cleanup.completion.isCompletedExceptionally || cleanup.epoch < clearedSelectionEpoch.get())
        }
    }

    internal fun selectionEpoch(): Long = grantStore.epoch()

    internal fun invalidateSelections() = grantStore.invalidateSelections()

    internal fun rememberSelection(
        uri: Uri,
        flags: Int,
        directory: Boolean,
        epoch: Long,
        cancellation: CancellationSignal,
    ): AgentFileGrantStore.Registration {
        val resource = parseResource(uri.toString())
        val metadata = try {
            describe(resource, cancellation)
        } catch (error: OperationCanceledException) {
            throw error
        } catch (error: CursorCleanupFailure) {
            throw error
        } catch (_: Exception) {
            null
        }
        return grantStore.remember(
            uri = uri,
            resource = resource,
            resultFlags = flags,
            name = metadata?.nullableString("name"),
            kind = metadata?.getString("kind") ?: if (directory) "directory" else "other",
            mimeType = metadata?.nullableString("mimeType"),
            expectedEpoch = epoch,
            cancellation = cancellation,
        )
    }

    internal fun rollbackSelection(registration: AgentFileGrantStore.Registration) =
        grantStore.rollback(registration)

    internal fun releaseGrant(id: String) = grantStore.release(id)

    internal fun clearGrants(): Long {
        val clearedBefore = grantStore.clear()
        clearedSelectionEpoch.updateAndGet { previous -> maxOf(previous, clearedBefore) }
        retiredPickerCleanups.entries.removeIf {
            it.value.epoch < clearedBefore && it.value.completion.isDone &&
                !pendingPickerCursors.containsValue(it.key)
        }
        return clearedBefore
    }

    internal fun status(cancellation: CancellationSignal): Map<String, Any?> {
        cancellation.throwIfCanceled()
        val allFiles = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            Environment.isExternalStorageManager()
        val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q && Environment.isExternalStorageLegacy())
        val read = hasPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
        val write = hasPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        val pathRead = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) allFiles else legacy && read
        val pathWrite = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) allFiles else legacy && write
        val snapshot = grantStore.snapshot()
        val resources = snapshot.records.map { record ->
            cancellation.throwIfCanceled()
            val uri = parseResource(record.resourceUri)
            val readPermission = hasUriAccess(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val writePermission = hasUriAccess(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            var error: JSONObject? = null
            val metadata = try {
                describe(uri, cancellation)
            } catch (failure: OperationCanceledException) {
                throw failure
            } catch (failure: CursorCleanupFailure) {
                throw failure
            } catch (failure: Exception) {
                error = errorJson(failure)
                null
            }
            val persisted = AgentFileGrantStore.permissionFlags(snapshot.persisted[record.uri])
            val capabilities = JSONObject()
            for (capability in listOf("read", "list", "create", "modify")) {
                capabilities.put(capability, metadata?.optBoolean(capability, false) ?: false)
            }
            JSONObject()
                .put("grantId", record.id)
                .put("uri", record.uri)
                .put("resource", JSONObject().put("kind", "contentUri").put("value", uri.toString()))
                .put("name", metadata?.nullableString("name") ?: record.name ?: JSONObject.NULL)
                .put("kind", metadata?.getString("kind") ?: record.kind)
                .put("mimeType", metadata?.nullableString("mimeType") ?: record.mimeType ?: JSONObject.NULL)
                .put("read", readPermission)
                .put("write", writePermission)
                .put("persistedRead", persisted and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
                .put("persistedWrite", persisted and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0)
                .put("persisted", persisted != 0)
                .put("ownedRead", record.ownedFlags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
                .put("ownedWrite", record.ownedFlags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0)
                .put("persistable", record.persistable)
                .put("persistenceError", record.persistenceError ?: JSONObject.NULL)
                .put("capabilities", capabilities)
                .put("available", metadata != null)
                .put("error", error ?: JSONObject.NULL)
                .toPlatformMap()
        }
        return linkedMapOf(
            "platform" to "android",
            "sdkInt" to Build.VERSION.SDK_INT,
            "allFilesAccess" to allFiles,
            "legacyStorage" to legacy,
            "readExternalStorage" to read,
            "writeExternalStorage" to write,
            "pathRead" to pathRead,
            "pathWrite" to pathWrite,
            "resources" to resources,
        )
    }

    private fun hasPermission(permission: String): Boolean =
        application.checkPermission(permission, Process.myPid(), Process.myUid()) == PackageManager.PERMISSION_GRANTED

    private fun hasUriAccess(uri: Uri, mode: Int): Boolean {
        if (application.checkUriPermission(uri, Process.myPid(), Process.myUid(), mode) ==
            PackageManager.PERMISSION_GRANTED
        ) return true
        val provider = application.packageManager.resolveContentProvider(uri.authority ?: return false, 0)
            ?: return false
        if (provider.applicationInfo.uid == Process.myUid()) return true
        if (!provider.exported) return false
        val write = mode == Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        val permission = if (write) provider.writePermission else provider.readPermission
        if (permission != null && hasPermission(permission)) return true
        var defaultAccess = permission == null
        for (path in provider.pathPermissions.orEmpty()) {
            val required = if (write) path.writePermission else path.readPermission
            if (required != null && path.match(uri.path ?: "")) {
                if (hasPermission(required)) return true
                defaultAccess = false
            }
        }
        return defaultAccess
    }

    private fun parseResource(value: String): Uri {
        val uri = Uri.parse(value)
        if (uri.scheme != "content" || uri.authority.isNullOrEmpty()) {
            throw AgentFileFailure("invalidArgument", "A ContentResolver resource requires a content URI.")
        }
        return if (DocumentsContract.isTreeUri(uri) && !DocumentsContract.isDocumentUri(application, uri)) {
            DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
        } else {
            uri
        }
    }

    companion object {
        private val DOCUMENT_COLUMNS = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        private val OPENABLE_COLUMNS = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)

        internal fun errorJson(error: Exception): JSONObject {
            val native = generateSequence<Throwable>(error) { it.cause }
                .filterIsInstance<ErrnoException>().firstOrNull()
            val code = when (error) {
                is AgentFileFailure -> error.code
                is CursorCleanupFailure -> "storageFailure"
                is OperationCanceledException -> "cancelled"
                is SecurityException -> "permissionDenied"
                is FileNotFoundException -> "notFound"
                is UnsupportedOperationException -> "unsupported"
                is JSONException, is IllegalArgumentException -> "invalidArgument"
                else -> when (native?.errno) {
                    OsConstants.EACCES, OsConstants.EPERM -> "permissionDenied"
                    OsConstants.ENOENT -> "notFound"
                    OsConstants.EBUSY -> "busy"
                    OsConstants.EEXIST -> "conflict"
                    else -> "storageFailure"
                }
            }
            return JSONObject()
                .put("code", code)
                .put("message", error.message ?: "The Android file operation failed.")
                .put("osCode", (error as? AgentFileFailure)?.osCode ?: native?.errno ?: JSONObject.NULL)
        }
    }
}

private fun JSONObject.requiredString(name: String): String {
    val value = getString(name)
    if (value.isEmpty()) throw AgentFileFailure("invalidArgument", "The $name field must not be empty.")
    return value
}

private fun Cursor.stringOrNull(column: String): String? {
    val index = getColumnIndex(column)
    return if (index < 0 || isNull(index)) null else getString(index)
}

private fun Cursor.longOrNull(column: String): Long? {
    val index = getColumnIndex(column)
    return if (index < 0 || isNull(index)) null else getLong(index)
}

internal fun JSONObject.toPlatformMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
    toPlatformValue(get(key))
}

private fun toPlatformValue(value: Any?): Any? = when (value) {
    null, JSONObject.NULL -> null
    is JSONObject -> value.toPlatformMap()
    is JSONArray -> (0 until value.length()).map { toPlatformValue(value.get(it)) }
    else -> value
}
