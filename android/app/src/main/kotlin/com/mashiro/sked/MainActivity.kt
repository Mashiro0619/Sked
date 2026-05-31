package com.mashiro.sked

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContent: String? = null
    private var pendingSaveFileName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXPORT_FILE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveTextFile" -> saveTextFile(
                    fileName = call.argument<String>("fileName"),
                    content = call.argument<String>("content"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun saveTextFile(
        fileName: String?,
        content: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }
        if (fileName.isNullOrBlank() || content == null) {
            result.error("invalidArguments", "Missing fileName or content.", null)
            return
        }

        pendingSaveResult = result
        pendingSaveContent = content
        pendingSaveFileName = fileName

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType?.takeIf { it.isNotBlank() } ?: "text/plain"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            startActivityForResult(intent, SAVE_TEXT_FILE_REQUEST_CODE)
        } catch (_: ActivityNotFoundException) {
            clearPendingSave()
            result.error("unsupported", "No document provider is available.", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_TEXT_FILE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingSaveResult ?: return
        val content = pendingSaveContent
        val fileName = pendingSaveFileName
        clearPendingSave()

        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || content == null) {
            result.success(null)
            return
        }

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: run {
                result.error("failed", "Unable to open output stream.", null)
                return
            }
            result.success(fileName)
        } catch (_: SecurityException) {
            result.error("permissionDenied", "Permission denied while saving file.", null)
        } catch (_: IOException) {
            result.error("failed", "Failed to save file.", null)
        }
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveContent = null
        pendingSaveFileName = null
    }

    private companion object {
        const val EXPORT_FILE_CHANNEL = "com.mashiro.sked/export_file"
        const val SAVE_TEXT_FILE_REQUEST_CODE = 1001
    }
}
