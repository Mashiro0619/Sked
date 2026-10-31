package com.mashiro.sked

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/** Returns only after both streams close; false means copying observed cancellation. */
internal fun copyExportStream(
    byteLength: Long,
    openInput: () -> InputStream,
    openOutput: () -> OutputStream?,
    isCancelled: () -> Boolean,
): Boolean {
    require(byteLength >= 0)
    if (isCancelled()) return false
    openInput().use { input ->
        if (isCancelled()) return false
        val target = openOutput() ?: throw IOException("Unable to open the export destination.")
        target.use { output ->
            val buffer = ByteArray(64 * 1024)
            var copied = 0L
            while (true) {
                if (isCancelled()) return false
                val count = input.read(buffer)
                if (count < 0) break
                if (count == 0) continue
                if (isCancelled()) return false
                if (count.toLong() > byteLength - copied) {
                    throw IOException("The prepared export changed while saving.")
                }
                output.write(buffer, 0, count)
                copied += count
            }
            if (copied != byteLength) throw IOException("The prepared export is incomplete.")
            if (isCancelled()) return false
            output.flush()
        }
    }
    // Cancellation arriving after a successful close cannot undo that save.
    return true
}
