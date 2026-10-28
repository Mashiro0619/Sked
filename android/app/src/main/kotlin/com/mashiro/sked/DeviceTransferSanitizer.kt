package com.mashiro.sked

import com.google.gson.Strictness
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import com.google.gson.stream.JsonWriter
import java.io.IOException
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.nio.charset.CodingErrorAction
import java.util.ArrayDeque

/** Copies a complete storage object, dropping only managed legacy API-key fields. */
internal object DeviceTransferSanitizer {
    private enum class Scope { ROOT, STUDENT, SETTINGS, OTHER }
    private data class Frame(val objectValue: Boolean, val scope: Scope)

    fun copy(input: InputStream, output: OutputStream) {
        val decoder = Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val encoder = Charsets.UTF_8.newEncoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val reader = JsonReader(InputStreamReader(input, decoder)).apply {
            strictness = Strictness.STRICT
            // Traversal is iterative: unknown ordinary fields do not consume
            // the JVM call stack or inherit Gson's binding-layer depth limit.
            nestingLimit = Int.MAX_VALUE
        }
        val writer = JsonWriter(OutputStreamWriter(output, encoder)).apply {
            strictness = Strictness.STRICT
        }
        if (reader.peek() != JsonToken.BEGIN_OBJECT) {
            throw IOException("Device transfer requires a storage JSON object.")
        }
        reader.beginObject()
        writer.beginObject()
        val frames = ArrayDeque<Frame>()
        frames.addLast(Frame(true, Scope.ROOT))
        while (frames.isNotEmpty()) {
            val frame = frames.getLast()
            if (!reader.hasNext()) {
                if (frame.objectValue) {
                    reader.endObject()
                    writer.endObject()
                } else {
                    reader.endArray()
                    writer.endArray()
                }
                frames.removeLast()
                continue
            }
            var childScope = Scope.OTHER
            if (frame.objectValue) {
                val name = reader.nextName()
                if (frame.scope == Scope.SETTINGS && name == "customApiKey") {
                    // nextName decodes escapes; skip each occurrence, including
                    // duplicate keys and non-string values in corrupt snapshots.
                    reader.skipValue()
                    continue
                }
                childScope = when {
                    frame.scope == Scope.ROOT && name == "studentMode" -> Scope.STUDENT
                    frame.scope == Scope.ROOT && name == "aiApiSettings" -> Scope.SETTINGS
                    (frame.scope == Scope.ROOT || frame.scope == Scope.STUDENT) &&
                        name == "schoolImportParserSettings" -> Scope.SETTINGS
                    else -> Scope.OTHER
                }
                if (childScope != Scope.OTHER && reader.peek() != JsonToken.BEGIN_OBJECT) {
                    throw IOException("Device transfer contains an invalid settings container.")
                }
                writer.name(name)
            }
            when (reader.peek()) {
                JsonToken.BEGIN_OBJECT -> {
                    reader.beginObject()
                    writer.beginObject()
                    frames.addLast(Frame(true, childScope))
                }
                JsonToken.BEGIN_ARRAY -> {
                    reader.beginArray()
                    writer.beginArray()
                    frames.addLast(Frame(false, Scope.OTHER))
                }
                JsonToken.STRING -> writer.value(reader.nextString())
                // Do not round large IDs, decimals, or scientific notation by
                // converting through Double or Long.
                JsonToken.NUMBER -> writer.jsonValue(reader.nextString())
                JsonToken.BOOLEAN -> writer.value(reader.nextBoolean())
                JsonToken.NULL -> {
                    reader.nextNull()
                    writer.nullValue()
                }
                else -> throw IOException("Device transfer contains an invalid JSON value.")
            }
        }
        if (reader.peek() != JsonToken.END_DOCUMENT) {
            throw IOException("Device transfer contains trailing data.")
        }
        writer.flush()
    }
}
