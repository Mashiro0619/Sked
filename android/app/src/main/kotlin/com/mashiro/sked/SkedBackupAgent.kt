package com.mashiro.sked

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.app.backup.FullBackupDataOutput
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.EOFException
import java.io.File
import java.io.FileInputStream

/** Only the explicitly filtered Android 12+ device-transfer artifact is emitted. */
class SkedBackupAgent : BackupAgent() {
    private val transfer by lazy { DeviceTransferStore(filesDir, noBackupFilesDir) }

    override fun onFullBackup(data: FullBackupDataOutput) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        transfer.send(
            data.transportFlags and FLAG_DEVICE_TO_DEVICE_TRANSFER != 0,
        ) { artifact -> fullBackupFile(artifact, data) }
    }

    override fun onRestoreFile(
        data: ParcelFileDescriptor,
        size: Long,
        destination: File,
        type: Int,
        mode: Long,
        mtime: Long,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            super.onRestoreFile(data, size, destination, type, mode, mtime)
            return
        }
        val artifact = transfer.beforeRestoreFile(destination)
        if (!artifact || type != TYPE_FILE || size < 0) {
            // Includes can also match descendants when a path is represented
            // as a directory in an archive. Enforce the exact file here too.
            // The framework owns this descriptor; do not close it.
            val input = FileInputStream(data.fileDescriptor)
            val buffer = ByteArray(8192)
            var remaining = size
            while (remaining > 0) {
                val read = input.read(buffer, 0, minOf(remaining, buffer.size.toLong()).toInt())
                if (read < 0) throw EOFException("Incomplete discarded restore entry.")
                remaining -= read
            }
            return
        }
        // The framework additionally enforces cloud exclusions and D2D includes
        // and consumes rejected files. Do not call its blanket onFullBackup.
        super.onRestoreFile(data, size, destination, type, mode, mtime)
        transfer.afterRestoreFile(size, true)
    }

    override fun onRestoreFinished() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) transfer.finishRestore()
    }

    // fullBackupOnly prevents key/value selection; these required abstract
    // callbacks still deliberately emit and accept no key/value application data.
    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput,
        newState: ParcelFileDescriptor,
    ) = Unit

    override fun onRestore(
        data: BackupDataInput,
        appVersionCode: Int,
        newState: ParcelFileDescriptor?,
    ) {
        while (data.readNextHeader()) data.skipEntityData()
    }
}
