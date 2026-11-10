package com.mashiro.sked

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.UriPermission
import android.net.Uri
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.system.Os
import android.system.OsConstants
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong

/** Device-local selections and write-ahead evidence for acquiring URI permissions. */
internal class AgentFileGrantStore(context: Context) {
    data class Record(
        val id: String,
        val uri: String,
        val resourceUri: String,
        val name: String?,
        val kind: String,
        val mimeType: String?,
        val persistable: Boolean,
        val persistenceError: String?,
        val ownedFlags: Int,
        val ownedPersistedTime: Long?,
        val revision: String,
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("uri", uri)
            .put("resourceUri", resourceUri)
            .put("name", name ?: JSONObject.NULL)
            .put("kind", kind)
            .put("mimeType", mimeType ?: JSONObject.NULL)
            .put("persistable", persistable)
            .put("persistenceError", persistenceError ?: JSONObject.NULL)
            .put("ownedFlags", ownedFlags)
            .put("ownedPersistedTime", ownedPersistedTime ?: JSONObject.NULL)
            .put("revision", revision)

        companion object {
            fun fromJson(value: JSONObject): Record = Record(
                id = value.getString("id"),
                uri = value.getString("uri"),
                resourceUri = value.getString("resourceUri"),
                name = value.nullableString("name"),
                kind = value.getString("kind"),
                mimeType = value.nullableString("mimeType"),
                persistable = value.getBoolean("persistable"),
                persistenceError = value.nullableString("persistenceError"),
                ownedFlags = value.getInt("ownedFlags") and READ_WRITE_FLAGS,
                ownedPersistedTime = value.nullableLong("ownedPersistedTime"),
                revision = value.getString("revision"),
            )
        }
    }

    private data class Acquisition(
        val record: Record,
        val additionalFlags: Int,
        val beforePersistedTime: Long?,
        val acquired: Boolean,
    ) {
        val id: String get() = record.revision

        fun toJson(): JSONObject = JSONObject()
            .put("record", record.toJson())
            .put("additionalFlags", additionalFlags)
            .put("beforePersistedTime", beforePersistedTime ?: JSONObject.NULL)
            .put("acquired", acquired)

        companion object {
            fun fromJson(value: JSONObject): Acquisition = Acquisition(
                record = Record.fromJson(value.getJSONObject("record")),
                additionalFlags = value.getInt("additionalFlags") and READ_WRITE_FLAGS,
                beforePersistedTime = value.nullableLong("beforePersistedTime"),
                acquired = value.getBoolean("acquired"),
            )
        }
    }

    data class Snapshot(val records: List<Record>, val persisted: Map<String, UriPermission>)
    data class Registration(val record: Record, val previous: Record?, val addedFlags: Int)

    private val resolver: ContentResolver = context.applicationContext.contentResolver
    private val file = AtomicFile(File(context.noBackupFilesDir, "agent_file_grants.json"))
    private val selectionEpoch = AtomicLong()
    private val lock = Any()
    private var loaded = false
    private var records = linkedMapOf<String, Record>()
    private var acquisitions = linkedMapOf<String, Acquisition>()
    // A failed disk update cannot erase a take that returned in this process.
    private val acquiredHere = linkedMapOf<String, Acquisition>()

    fun epoch(): Long = selectionEpoch.get()
    fun invalidateSelections() {
        selectionEpoch.incrementAndGet()
    }

    fun snapshot(): Snapshot = synchronized(lock) {
        load()
        val persisted = persisted()
        val reconciled = records.mapValues { (_, record) -> reconcile(record, persisted) }
        if (reconciled != records) save(reconciled)
        val pending = acquisitions.values.map { acquisition ->
            val current = try {
                ownedAcquisition(acquisition, persisted)
            } catch (_: AgentFileFailure) {
                acquisition.record.copy(ownedFlags = 0)
            }
            current.copy(persistenceError = "This URI permission acquisition still requires cleanup.")
        }
        Snapshot((records.values + pending).associateBy { it.uri }.values.toList(), persisted)
    }

    fun remember(
        uri: Uri,
        resource: Uri,
        resultFlags: Int,
        name: String?,
        kind: String,
        mimeType: String?,
        expectedEpoch: Long,
        cancellation: CancellationSignal,
    ): Registration = synchronized(lock) {
        load()
        checkSelection(expectedEpoch, cancellation)
        if (acquisitions.values.any { it.record.uri == uri.toString() }) {
            throw AgentFileFailure("busy", "The previous URI selection still requires cleanup.")
        }
        val before = persisted()
        val beforePermission = before[uri.toString()]
        val previous = records.values.firstOrNull { it.uri == uri.toString() }
            ?.let { reconcile(it, before) }
        val requested = resultFlags and READ_WRITE_FLAGS
        val additional = requested and permissionFlags(beforePermission).inv()
        val persistable = resultFlags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0
        val template = Record(
            id = UUID.randomUUID().toString(),
            uri = uri.toString(),
            resourceUri = resource.toString(),
            name = name,
            kind = kind,
            mimeType = mimeType,
            persistable = persistable,
            persistenceError = null,
            ownedFlags = previous?.ownedFlags ?: 0,
            ownedPersistedTime = beforePermission?.persistedTime,
            revision = UUID.randomUUID().toString(),
        )
        var acquisition: Acquisition? = null
        var mayHaveAcquired = false
        var acquired = false
        var publicationStarted = false
        var persistenceError: String? = null
        var restoredPrevious = previous
        try {
            if (persistable && additional != 0) {
                val intent = Acquisition(template, additional, beforePermission?.persistedTime, false)
                acquisition = intent
                // The intent must be durably readable before changing the system grant.
                save(records, LinkedHashMap(acquisitions).apply { put(intent.id, intent) })
                checkSelection(expectedEpoch, cancellation)
                mayHaveAcquired = true
                try {
                    resolver.takePersistableUriPermission(uri, requested)
                    acquired = true
                } catch (error: SecurityException) {
                    mayHaveAcquired = false
                    persistenceError = error.message ?: "The provider did not retain this URI grant."
                } catch (error: UnsupportedOperationException) {
                    mayHaveAcquired = false
                    persistenceError = error.message ?: "The provider does not retain URI grants."
                }
                if (acquired) {
                    val observed = intent.copy(
                        record = template.copy(
                            ownedFlags = template.ownedFlags or additional,
                            ownedPersistedTime = null,
                        ),
                        acquired = true,
                    )
                    acquisition = observed
                    acquiredHere[observed.id] = observed
                    acquisitions[observed.id] = observed
                    restoredPrevious = previous?.copy(ownedPersistedTime = null)
                    save(records)
                } else {
                    save(records, LinkedHashMap(acquisitions).apply { remove(intent.id) })
                    acquisition = null
                }
            }

            val afterPermission = persisted()[uri.toString()]
            val added = if (acquired) permissionFlags(afterPermission) and additional else 0
            val previousOwned = if (acquired ||
                beforePermission?.persistedTime == afterPermission?.persistedTime
            ) previous?.ownedFlags ?: 0 else 0
            val record = template.copy(
                persistenceError = persistenceError,
                ownedFlags = (previousOwned or added) and permissionFlags(afterPermission),
                ownedPersistedTime = afterPermission?.persistedTime,
            )
            acquisition?.let {
                val observed = it.copy(record = record)
                acquisition = observed
                acquiredHere[observed.id] = observed
                acquisitions[observed.id] = observed
                save(records)
                restoredPrevious = previous?.copy(
                    ownedFlags = previousOwned and permissionFlags(afterPermission),
                    ownedPersistedTime = afterPermission?.persistedTime,
                )
            }
            checkSelection(expectedEpoch, cancellation)
            val next = LinkedHashMap(records).apply {
                previous?.let { remove(it.id) }
                put(record.id, record)
            }
            val pending = LinkedHashMap(acquisitions).apply { remove(template.revision) }
            publicationStarted = true
            save(next, pending)
            Registration(record, restoredPrevious, added)
        } catch (error: Exception) {
            val pending = acquisition
            if (pending != null || publicationStarted) {
                if (mayHaveAcquired && !acquired) {
                    throw cleanupFailure(
                        "The system did not confirm whether this URI permission was acquired.",
                        error,
                        unknown = true,
                    )
                }
                try {
                    if (acquired && pending != null) {
                        val owned = ownedAcquisition(pending, persisted())
                        restoredPrevious = restoredPrevious?.let { old ->
                            old.copy(
                                ownedFlags = old.ownedFlags and owned.ownedFlags,
                                ownedPersistedTime = owned.ownedPersistedTime,
                            )
                        }
                        releaseOwned(owned.copy(ownedFlags = owned.ownedFlags and pending.additionalFlags), strict = true)
                    }
                    load()
                    val restored = LinkedHashMap(records).apply { remove(template.id) }
                    restoredPrevious?.let { old ->
                        restored[old.id] = reconcile(old, persisted())
                    }
                    save(restored, LinkedHashMap(acquisitions).apply { pending?.let { remove(it.id) } })
                } catch (cleanup: Exception) {
                    error.addSuppressed(cleanup)
                    throw cleanupFailure(
                        "The URI selection failed and its grant record still requires cleanup.",
                        error,
                    )
                }
            }
            throw error
        }
    }

    /** A retired picker may roll back only the registration that it produced. */
    fun rollback(registration: Registration) = synchronized(lock) {
        load()
        val current = records[registration.record.id] ?: return@synchronized
        if (current.revision != registration.record.revision) return@synchronized
        releaseOwned(current.copy(ownedFlags = current.ownedFlags and registration.addedFlags))
        val next = LinkedHashMap(records).apply { remove(current.id) }
        registration.previous?.let { previous ->
            next[previous.id] = reconcile(previous, persisted())
        }
        save(next)
    }

    fun release(id: String) = synchronized(lock) {
        load()
        val pending = acquisitions.values.firstOrNull { it.record.id == id }
        val record = pending?.let { ownedAcquisition(it, persisted()) }
            ?: records[id] ?: return@synchronized
        releaseOwned(record, strict = pending != null)
        val next = LinkedHashMap(records).apply {
            if (pending == null) remove(id) else entries.removeAll { it.value.uri == record.uri }
        }
        val remaining = LinkedHashMap(acquisitions).apply { pending?.let { remove(it.id) } }
        save(next, remaining)
    }

    fun clear(): Long = synchronized(lock) {
        val clearedBefore = selectionEpoch.incrementAndGet()
        load()
        val next = LinkedHashMap(records)
        val remaining = LinkedHashMap(acquisitions)
        val unresolvedUris = mutableSetOf<String>()
        var failure: Exception? = null
        fun failed(error: Exception) {
            if (failure == null) failure = error else failure!!.addSuppressed(error)
        }
        for (pending in acquisitions.values) {
            try {
                releaseOwned(ownedAcquisition(pending, persisted()), strict = true)
                next.entries.removeAll { it.value.uri == pending.record.uri }
                remaining.remove(pending.id)
            } catch (error: Exception) {
                unresolvedUris.add(pending.record.uri)
                failed(error)
            }
        }
        for (record in next.values.toList()) {
            if (record.uri in unresolvedUris) continue
            try {
                releaseOwned(record)
                next.remove(record.id)
            } catch (error: Exception) {
                failed(error)
            }
        }
        save(next, remaining)
        failure?.let { throw it }
        if (remaining.isNotEmpty()) {
            throw cleanupFailure("A URI permission acquisition remains unresolved.", unknown = true)
        }
        clearedBefore
    }

    private fun ownedAcquisition(
        acquisition: Acquisition,
        permissions: Map<String, UriPermission>,
    ): Record {
        val record = acquisition.record
        val permission = permissions[record.uri]
        val held = permissionFlags(permission)
        val possible = record.ownedFlags or acquisition.additionalFlags
        val actual = possible and held
        if (actual == 0) return record.copy(ownedFlags = 0, ownedPersistedTime = permission?.persistedTime)
        val acquiredInProcess = acquiredHere[acquisition.id]
        val recordedAcquisition = acquisition.acquired &&
            record.ownedPersistedTime != null &&
            permission?.persistedTime == record.ownedPersistedTime
        val unchangedBefore = !acquisition.acquired &&
            held and acquisition.additionalFlags == 0 &&
            permission?.persistedTime == acquisition.beforePersistedTime
        if (acquiredInProcess != null || recordedAcquisition || unchangedBefore) {
            if (acquisition.acquired && record.ownedPersistedTime != null &&
                permission?.persistedTime != record.ownedPersistedTime
            ) {
                throw cleanupFailure("The pending URI grant was replaced before cleanup.", unknown = true)
            }
            return record.copy(ownedFlags = actual, ownedPersistedTime = permission?.persistedTime)
        }
        throw cleanupFailure(
            "A previous URI permission acquisition was interrupted before its ownership was recorded.",
            unknown = true,
        )
    }

    private fun checkSelection(expectedEpoch: Long, cancellation: CancellationSignal) {
        cancellation.throwIfCanceled()
        if (selectionEpoch.get() != expectedEpoch) throw OperationCanceledException()
    }

    private fun persisted(): Map<String, UriPermission> =
        resolver.persistedUriPermissions.associateBy { it.uri.toString() }

    private fun reconcile(record: Record, permissions: Map<String, UriPermission>): Record {
        val permission = permissions[record.uri]
        val flags = if (permission?.persistedTime == record.ownedPersistedTime) {
            record.ownedFlags and permissionFlags(permission)
        } else {
            0
        }
        return record.copy(ownedFlags = flags, ownedPersistedTime = permission?.persistedTime)
    }

    private fun releaseOwned(record: Record, strict: Boolean = false) {
        val permissions = persisted()
        val current = reconcile(record, permissions)
        val stillPresent = record.ownedFlags and permissionFlags(permissions[record.uri])
        if (strict && current.ownedFlags != stillPresent) {
            throw cleanupFailure("The pending URI grant changed before release.", unknown = true)
        }
        if (current.ownedFlags == 0) return
        val uri = Uri.parse(current.uri)
        try {
            resolver.releasePersistableUriPermission(uri, current.ownedFlags)
        } catch (error: SecurityException) {
            if (permissionFlags(persisted()[current.uri]) and current.ownedFlags != 0) throw error
        }
        if (permissionFlags(persisted()[current.uri]) and current.ownedFlags != 0) {
            throw AgentFileFailure("storageFailure", "The URI grant remains persisted after release.")
        }
    }

    private fun load() {
        if (loaded) return
        val source = try {
            file.openRead()
        } catch (error: FileNotFoundException) {
            if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) throw error
            records = linkedMapOf()
            acquisitions = LinkedHashMap(acquiredHere)
            loaded = true
            return
        }
        try {
            val root = source.bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()) }
            if (root.getInt("format") != 1) {
                throw AgentFileFailure("unsupported", "The URI grant record format is not supported.")
            }
            val restored = linkedMapOf<String, Record>()
            val values = root.getJSONArray("records")
            for (index in 0 until values.length()) {
                val record = Record.fromJson(values.getJSONObject(index))
                if (restored.put(record.id, record) != null) {
                    throw IOException("The URI grant records repeat an identity.")
                }
            }
            val pending = linkedMapOf<String, Acquisition>()
            val intents = root.optJSONArray("acquisitions") ?: JSONArray()
            for (index in 0 until intents.length()) {
                val acquisition = Acquisition.fromJson(intents.getJSONObject(index))
                if (pending.put(acquisition.id, acquisition) != null) {
                    throw IOException("The URI grant acquisitions repeat an identity.")
                }
            }
            pending.putAll(acquiredHere)
            records = restored
            acquisitions = pending
            loaded = true
        } catch (error: AgentFileFailure) {
            throw error
        } catch (error: Exception) {
            throw AgentFileFailure("storageFailure", "The URI grant records could not be read.", cause = error)
        }
    }

    private fun save(
        next: Map<String, Record>,
        pending: Map<String, Acquisition> = acquisitions,
    ) {
        val values = JSONArray()
        next.values.forEach { values.put(it.toJson()) }
        val intents = JSONArray()
        pending.values.forEach { intents.put(it.toJson()) }
        val bytes = JSONObject().put("format", 1).put("records", values).put("acquisitions", intents)
            .toString().toByteArray(Charsets.UTF_8)
        var stream: FileOutputStream? = null
        var finished = false
        try {
            val output = file.startWrite()
            stream = output
            output.write(bytes)
            output.fd.sync()
            file.finishWrite(output)
            finished = true
            if (!file.openRead().use { it.readBytes() }.contentEquals(bytes)) {
                throw IOException("The URI grant records did not match after saving.")
            }
            syncGrantDirectory()
        } catch (error: Exception) {
            loaded = false
            if (!finished && stream != null) {
                try {
                    file.failWrite(stream)
                } catch (cleanup: Exception) {
                    error.addSuppressed(cleanup)
                }
            }
            throw error
        }
        records = LinkedHashMap(next)
        acquisitions = LinkedHashMap(pending)
        acquiredHere.keys.retainAll(pending.keys)
    }

    private fun syncGrantDirectory() {
        val directory = file.baseFile.parentFile ?: throw IOException("The URI grant directory is missing.")
        val descriptor = Os.open(
            directory.absolutePath,
            OsConstants.O_RDONLY or OsConstants.O_CLOEXEC or OsConstants.O_NOFOLLOW,
            0,
        )
        try {
            if (!OsConstants.S_ISDIR(Os.fstat(descriptor).st_mode)) {
                throw IOException("The URI grant parent is not a directory.")
            }
            Os.fsync(descriptor)
        } finally {
            Os.close(descriptor)
        }
    }

    private fun cleanupFailure(
        message: String,
        cause: Throwable? = null,
        unknown: Boolean = false,
    ): AgentFileFailure = AgentFileFailure(
        if (unknown) "outcomeUnknown" else "storageFailure",
        message,
        cause = cause,
        cleanupIncomplete = true,
    )

    companion object {
        const val READ_WRITE_FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION

        fun permissionFlags(permission: UriPermission?): Int {
            if (permission == null) return 0
            return (if (permission.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                (if (permission.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        }
    }
}

internal fun JSONObject.nullableString(name: String): String? =
    if (!has(name) || isNull(name)) null else getString(name)

private fun JSONObject.nullableLong(name: String): Long? =
    if (!has(name) || isNull(name)) null else getLong(name)
