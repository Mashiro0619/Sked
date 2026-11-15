package com.mashiro.sked

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.Locale

class AgentOpenedFileProvider : FileProvider()

/** Builds file intents on the channel worker and launches viewers on the UI thread. */
class AgentFileActions(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false

    fun close() {
        closed = true
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") {
            result.notImplemented()
            return
        }
        val intent = try {
            check(!closed) { "The file action belongs to a closed application view." }
            prepare(call)
        } catch (error: Exception) {
            failure(result, error)
            return
        }
        main.post {
            if (closed || activity.isFinishing || activity.isDestroyed) {
                result.error("unavailable", "The application view has closed.", null)
                return@post
            }
            try {
                activity.startActivity(intent)
            } catch (error: Exception) {
                failure(result, error)
                return@post
            }
            result.success(null)
        }
    }

    private fun prepare(call: MethodCall): Intent {
        val location = requireNotNull(call.argument<String>("value")) { "Missing file location." }
        val name = requireNotNull(call.argument<String>("name")) { "Missing file name." }
        val uri = when (call.argument<String>("kind")) {
            "contentUri" -> Uri.parse(location).also {
                require(it.scheme == "content" && !it.authority.isNullOrBlank()) {
                    "The document location must be a content URI."
                }
            }
            "androidPath" -> {
                val file = File(location)
                require(file.isAbsolute) { "The file path must be absolute." }
                if (!file.isFile) throw FileNotFoundException("The file to open is unavailable.")
                FileProvider.getUriForFile(activity, "${activity.packageName}.agent_open_files", file)
            }
            else -> throw IllegalArgumentException("Unsupported file resource kind.")
        }
        val mimeType = call.argument<String>("mediaType")
            ?.substringBefore(';')?.trim()?.takeIf { it.isNotEmpty() }
            ?: activity.contentResolver.getType(uri)
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(
                name.substringAfterLast('.', "").lowercase(Locale.ROOT),
            )
            ?: "application/octet-stream"
        return Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            clipData = ClipData.newRawUri(name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun failure(result: MethodChannel.Result, error: Exception) {
        val code = when (error) {
            is ActivityNotFoundException -> "noApplication"
            is SecurityException -> "permissionDenied"
            is FileNotFoundException -> "notFound"
            is IllegalArgumentException -> "invalidArgument"
            is IllegalStateException -> "unavailable"
            else -> "openFailed"
        }
        val message = if (error is ActivityNotFoundException) {
            "No application is available to open this file type."
        } else error.message ?: "The file could not be opened."
        result.error(code, message, null)
    }

    companion object {
        const val CHANNEL = "com.mashiro.sked/agent_file_actions"
    }
}
