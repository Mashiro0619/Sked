package com.mashiro.sked

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class DeviceTransferSanitizerTest {
    private fun sanitize(source: String): String = sanitize(source.toByteArray(Charsets.UTF_8))

    private fun sanitize(source: ByteArray): String {
        val output = ByteArrayOutputStream()
        DeviceTransferSanitizer.copy(ByteArrayInputStream(source), output)
        return output.toString("UTF-8")
    }

    @Test
    fun sharedAppDataFixtureMatchesTheSnapshotReadByDartStorage() {
        val resources = javaClass.classLoader!!
        val input = resources.getResourceAsStream("device_transfer/legacy.json")!!.use { it.readBytes() }
        val expected = resources.getResourceAsStream("device_transfer/sanitized.json")!!
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        assertEquals(expected, sanitize(input))
    }

    @Test
    fun stripsEveryManagedPathIncludingEscapedNamesAndDuplicates() {
        val source = """{
          "aiApiSettings":{"customApiKey":"KEY_A","customApiKey":{"nested":"KEY_B"},"model":"model"},
          "aiApiSettings":{"custom\u0041piKey":["KEY_C"]},
          "schoolImportParserSettings":{"customApiKey":"KEY_D","customPrompt":"prompt"},
          "student\u004dode":{"schoolImportParserSettings":{"customApiKey":"KEY_E"},"timetables":[]}
        }"""
        val result = sanitize(source)
        assertFalse(result.contains("KEY_"))
        assertFalse(result.contains("customApiKey"))
        assertEquals(
            """{"aiApiSettings":{"model":"model"},"aiApiSettings":{},"schoolImportParserSettings":{"customPrompt":"prompt"},"studentMode":{"schoolImportParserSettings":{},"timetables":[]}}""",
            result,
        )
    }

    @Test
    fun ordinaryValuesAndNumericLexemesArePreserved() {
        val source = """{"text":"中文🌸\nquote\"","id":9007199254740993,"decimal":1.234567890123456789,"exponent":1e+99,"negativeZero":-0,"array":[true,false,null,{},[]],"metadata":{"customApiKey":"ordinary user content"},"studentMode":{"ordinary":{"schoolImportParserSettings":{"customApiKey":"content"}}}}"""
        assertEquals(source, sanitize(source))
    }

    @Test
    fun deeplyNestedOrdinaryContentUsesIterativeTraversal() {
        val source = "{\"ordinary\":" + "[".repeat(3000) + "0" + "]".repeat(3000) + "}"
        assertEquals(source, sanitize(source))
    }

    @Test
    fun malformedOrIncompleteJsonCannotProduceAnAcceptedArtifact() {
        val inputs = listOf(
            "", "[]", "null", "{", "{} {}", "{} trailing", "{\"a\":NaN}",
            "{'a':1}", "{\"a\":01}", "{\"a\":1,}", "{\"a\":/*comment*/1}",
            "{\"a\":\"raw\nnewline\"}", "{\"aiApiSettings\":{\"customApiKey\":\"bad\\x\"}}",
            "{\"aiApiSettings\":[]}", "{\"studentMode\":null}",
            "{\"schoolImportParserSettings\":\"key\"}",
            "{\"studentMode\":{\"schoolImportParserSettings\":[{\"customApiKey\":\"key\"}]}}",
        )
        for (source in inputs) {
            assertThrows(source, Exception::class.java) { sanitize(source) }
        }
    }

    @Test
    fun malformedUtf8IsRejectedInsteadOfChangingUserContent() {
        assertThrows(Exception::class.java) {
            sanitize(byteArrayOf(123, 34, 120, 34, 58, 34, 0xc3.toByte(), 34, 125))
        }
    }

    @Test
    fun unmatchedEscapedSurrogateIsRejectedInsteadOfSilentlyReplacingIt() {
        assertThrows(Exception::class.java) { sanitize("{\"x\":\"\\ud800\"}") }
    }
}
