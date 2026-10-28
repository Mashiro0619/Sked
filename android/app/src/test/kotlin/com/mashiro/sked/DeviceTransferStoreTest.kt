package com.mashiro.sked

import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class DeviceTransferStoreTest {
    @get:Rule val temporary = TemporaryFolder()
    private val source = """{"aiApiSettings":{"customApiKey":"LEGACY_KEY","customModel":"model"},"ordinary":[1,true,"课程"]}"""
    private val sanitized = """{"aiApiSettings":{"customModel":"model"},"ordinary":[1,true,"课程"]}"""
    private val files by lazy { temporary.newFolder("files") }
    private val privateFiles by lazy { temporary.newFolder("no_backup") }
    private val main get() = File(files, DeviceTransferStore.DATA_NAME)
    private val candidate get() = File(files, "${DeviceTransferStore.DATA_NAME}.tmp")

    private fun store() = DeviceTransferStore(files, privateFiles)

    private fun receive(store: DeviceTransferStore, contents: String = source) {
        assertTrue(store.beforeRestoreFile(store.artifact))
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText(contents)
        store.afterRestoreFile(store.artifact.length(), true)
    }

    private fun assertNoPrivateStaging() = assertTrue(privateFiles.listFiles()!!.isEmpty())

    @Test
    fun deviceTransferEmitsOnlyIndependentSanitizedMainAndPreservesSource() {
        main.writeText(source)
        File(files, "${DeviceTransferStore.DATA_NAME}.bak").writeText("old backup")
        val store = store()
        var emitted = 0
        store.send(true) {
            emitted++
            assertEquals(store.artifact, it)
            assertEquals(sanitized, it.readText())
            assertEquals(source, main.readText())
        }
        assertEquals(1, emitted)
        assertEquals(source, main.readText())
        assertEquals("old backup", File(files, "${DeviceTransferStore.DATA_NAME}.bak").readText())
        assertFalse(store.artifact.exists())
        assertTrue(store.artifact.parentFile!!.listFiles()!!.isEmpty())
    }

    @Test
    fun cloudAndOtherTransportsRemoveStaleArtifactWithoutReadingSource() {
        val store = store()
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText("stale")
        main.writeText("corrupt original")
        store.send(false) { throw AssertionError("Cloud transport emitted a file") }
        assertFalse(store.artifact.exists())
        assertEquals("corrupt original", main.readText())
    }

    @Test
    fun missingMainDoesNotFallBackToAnUnfilteredBackup() {
        File(files, "${DeviceTransferStore.DATA_NAME}.bak").writeText(source)
        store().send(true) { throw AssertionError("Backup unexpectedly transferred") }
        assertFalse(main.exists())
    }

    @Test
    fun invalidMainClearsStaleAndPartialOutgoingArtifacts() {
        val store = store()
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText("stale")
        main.writeText("{\"ordinary\":[1,")
        assertThrows(Exception::class.java) {
            store.send(true) { throw AssertionError("Partial artifact emitted") }
        }
        assertEquals("{\"ordinary\":[1,", main.readText())
        assertTrue(store.artifact.parentFile!!.listFiles()!!.isEmpty())
    }

    @Test
    fun transferEmissionFailureCleansArtifactAndPreservesMain() {
        main.writeText(source)
        val store = store()
        assertThrows(IOException::class.java) { store.send(true) { throw IOException("emit") } }
        assertEquals(source, main.readText())
        assertTrue(store.artifact.parentFile!!.listFiles()!!.isEmpty())
    }

    @Test
    fun freshRestoreRefiltersTheReceivedFileAndPublishesNormalMain() {
        val store = store()
        receive(store)
        assertTrue(store.finishRestore())
        assertEquals(sanitized, main.readText())
        assertFalse(candidate.exists())
        assertFalse(store.artifact.exists())
        assertNoPrivateStaging()
    }

    @Test
    fun everyExistingStorageOrRecoveryArtifactPreventsReplacement() {
        for (name in listOf(
            "Sked_data.json", "Sked_data.json.tmp", "Sked_data.json.bak",
            "Sked_data.json.tmp.failed", "Sked_data.json.secret-scrub.rollback",
            "Sked_data.json.secret-scrub.tmp", "Sked_school_sites.json",
            "Sked_backup_restore_journal.json", "Sked_backup_restore_journal.json.tmp",
            "Sked_recovery_123", "Sked_school_sites_recovery_123",
            "Sked_backup_restore_recovery_123", "Sked_instance.lock",
        )) {
            val existing = File(files, name)
            existing.writeText("existing evidence")
            val store = store()
            receive(store)
            assertFalse(name, store.finishRestore())
            assertEquals(name, "existing evidence", existing.readText())
            if (existing != main) assertFalse(main.exists())
            if (existing != candidate) assertFalse(candidate.exists())
            Files.delete(existing.toPath())
        }
    }

    @Test
    fun anExistingRecoveryDirectoryAlsoPreventsRestore() {
        File(files, "Sked_recovery_123").mkdirs()
        val store = store()
        receive(store)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
    }

    @Test
    fun staleArtifactsAndRepeatedFinishNeverCreateASecondRestore() {
        val store = store()
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText(source)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
        receive(store)
        assertTrue(store.finishRestore())
        Files.delete(main.toPath())
        store.artifact.writeText(source)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
    }

    @Test
    fun truncatedReceiptAndRejectedFrameworkRestoreCannotBeAdopted() {
        val store = store()
        store.beforeRestoreFile(store.artifact)
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText(source)
        store.afterRestoreFile(store.artifact.length() + 1, true)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
        store.beforeRestoreFile(store.artifact)
        store.afterRestoreFile(30, true)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
    }

    @Test
    fun nonFileAndUnrelatedReceiptsAreNotAdopted() {
        val store = store()
        assertFalse(store.beforeRestoreFile(File(files, "unrelated.json")))
        assertFalse(store.finishRestore())
        store.beforeRestoreFile(store.artifact)
        store.artifact.parentFile!!.mkdirs()
        store.artifact.writeText(source)
        store.afterRestoreFile(store.artifact.length(), false)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
    }

    @Test
    fun aLaterTruncatedReceiptInvalidatesAnEarlierValidOne() {
        val store = store()
        receive(store)
        assertTrue(store.beforeRestoreFile(store.artifact))
        store.afterRestoreFile(30, true)
        assertFalse(store.finishRestore())
        assertFalse(main.exists())
    }

    @Test
    fun malformedReceivedJsonLeavesNoMainOrRecoverablePartialTemporary() {
        val store = store()
        receive(store, "{\"ordinary\":[1,")
        assertThrows(Exception::class.java) { store.finishRestore() }
        assertFalse(main.exists())
        assertFalse(candidate.exists())
        assertFalse(store.artifact.exists())
        assertNoPrivateStaging()
    }

    @Test
    fun partialPrivateWriteFailureLeavesNoRecoverableCandidate() {
        val store = DeviceTransferStore(files, privateFiles, filter = { _, target ->
            target.writeText("{\"partial\":")
            throw IOException("write interrupted")
        })
        receive(store)
        assertThrows(IOException::class.java) { store.finishRestore() }
        assertFalse(main.exists())
        assertFalse(candidate.exists())
        assertNoPrivateStaging()
    }

    @Test
    fun firstPublicationFailureRemovesPrivateStaging() {
        val store = DeviceTransferStore(files, privateFiles, publish = { _, _ ->
            throw IOException("cannot publish")
        })
        receive(store)
        assertThrows(IOException::class.java) { store.finishRestore() }
        assertFalse(main.exists())
        assertFalse(candidate.exists())
        assertNoPrivateStaging()
    }

    @Test
    fun failedMainPromotionKeepsTheCompleteNormalRecoveryCandidate() {
        val store = DeviceTransferStore(files, privateFiles, publish = { source, target ->
            if (target == main) throw IOException("main promotion interrupted")
            Files.createLink(target.toPath(), source.toPath())
        })
        receive(store)
        assertThrows(IOException::class.java) { store.finishRestore() }
        assertFalse(main.exists())
        assertEquals(sanitized, candidate.readText())
        assertFalse(store.artifact.exists())
        assertNoPrivateStaging()
    }

    @Test
    fun concurrentMainCreationIsNotReplacedDuringPromotion() {
        val store = DeviceTransferStore(files, privateFiles, publish = { source, target ->
            if (target == main) main.writeText("concurrent data")
            Files.createLink(target.toPath(), source.toPath())
        })
        receive(store)
        assertThrows(IOException::class.java) { store.finishRestore() }
        assertEquals("concurrent data", main.readText())
        assertEquals(sanitized, candidate.readText())
        assertNoPrivateStaging()
    }
}
