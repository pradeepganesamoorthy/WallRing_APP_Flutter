package com.example.wallpaper_ringtone_app

import android.content.ContentValues
import android.content.Context
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

                    "setRingtone" -> {
                        val path  = call.argument<String>("path")
                        val type  = call.argument<String>("type")
                        val title = call.argument<String>("title") ?: "Ringtone"

                        if (path == null || type == null) {
                            result.error("INVALID_ARGS", "path and type are required", null)
                            return@setMethodCallHandler
                        }

                        // Android 6+ needs WRITE_SETTINGS for ringtone changes
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.System.canWrite(this)) {
                                result.error(
                                    "PERMISSION_DENIED",
                                    "Modify System Settings permission not granted.\n\n" +
                                    "Go to: Settings → Apps → WallRing → Modify System Settings → Turn ON",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        try {
                            val success = setRingtoneFixed(this, path, title, type)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("SET_FAILED", e.message, null)
                        }
                    }

                    "checkWriteSettings" -> {
                        val canWrite = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.System.canWrite(this)
                        } else {
                            true
                        }
                        result.success(canWrite)
                    }

                    "openWriteSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = android.content.Intent(
                                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                                android.net.Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * ✅ FIXED: The "mutation of data is not allowed" error happens because
     * Android 10+ does not let you register an arbitrary external file path
     * directly in MediaStore. The fix is:
     * 1. Copy the selected audio file into the app's own Ringtones folder
     * 2. Register THAT copy in MediaStore
     * 3. Set it as the ringtone
     */
    private fun setRingtoneFixed(
        context: Context,
        sourcePath: String,
        title: String,
        type: String
    ): Boolean {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return false

        val ringtoneType = when (type) {
            "ringtone"     -> RingtoneManager.TYPE_RINGTONE
            "notification" -> RingtoneManager.TYPE_NOTIFICATION
            "alarm"        -> RingtoneManager.TYPE_ALARM
            else           -> RingtoneManager.TYPE_RINGTONE
        }

        // ── Step 1: Copy file to the correct system Ringtones/Notifications dir ──
        val destDir = when (type) {
            "notification" -> File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_NOTIFICATIONS),
                ""
            )
            "alarm" -> File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_ALARMS),
                ""
            )
            else -> File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RINGTONES),
                ""
            )
        }

        if (!destDir.exists()) destDir.mkdirs()

        // Use sanitised title as filename
        val safeName = title.replace(Regex("[^a-zA-Z0-9._\\- ]"), "_") + ".mp3"
        val destFile = File(destDir, safeName)

        // Copy bytes
        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }

        // ── Step 2: Register copy in MediaStore ───────────────────────────────────
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DATA,         destFile.absolutePath)
            put(MediaStore.MediaColumns.TITLE,        title)
            put(MediaStore.MediaColumns.MIME_TYPE,    getMimeType(destFile.name))
            put(MediaStore.MediaColumns.SIZE,         destFile.length())
            put(MediaStore.Audio.Media.IS_RINGTONE,   type == "ringtone")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, type == "notification")
            put(MediaStore.Audio.Media.IS_ALARM,      type == "alarm")
            put(MediaStore.Audio.Media.IS_MUSIC,      false)
        }

        // Remove any previous entry for this file to avoid duplicates
        context.contentResolver.delete(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            "${MediaStore.MediaColumns.DATA} = ?",
            arrayOf(destFile.absolutePath)
        )

        val uri: Uri = context.contentResolver.insert(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            values
        ) ?: return false

        // ── Step 3: Set as system ringtone ────────────────────────────────────────
        RingtoneManager.setActualDefaultRingtoneUri(context, ringtoneType, uri)
        return true
    }

    private fun getMimeType(filename: String): String {
        return when {
            filename.endsWith(".mp3",  ignoreCase = true) -> "audio/mpeg"
            filename.endsWith(".m4a",  ignoreCase = true) -> "audio/mp4"
            filename.endsWith(".ogg",  ignoreCase = true) -> "audio/ogg"
            filename.endsWith(".wav",  ignoreCase = true) -> "audio/wav"
            filename.endsWith(".flac", ignoreCase = true) -> "audio/flac"
            filename.endsWith(".aac",  ignoreCase = true) -> "audio/aac"
            else -> "audio/mpeg"
        }
    }
}
