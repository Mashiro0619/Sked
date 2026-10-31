package com.mashiro.sked

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ExportStreamCopyTest {
    private class Input(bytes: ByteArray) : ByteArrayInputStream(bytes) {
        var closed = false
        var maximumRead = 0
        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            maximumRead = maxOf(maximumRead, length)
            return super.read(buffer, offset, length)
        }
        override fun close() {
            closed = true
            super.close()
        }
    }

    private class Output : ByteArrayOutputStream() {
        var closed = false
        var flushes = 0
        var writeFailure = false
        var closeFailure = false
        var afterWrite: (() -> Unit)? = null
        var afterClose: (() -> Unit)? = null
        override fun write(buffer: ByteArray, offset: Int, length: Int) {
            if (writeFailure) throw IOException("write failed")
            super.write(buffer, offset, length)
            afterWrite?.invoke()
        }
        override fun flush() {
            flushes++
            super.flush()
        }
        override fun close() {
            closed = true
            super.close()
            if (closeFailure) throw IOException("close failed")
            afterClose?.invoke()
        }
    }

    @Test
    fun streamsExactBinaryBytesWithBoundedReadsAndClosesBeforeSuccess() {
        val bytes = ByteArray(200_003) { (it % 256).toByte() }
        val input = Input(bytes)
        val output = Output()

        assertTrue(copyExportStream(bytes.size.toLong(), { input }, { output }, { false }))
        assertArrayEquals(bytes, output.toByteArray())
        assertTrue(input.maximumRead <= 64 * 1024)
        assertTrue(input.closed)
        assertTrue(output.closed)
        assertEquals(1, output.flushes)
    }

    @Test
    fun zeroByteFileStillOpensFlushesAndClosesItsDestination() {
        val input = Input(byteArrayOf())
        val output = Output()

        assertTrue(copyExportStream(0, { input }, { output }, { false }))
        assertEquals(0, output.size())
        assertEquals(1, output.flushes)
        assertTrue(input.closed)
        assertTrue(output.closed)
    }

    @Test
    fun cancellationBeforeCopyDoesNotOpenEitherStream() {
        assertFalse(copyExportStream(
            1,
            { throw AssertionError("input opened after cancellation") },
            { throw AssertionError("output opened after cancellation") },
            { true },
        ))
    }

    @Test
    fun cancellationAfterOpeningSourceStillAvoidsOpeningDestination() {
        val input = Input(byteArrayOf(1))
        var cancelled = false

        assertFalse(copyExportStream(
            1,
            { cancelled = true; input },
            { throw AssertionError("output opened after cancellation") },
            { cancelled },
        ))
        assertTrue(input.closed)
    }

    @Test
    fun cancellationBetweenChunksStopsWritesAndClosesBothStreams() {
        val input = Input(ByteArray(200_003) { 0x42 })
        val output = Output()
        var cancelled = false
        output.afterWrite = { cancelled = true }

        assertFalse(copyExportStream(200_003, { input }, { output }, { cancelled }))
        assertEquals(64 * 1024, output.size())
        assertEquals(0, output.flushes)
        assertTrue(input.closed)
        assertTrue(output.closed)
    }

    @Test
    fun cancellationAfterSuccessfulCloseDoesNotRewriteActualSaveAsCancelled() {
        val input = Input(byteArrayOf(1, 2, 3))
        val output = Output()
        var cancelled = false
        output.afterClose = { cancelled = true }

        assertTrue(copyExportStream(3, { input }, { output }, { cancelled }))
        assertTrue(cancelled)
        assertArrayEquals(byteArrayOf(1, 2, 3), output.toByteArray())
    }

    @Test
    fun outputWriteFailureClosesBothStreamsAndPropagatesFailure() {
        val input = Input(byteArrayOf(1, 2, 3))
        val output = Output().apply { writeFailure = true }

        assertThrows(IOException::class.java) {
            copyExportStream(3, { input }, { output }, { false })
        }
        assertTrue(input.closed)
        assertTrue(output.closed)
    }

    @Test
    fun outputCloseFailureIsNotReportedAsSaved() {
        val input = Input(byteArrayOf(1, 2, 3))
        val output = Output().apply { closeFailure = true }

        assertThrows(IOException::class.java) {
            copyExportStream(3, { input }, { output }, { false })
        }
        assertTrue(input.closed)
        assertTrue(output.closed)
    }

    @Test
    fun missingDestinationOrRevokedPermissionClosesTheSource() {
        val missingInput = Input(byteArrayOf(1))
        assertThrows(IOException::class.java) {
            copyExportStream(1, { missingInput }, { null }, { false })
        }
        assertTrue(missingInput.closed)

        val deniedInput = Input(byteArrayOf(1))
        assertThrows(SecurityException::class.java) {
            copyExportStream(1, { deniedInput }, { throw SecurityException("denied") }, { false })
        }
        assertTrue(deniedInput.closed)
    }

    @Test
    fun sourceLengthChangesCannotProduceASuccessfulExport() {
        for (expected in listOf(2L, 4L)) {
            val input = Input(byteArrayOf(1, 2, 3))
            val output = Output()
            assertThrows(IOException::class.java) {
                copyExportStream(expected, { input }, { output }, { false })
            }
            assertTrue(input.closed)
            assertTrue(output.closed)
            assertEquals(0, output.flushes)
        }
    }
}
