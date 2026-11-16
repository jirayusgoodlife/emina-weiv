package com.animeview.anime_view

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
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class DownloadForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "anime_view_downloads_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "ACTION_START"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val ACTION_STOP = "ACTION_STOP"

        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val EXTRA_MESSAGE = "EXTRA_MESSAGE"
        const val EXTRA_PROGRESS = "EXTRA_PROGRESS"
        const val EXTRA_MAX = "EXTRA_MAX"
        const val EXTRA_COMPLETED_SUMMARY = "EXTRA_COMPLETED_SUMMARY"

        fun start(context: Context, title: String, message: String, progress: Int = 0, max: Int = 100) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_MESSAGE, message)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_MAX, max)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Fallback for restrictions on certain devices
            }
        }

        fun update(context: Context, title: String, message: String, progress: Int, max: Int = 100) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_MESSAGE, message)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_MAX, max)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Fallback
            }
        }

        fun stop(context: Context, completedSummary: String? = null) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_COMPLETED_SUMMARY, completedSummary)
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                // Fallback
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var notificationManager: NotificationManager? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "anime_view:download_wakelock").apply {
                setReferenceCounted(false)
                acquire(120 * 60 * 1000L) // 2 hours safety timeout
            }
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        when (action) {
            ACTION_STOP -> {
                val summary = intent?.getStringExtra(EXTRA_COMPLETED_SUMMARY)
                handleStop(summary)
            }
            ACTION_UPDATE -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "กำลังดาวน์โหลดอนิเมะ"
                val message = intent?.getStringExtra(EXTRA_MESSAGE) ?: "กำลังดาวน์โหลด..."
                val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0
                val max = intent?.getIntExtra(EXTRA_MAX, 100) ?: 100
                updateNotification(title, message, progress, max)
            }
            ACTION_START -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "กำลังดาวน์โหลดอนิเมะ"
                val message = intent?.getStringExtra(EXTRA_MESSAGE) ?: "เริ่มการดาวน์โหลด..."
                val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0
                val max = intent?.getIntExtra(EXTRA_MAX, 100) ?: 100
                startForegroundWithNotification(title, message, progress, max)
            }
        }
        return START_STICKY
    }

    private fun startForegroundWithNotification(title: String, message: String, progress: Int, max: Int) {
        val notification = buildNotification(title, message, progress, max, isOngoing = true)
        val foregroundServiceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, foregroundServiceType)
        } catch (e: Exception) {
            // In case dataSync permission was delayed, retry with standard startForeground
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (_: Exception) {}
        }
    }

    private fun updateNotification(title: String, message: String, progress: Int, max: Int) {
        val notification = buildNotification(title, message, progress, max, isOngoing = true)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun handleStop(completedSummary: String?) {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}

        if (completedSummary != null && completedSummary.isNotEmpty()) {
            val completedNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("ดาวน์โหลดเสร็จสิ้น")
                .setContentText(completedSummary)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setOngoing(false)
                .setAutoCancel(true)
                .setContentIntent(createPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
            notificationManager?.notify(NOTIFICATION_ID, completedNotification)
        } else {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        }
        stopSelf()
    }

    private fun buildNotification(
        title: String,
        message: String,
        progress: Int,
        max: Int,
        isOngoing: Boolean
    ): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(isOngoing)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(createPendingIntent())

        if (max > 0) {
            val isIndeterminate = progress <= 0
            builder.setProgress(max, progress, isIndeterminate)
        }

        return builder.build()
    }

    private fun createPendingIntent(): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(this, 0, launchIntent, flags)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "การดาวน์โหลดอนิเมะ",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "แสดงความคืบหน้าการดาวน์โหลดอนิเมะในพื้นหลัง"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
