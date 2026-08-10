package com.lyrical.lyricalvideo.lyrical_video

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.lyrical.lyricalvideo/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveVideoToGallery") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val success = saveVideoToMediaStore(filePath)
                    result.success(success)
                } else {
                    result.error("INVALID_PATH", "File path was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveVideoToMediaStore(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, "LyricalVideo_${System.currentTimeMillis()}.mp4")
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/LyricalVideoMaker")
                }
            }

            val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { outputStream ->
                    FileInputStream(file).use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
