package com.mashiro.sked

import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.UUID

/** Owns only files allocated for this export session, never a caller-supplied path. */
internal class BinaryExportStaging(cacheDirectory: File) {
    private val cache = cacheDirectory.canonicalFile
    private var pending: Prepared? = null

    val isPending: Boolean
        get() = pending != null

    internal class Prepared internal constructor(
        val id: String,
        val fileName: String,
        val mimeType: String,
        val byteLength: Long,
        private val directory: File,
        private val file: File,
    ) {
        val path: String
            get() = file.absolutePath

        fun verify() {
            // Both the directory and file must still be the regular private
            // objects allocated here. A cache entry replaced by a symlink must
            // not turn the document exporter into a reader of another file.
            if (directory.canonicalFile != directory ||
                file.canonicalFile != file || !file.isFile || file.length() != byteLength
            ) {
                throw IOException("The prepared export is unavailable or incomplete.")
            }
        }

        fun openInput(): InputStream {
            verify()
            return file.inputStream()
        }

        internal fun discard() {
            if (directory.canonicalFile != directory) {
                // Delete only the substituted link, never a file below its
                // destination. The native API does not accept either path.
                if (!directory.delete() && directory.exists()) {
                    throw IOException("Unable to remove the prepared export.")
                }
                return
            }
            if (!file.delete() && file.exists()) {
                throw IOException("Unable to remove the prepared export.")
            }
            // No recursive deletion: an unexpected child is not owned by us.
            if (!directory.delete() && directory.exists()) {
                throw IOException("Unable to remove the export directory.")
            }
        }
    }

    fun prepare(fileName: String, mimeType: String, byteLength: Long): Prepared? {
        if (isPending) return null
        require(fileName.isNotBlank() && mimeType.isNotBlank() && byteLength >= 0)
        if (!cache.isDirectory) throw IOException("The application cache is unavailable.")
        val id = UUID.randomUUID().toString()
        val directory = File(cache, "sked-export-$id")
        if (!directory.mkdir()) throw IOException("Unable to prepare an export directory.")
        val file = File(directory, "payload")
        try {
            if (!file.createNewFile()) throw IOException("Unable to prepare an export file.")
        } catch (error: Exception) {
            directory.delete()
            throw error
        }
        return Prepared(id, fileName, mimeType, byteLength, directory, file).also {
            pending = it
        }
    }

    fun find(id: String?): Prepared? = pending?.takeIf { it.id == id }

    fun discard(id: String?) {
        val prepared = find(id) ?: return
        prepared.discard()
        pending = null
    }

    fun discardCurrent() {
        discard(pending?.id)
    }
}
