package com.example.wallpaper_ringtone_app

import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.wallpaper_ringtone_app/ringtone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canWriteSettings" -> {
                        result.success(Settings.System.canWrite(this))
                    }

                    "openWriteSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_SETTINGS_FAILED", e.message, null)
                        }
                    }

                    "setRingtone" -> {
                        try {
                            if (!Settings.System.canWrite(this)) {
                                result.error(
                                    "NO_PERMISSION",
                                    "Modify system settings permission not granted",
                                    null
                                )
                                return@setMethodCallHandler
                            }

                            val path = call.argument<String>("path")
                            val type = call.argument<String>("type") ?: "ringtone"
                            val title = call.argument<String>("title") ?: "WallRing Tone"

                            if (path.isNullOrEmpty()) {
                                result.error("INVALID_PATH", "Audio path is null or empty", null)
                                return@setMethodCallHandler
                            }

                            val success = setSystemTone(path, type, title)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("SET_TONE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun setSystemTone(path: String, type: String, title: String): Boolean {
        val sourceFile = File(path)
        if (!sourceFile.exists()) return false

        val tonesDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RINGTONES),
            "WallRing"
        )
        if (!tonesDir.exists()) {
            tonesDir.mkdirs()
        }

        val extension = sourceFile.extension.ifEmpty { "mp3" }
        val safeTitle = title.replace(Regex("[^A-Za-z0-9._ -]"), "_")
        val destFile = File(tonesDir, "$safeTitle.$extension")

        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }

        val values = android.content.ContentValues().apply {
            put(MediaStore.MediaColumns.DATA, destFile.absolutePath)
            put(MediaStore.MediaColumns.TITLE, title)
            put(MediaStore.MediaColumns.MIME_TYPE, "audio/*")
            put(MediaStore.Audio.Media.IS_RINGTONE, type == "ringtone")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, type == "notification")
            put(MediaStore.Audio.Media.IS_ALARM, false)
            put(MediaStore.Audio.Media.IS_MUSIC, false)
        }

        val uri = MediaStore.Audio.Media.getContentUriForPath(destFile.absolutePath)
        contentResolver.delete(uri!!, MediaStore.MediaColumns.DATA + "=?", arrayOf(destFile.absolutePath))
        val newUri = contentResolver.insert(uri, values) ?: return false

        when (type) {
            "notification" -> {
                RingtoneManager.setActualDefaultRingtoneUri(
                    this,
                    RingtoneManager.TYPE_NOTIFICATION,
                    newUri
                )
            }

            else -> {
                RingtoneManager.setActualDefaultRingtoneUri(
                    this,
                    RingtoneManager.TYPE_RINGTONE,
                    newUri
                )
            }
        }

        return true
    }
}