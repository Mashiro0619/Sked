package com.mashiro.sked

import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeNoException
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BinaryExportStagingTest {
    @get:Rule val temporary = TemporaryFolder()
    private val cache by lazy { temporary.newFolder("cache") }
    private val bytes = byteArrayOf(0x50, 0x4b, 0, 0xff.toByte(), 0x80.toByte(), 13, 10)

    @Test
    fun allocatesOnlyPrivateCacheFilesAndRejectsAnotherPreparation() {
        val staging = BinaryExportStaging(cache)
        val prepared = staging.prepare("备份.zip", "application/zip", bytes.size.toLong())!!

        assertTrue(staging.isPending)
        assertSame(prepared, staging.find(prepared.id))
        assertEquals("备份.zip", prepared.fileName)
        assertEquals("application/zip", prepared.mimeType)
        assertTrue(prepared.path.startsWith(cache.canonicalPath + File.separator))
        assertFalse(prepared.path.contains(prepared.fileName))
        assertNull(staging.prepare("another.zip", "application/zip", 0))
        assertEquals(1, cache.listFiles()!!.size)

        File(prepared.path).writeBytes(bytes)
        prepared.openInput().use { assertArrayEquals(bytes, it.readBytes()) }
        staging.discard(prepared.id)
        assertFalse(staging.isPending)
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    @Test
    fun pathsAndUnknownTokensCannotSelectOrDeleteAnySource() {
        val staging = BinaryExportStaging(cache)
        val outside = temporary.newFile("private-data.json").apply { writeText("untouched") }
        val prepared = staging.prepare("backup.zip", "application/zip", 0)!!

        for (value in listOf(outside.absolutePath, prepared.path, "../private-data.json", "unknown", null)) {
            assertNull(staging.find(value))
            staging.discard(value)
            assertSame(prepared, staging.find(prepared.id))
            assertTrue(File(prepared.path).exists())
            assertEquals("untouched", outside.readText())
        }
        staging.discardCurrent()
        assertTrue(cache.listFiles()!!.isEmpty())
        assertEquals("untouched", outside.readText())
    }

    @Test
    fun retiredTokenCannotReleaseItsReplacement() {
        val staging = BinaryExportStaging(cache)
        val old = staging.prepare("old.zip", "application/zip", 0)!!
        staging.discard(old.id)
        val replacement = staging.prepare("new.zip", "application/zip", 0)!!

        assertNotEquals(old.id, replacement.id)
        assertNotEquals(old.path, replacement.path)
        staging.discard(old.id)
        assertNull(staging.find(old.id))
        assertSame(replacement, staging.find(replacement.id))
        assertTrue(File(replacement.path).isFile)
        staging.discard(replacement.id)
    }

    @Test
    fun incompleteEvictedAndOversizedFilesCannotBeRead() {
        val staging = BinaryExportStaging(cache)
        val prepared = staging.prepare("backup.zip", "application/zip", bytes.size.toLong())!!
        val file = File(prepared.path)

        assertThrows(IOException::class.java) { prepared.verify() }
        file.writeBytes(bytes + 1.toByte())
        assertThrows(IOException::class.java) { prepared.openInput() }
        file.writeBytes(bytes)
        prepared.verify()
        file.delete()
        assertThrows(IOException::class.java) { prepared.openInput() }
        staging.discard(prepared.id)
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    @Test
    fun zeroBytePreparationIsARealReadableFile() {
        val staging = BinaryExportStaging(cache)
        val prepared = staging.prepare("empty.zip", "application/zip", 0)!!

        prepared.verify()
        prepared.openInput().use { assertEquals(-1, it.read()) }
        staging.discard(prepared.id)
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    @Test
    fun replacedFileLinkIsRejectedAndOnlyThatLinkIsRemoved() {
        val staging = BinaryExportStaging(cache)
        val outside = temporary.newFile("outside-source").apply { writeBytes(bytes) }
        val prepared = staging.prepare("backup.zip", "application/zip", bytes.size.toLong())!!
        val source = File(prepared.path)
        assertTrue(source.delete())
        createLink(source, outside)

        assertThrows(IOException::class.java) { prepared.openInput() }
        staging.discard(prepared.id)
        assertArrayEquals(bytes, outside.readBytes())
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    @Test
    fun replacedDirectoryLinkNeverDeletesItsDestinationPayload() {
        val staging = BinaryExportStaging(cache)
        val outside = temporary.newFolder("outside-directory")
        val protected = File(outside, "payload").apply { writeBytes(bytes) }
        val prepared = staging.prepare("backup.zip", "application/zip", bytes.size.toLong())!!
        val source = File(prepared.path)
        val directory = source.parentFile!!
        assertTrue(source.delete())
        assertTrue(directory.delete())
        createLink(directory, outside)

        assertThrows(IOException::class.java) { prepared.openInput() }
        staging.discard(prepared.id)
        assertArrayEquals(bytes, protected.readBytes())
        assertTrue(outside.isDirectory)
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    @Test
    fun cleanupFailureDoesNotRecursivelyRemoveUnexpectedChildren() {
        val staging = BinaryExportStaging(cache)
        val prepared = staging.prepare("backup.zip", "application/zip", 0)!!
        val unexpected = File(File(prepared.path).parentFile, "unrelated").apply { writeText("keep") }

        assertThrows(IOException::class.java) { staging.discard(prepared.id) }
        assertTrue(staging.isPending)
        assertEquals("keep", unexpected.readText())
        assertFalse(File(prepared.path).exists())

        assertTrue(unexpected.delete())
        staging.discard(prepared.id)
        assertFalse(staging.isPending)
        assertTrue(cache.listFiles()!!.isEmpty())
    }

    private fun createLink(link: File, target: File) {
        try {
            Files.createSymbolicLink(link.toPath(), target.toPath())
        } catch (error: IOException) {
            assumeNoException("The host does not permit symbolic links.", error)
        } catch (error: UnsupportedOperationException) {
            assumeNoException("The host does not support symbolic links.", error)
        } catch (error: SecurityException) {
            assumeNoException("The host does not permit symbolic links.", error)
        }
    }
}
