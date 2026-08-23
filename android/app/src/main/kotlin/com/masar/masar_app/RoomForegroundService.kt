package com.masar.masar_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * خدمة الواجهة الأمامية لجلسة القاعة (صوت/صورة).
 *
 * تُبقي الميكروفون والكاميرا يعملان عند إغلاق الشاشة أو تنقّل المستخدم
 * داخل التطبيق، وتُعرض إشعاراً دائماً يوضح أن الجلسة جارية.
 * تُشغَّل عبر قناة "masar/room_service" من Dart عند الاتصال بالقاعة
 * وتُوقف عند المغادرة.
 */
class RoomForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "masar_room_channel"
        const val NOTIFICATION_ID = 4711
        const val ACTION_START = "com.masar.masar_app.room.START"
        const val ACTION_STOP = "com.masar.masar_app.room.STOP"
        const val EXTRA_TITLE = "title"

        /** سقف أمان للـ WakeLock: 4 ساعات كحد أقصى للجلسة الواحدة. */
        private const val WAKELOCK_TIMEOUT_MS = 4L * 60 * 60 * 1000
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                releaseWakeLock()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }
            else -> startInForeground(
                intent?.getStringExtra(EXTRA_TITLE).orEmpty().ifEmpty { "جلسة القاعة الصوتية" }
            )
        }
        return START_STICKY
    }

    private fun startInForeground(title: String) {
        acquireWakeLock()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "القاعات الصوتية",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "تحافظ على استمرار صوت الجلسة عند إغلاق الشاشة"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification: Notification =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
                    .setContentTitle("جلسة جارية")
                    .setContentText(title)
                    .setSmallIcon(R.drawable.ic_room_mic)
                    .setOngoing(true)
                    .setContentIntent(contentIntent)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setContentTitle("جلسة جارية")
                    .setContentText(title)
                    .setSmallIcon(R.drawable.ic_room_mic)
                    .setOngoing(true)
                    .setContentIntent(contentIntent)
                    .build()
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "masar:room_session").also {
            it.setReferenceCounted(false)
            it.acquire(WAKELOCK_TIMEOUT_MS)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }
}
