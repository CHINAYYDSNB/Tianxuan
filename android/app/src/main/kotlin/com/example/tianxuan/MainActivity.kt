package com.example.tianxuan

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingLink: String? = null
    private var linkStreamHandler: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Capture initial intent (deep link that launched the app)
        intent?.data?.toString()?.let { pendingLink = it }

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Method channel: getInitialLink (consumed once)
        MethodChannel(messenger, "com.tianxuan.app/deeplink")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        val link = pendingLink
                        pendingLink = null // consume once
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel: stream incoming deep links (onNewIntent)
        EventChannel(messenger, "com.tianxuan.app/deeplink/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    linkStreamHandler = events
                }

                override fun onCancel(arguments: Any?) {
                    linkStreamHandler = null
                }
            })

        // Method channel: save file to public Downloads/tianxuan/ (visible in file manager)
        MethodChannel(messenger, "com.tianxuan.app/downloads")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val name = call.argument<String>("name")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (name == null || bytes == null) {
                        result.error("BAD_ARGS", "name/bytes required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val path = saveToPublicDownloads(name, bytes)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** 写入公共 Downloads/tianxuan/ 目录，供系统文件管理器直接可见。 */
    private fun saveToPublicDownloads(name: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ : MediaStore (scoped storage)
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/tianxuan")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values)
                ?: throw Exception("无法创建下载条目")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("无法写入下载目录")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        } else {
            // Android 9 及以下: 直接写外部存储 Downloads/tianxuan/
            val dir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val target = java.io.File(dir, "tianxuan")
            if (!target.exists()) target.mkdirs()
            val file = java.io.File(target, name)
            file.writeBytes(bytes)
            return file.absolutePath
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val data = intent.data?.toString()
        if (data != null) {
            pendingLink = data
            linkStreamHandler?.success(data)
        }
    }
}
