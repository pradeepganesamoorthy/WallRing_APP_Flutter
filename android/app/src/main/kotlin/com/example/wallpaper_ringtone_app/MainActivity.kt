package com.example.wallpaper_ringtone_app

import android.content.ContentValues
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.wallpaper_ringtone_app/ringtone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRingtone" -> {
                        val path = call.argument<String>("path")
                        val type = call.argument<String>("type")
                        val title = call.argument<String>("title") ?: "Ringtone"

                        if (path == null || type == null) {
                            result.error("INVALID_ARGS", "path and type are required", null)
                            return@setMethodCallHandler
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.System.canWrite(this)) {
                                result.error(
                                    "PERMISSION_DENIED",
                                    "Modify System Settings permission not granted. Go to Settings > Apps > WallRing > Modify System Settings and enable it.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        val success = setRingtone(this, path, title, type)
                        result.success(success)
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

    private fun setRingtone(context: Context, filePath: String, title: String, type: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val ringtoneType = when (type) {
                "ringtone" -> RingtoneManager.TYPE_RINGTONE
                "notification" -> RingtoneManager.TYPE_NOTIFICATION
                else -> RingtoneManager.TYPE_RINGTONE
            }

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DATA, filePath)
                put(MediaStore.MediaColumns.TITLE, title)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                put(MediaStore.MediaColumns.SIZE, file.length())
                put(MediaStore.Audio.Media.IS_RINGTONE, type == "ringtone")
                put(MediaStore.Audio.Media.IS_NOTIFICATION, type == "notification")
                put(MediaStore.Audio.Media.IS_MUSIC, false)
            }

            val contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            context.contentResolver.delete(contentUri, "${MediaStore.MediaColumns.DATA}=?", arrayOf(filePath))
            val uri = context.contentResolver.insert(contentUri, values) ?: return false
            RingtoneManager.setActualDefaultRingtoneUri(context, ringtoneType, uri)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
