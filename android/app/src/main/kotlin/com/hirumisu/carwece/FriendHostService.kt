package com.hirumisu.carwece

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Keeps the active phone host awake; stopping the app still ends the room. */
class FriendHostService : Service() {
    private var wake: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("friend_room", "Sala entre amigos", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "friend_room") else Notification.Builder(this))
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("CarWece • sala entre amigos")
            .setContentText("Você está hospedando. Volte ao jogo para encerrar a sala.")
            .setContentIntent(open).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(140, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        else startForeground(140, notification)
        if (wake == null) {
            wake = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CarWece:FriendRoom")
                .apply { setReferenceCounted(false); acquire(6 * 60 * 60 * 1000L) }
        }
        return START_NOT_STICKY
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf(); super.onTaskRemoved(rootIntent) }
    override fun onDestroy() { wake?.let { if (it.isHeld) it.release() }; wake = null; super.onDestroy() }
}
