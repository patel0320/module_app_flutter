package com.soleux.sdm

// Android foreground service that keeps the app process - and with it the
// Dart-side persistent module sockets and UDP heartbeat monitor - alive
// continuously, even when the app is backgrounded, the task is swiped away or
// the screen is off.
//
// The Dart isolate holds every module's persistent Control API / legacy AT TCP
// session (see ModuleStatusService) and the UDP heartbeat monitor (see
// ModuleHeartbeatService). Those cannot survive on their own once the OS
// suspends the app. This service counteracts that by:
//
//   - running as a specialUse foreground service (NOT dataSync, which is
//     capped at 6 h/day on Android 15+), so the process is not a candidate for
//     clean-up while the persistent notification is posted;
//   - holding a PARTIAL_WAKE_LOCK so the CPU (and the Dart socket event loop)
//     keeps running while the screen is off;
//   - returning START_STICKY from onStartCommand so the OS restarts the
//     service (and the process) if it is killed;
//   - re-arming itself from onTaskRemoved so swiping the app away from Recents
//     does not stop live monitoring;
//   - implementing onTimeout() as a mandatory safety net (Android 15+), even
//     though a specialUse service is not subject to a time budget.
//
// The service itself performs no protocol work; it only keeps the process
// alive so the existing Dart monitoring layers run uninterrupted. The Flutter
// engine keeps its socket event loop ticking while the process is alive and
// the CPU is awake, which is what "maintains the persistent socket connection"
// in Flutter.
import android.annotation.SuppressLint
import android.app.ActivityManager
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

class ModuleKeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val moduleCount = intent?.getIntExtra(EXTRA_MODULE_COUNT, 0) ?: 0
                val title = intent?.getStringExtra(EXTRA_TITLE)
                val text = intent?.getStringExtra(EXTRA_TEXT)
                startAsForeground(moduleCount, title, text)
                return START_STICKY
            }
        }
    }

    private fun startAsForeground(moduleCount: Int, title: String?, text: String?) {
        val notification = buildNotification(moduleCount, title, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(
        moduleCount: Int,
        title: String?,
        text: String?,
    ): Notification {
        val contentTitle = title ?: getString(R.string.keep_alive_title)
        val contentText = text
            ?: if (moduleCount > 0) {
                resources.getString(R.string.keep_alive_body_count, moduleCount)
            } else {
                getString(R.string.keep_alive_body)
            }

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Pre-API 26 there are no notification channels; the priority governs
        // how prominently the persistent notification is shown.
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        return builder
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.keep_alive_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.keep_alive_channel_description)
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    // PARTIAL_WAKE_LOCK keeps the CPU running (and with it the Dart socket /
    // heartbeat event loop) while the screen is off; doze would otherwise put
    // the app's process to sleep regardless of the foreground notification.
    @SuppressLint("WakelockTimeout")
    private fun acquireWakeLock() {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = power.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Soleux::SocketKeepAlive",
        )
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        if (lock.isHeld) {
            lock.release()
        }
        wakeLock = null
    }

    // Android 15+ (API 35) calls this when a foreground service exceeds its
    // allowed time budget. A specialUse service has no budget, so this is a
    // defensive safety net: stop cleanly instead of leaking a foreground state.
    override fun onTimeout() {
        super.onTimeout()
        stopForegroundCompat()
        stopSelf()
    }

    // stopForeground(true) on API < 24, stopForeground(STOP_FOREGROUND_REMOVE)
    // on API >= 24, so the persistent notification disappears when the service
    // is stopped on every supported Android version.
    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    // The user swiped the app away from Recents. The foreground service keeps
    // the process alive by itself, but re-arm explicitly so monitoring survives
    // even if the system had scheduled the service for a restart.
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            val restart = Intent(this, ModuleKeepAliveService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restart)
            } else {
                startService(restart)
            }
        } catch (_: Exception) {
            // Restart refused by the OS (background FGS start restriction); the
            // already-running foreground service keeps the process up.
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "com.soleux.sdm.action.KEEP_ALIVE_START"
        const val ACTION_STOP = "com.soleux.sdm.action.KEEP_ALIVE_STOP"
        const val EXTRA_MODULE_COUNT = "moduleCount"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        const val CHANNEL_ID = "module_keep_alive"
        const val NOTIFICATION_ID = 0x4B41 // "KA"

        @SuppressLint("MissingPermission")
        fun isRunning(context: Context): Boolean {
            val manager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            for (service in manager.getRunningServices(Int.MAX_VALUE)) {
                if (service.service.className == ModuleKeepAliveService::class.java.name) {
                    return true
                }
            }
            return false
        }
    }
}