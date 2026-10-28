package com.mashiro.sked

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files

/** File policy shared by the Android host and JVM failure-path regressions. */
internal class DeviceTransferStore(
    filesDirectory: File,
    privateDirectory: File,
    private val publish: (File, File) -> Unit = ::publishWithoutReplacement,
    private val filter: (File, File) -> Unit = ::filterSnapshot,
) {
    private val root = filesDirectory.canonicalFile
    private val privateRoot = privateDirectory.canonicalFile
    val artifact: File get() = File(root, ARTIFACT_PATH)
    private var receivedThisSession = false

    /** Always clear our old output, even when this transport cannot receive data. */
    fun send(deviceTransfer: Boolean, emit: (File) -> Unit) {
        clearArtifact()
        if (!deviceTransfer) return
        val source = File(root, DATA_NAME)
        if (!source.exists()) return
        requireRegularFile(source)
        val directory = artifact.parentFile!!
        requireDirectory(directory)
        val staging = File.createTempFile("outgoing-", ".tmp", directory)
        try {
            filter(source, staging)
            publish(staging, artifact)
            emit(artifact)
        } finally {
            Files.deleteIfExists(staging.toPath())
            clearArtifact()
        }
    }

    /** Called before the framework writes the only allowed incoming file. */
    fun beforeRestoreFile(destination: File): Boolean {
        if (!isArtifact(destination)) return false
        receivedThisSession = false
        clearArtifact()
        return true
    }

    /** The framework may drain a rejected or truncated file without throwing. */
    fun afterRestoreFile(size: Long, regularFile: Boolean) {
        receivedThisSession = regularFile && size >= 0 &&
            artifact.isFile && artifact.length() == size
        if (!receivedThisSession) clearArtifact()
    }

    fun finishRestore(): Boolean {
        try {
            if (!receivedThisSession || hasExistingStorage()) return false
            requireRegularFile(artifact)
            requireDirectory(privateRoot)
            val staging = File.createTempFile("Sked-device-restore-", ".tmp", privateRoot)
            try {
                filter(artifact, staging)
                // Check again after potentially slow input parsing. Publishing
                // below never replaces a file created by another participant.
                if (hasExistingStorage()) return false
                val temporary = File(root, "$DATA_NAME.tmp")
                publish(staging, temporary)
                // From this point the complete .tmp belongs to normal storage
                // recovery. Leave it intact if main publication fails.
                publish(temporary, File(root, DATA_NAME))
                Files.deleteIfExists(temporary.toPath())
                return true
            } finally {
                Files.deleteIfExists(staging.toPath())
            }
        } finally {
            receivedThisSession = false
            clearArtifact()
        }
    }

    private fun hasExistingStorage(): Boolean {
        val entries = root.listFiles() ?: throw IOException("Cannot inspect destination storage.")
        // Covers main, backup, temporary, failed secret scrub, journals, site
        // data, instance leases and every named recovery directory, including
        // future artifacts which follow AppStorageLayout's Sked_ namespace.
        return entries.any { it.name.startsWith("Sked_") && it.name != ARTIFACT_DIRECTORY }
    }

    private fun isArtifact(file: File): Boolean =
        file.absoluteFile == artifact.absoluteFile && file.canonicalFile == artifact.absoluteFile

    private fun clearArtifact() {
        if (!isArtifact(artifact)) throw IOException("Unsafe device transfer artifact path.")
        Files.deleteIfExists(artifact.toPath())
    }

    companion object {
        const val DATA_NAME = "Sked_data.json"
        const val ARTIFACT_DIRECTORY = "Sked_device_transfer"
        const val ARTIFACT_PATH = "$ARTIFACT_DIRECTORY/$DATA_NAME"

        private fun requireRegularFile(file: File) {
            if (!file.isFile || file.canonicalFile != file.absoluteFile) {
                throw IOException("Device transfer input is not a regular private file.")
            }
        }

        private fun requireDirectory(directory: File) {
            if ((!directory.isDirectory && !directory.mkdirs()) ||
                directory.canonicalFile != directory.absoluteFile
            ) {
                throw IOException("Device transfer directory is unavailable.")
            }
        }

        private fun filterSnapshot(source: File, target: File) {
            FileInputStream(source).use { input ->
                FileOutputStream(target).use { output ->
                    DeviceTransferSanitizer.copy(input, output)
                    output.fd.sync()
                }
            }
        }

        private fun publishWithoutReplacement(source: File, target: File) {
            // Both directories are in the same private app filesystem. A hard
            // link atomically exposes the completed, fsynced inode and fails if
            // the target already exists; no partial .tmp can become recoverable.
            Files.createLink(target.toPath(), source.toPath())
        }
    }
}
