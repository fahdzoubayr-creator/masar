package com.masar.masar_app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val channelName = "masar/room_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val intent = Intent(this, RoomForegroundService::class.java).apply {
                                action = RoomForegroundService.ACTION_START
                                putExtra(
                                    RoomForegroundService.EXTRA_TITLE,
                                    call.argument<String>("title") ?: "",
                                )
                            }
                            // نبدأ الخدمة فقط والمستخدم داخل التطبيق فعلياً
                            // (من شاشة القاعة) — متوافق مع قيود Android 12+.
                            startForegroundService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("fgs_start_failed", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            val intent = Intent(this, RoomForegroundService::class.java).apply {
                                action = RoomForegroundService.ACTION_STOP
                            }
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("fgs_stop_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
