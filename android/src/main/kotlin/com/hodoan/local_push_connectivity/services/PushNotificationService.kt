package com.hodoan.local_push_connectivity.services

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationCompat.PRIORITY_MAX
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.hodoan.local_push_connectivity.models.PluginSettings
import com.hodoan.local_push_connectivity.sockets.ISocketBase
import com.hodoan.local_push_connectivity.sockets.ReceiverCallback
import org.json.JSONObject
import java.security.cert.X509Certificate


class PushNotificationService : Service(), ReceiverCallback {
    private val context = this
    private var notifyManagerId = 1

    private var iconNotification: String? = null
    private var channelId: String? = null

    private var isShowNotify = false

    private lateinit var socket: ISocketBase

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.e("///", "onReceive: ${intent?.action} ")
            if (intent?.action == CHANGE_LIFE_CYCLE) {
                isShowNotify = intent.getBooleanExtra(NOTIFY_EXTRA, false)
            } else if (intent?.action == CHANGE_SETTING) {
                val jsonString = intent.getStringExtra(SETTINGS_EXTRA)!!
                val newSettings = PluginSettings.fromJson(JSONObject(jsonString))
                socket.updateSettings(newSettings)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground()
        val filter = IntentFilter(CHANGE_LIFE_CYCLE)
        filter.addAction(CHANGE_SETTING)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            ActivityCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        }
    }

    private fun startForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel(context, context.packageName)
        }
    }

    private fun showNotification(str: String) {

        val json = JSONObject(str)

        val data = json["Notification"]
        var title = ""
        var content = ""

        try {
            val mNotify = data as JSONObject
            if (!mNotify.isNull("Title")) {
                title = mNotify.getString("Title")
            }
            content = data.getString("Body")
        } catch (e: Exception) {
            Log.e("///", "showNotification: parse body error $e")
        }

        val channelId = createNotificationChannel(applicationContext, channelId ?: context.packageName)

        val packageName = context.packageName
        val packageManager = context.packageManager
        val activityIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            if (isShowNotify) {
                putExtra("from_notify", true)
            }
            putExtra("payload", str)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notifyManagerId,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (!isShowNotify) {
            pendingIntent.send()
            return
        }

        if (title.isEmpty()) return

        val notification = createNotification(channelId, title, content, pendingIntent)

        with(NotificationManagerCompat.from(this)) {
            if (ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                PushNotificationService::class.simpleName?.let {
                    Log.e(
                        it,
                        "showNotification: PERMISSION DENIED",
                    )
                }
                return
            }
            notifyManagerId++
            notify(notifyManagerId, notification)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val summaryNotification = NotificationCompat.Builder(applicationContext, channelId)
                    .setSmallIcon(getIcon())
                    .setColor(Color.GRAY)
                    .setContentTitle(title)
                    .setContentText(content)
                    .setGroup(GROUP_KEY)
                    .setGroupSummary(true)
                    .build()

                notify(SUMMARY_ID, summaryNotification)
            }
        }
    }

    private fun createNotification(
        channelId: String,
        title: String,
        content: String,
        pendingIntent: PendingIntent? = null
    ): Notification {
        val notificationBuilder = NotificationCompat.Builder(applicationContext)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val mBuilder = notificationBuilder
                .setSmallIcon(getIcon())
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setPriority(NotificationManager.IMPORTANCE_HIGH)
                .setColor(Color.GRAY)
                .setChannelId(channelId)
                .setContentTitle(title)
                .setContentText(content)

                .setGroup(GROUP_KEY)
                .setAutoCancel(true)
                .setVibrate(longArrayOf(0))

            if (pendingIntent != null) {
                mBuilder.setContentIntent(pendingIntent)
            }

            mBuilder.build()
        } else {
            val mBuilder = notificationBuilder
                .setSmallIcon(getIcon())
                .setPriority(PRIORITY_MAX)
                .setChannelId(channelId)
                .setContentTitle(content)
                .setContentText(title)
                .setColor(Color.GRAY)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            if (pendingIntent != null) {
                mBuilder.setContentIntent(pendingIntent)
            }

            mBuilder.build()
        }
    }

    companion object {
        const val CHANGE_LIFE_CYCLE: String = "com.hodoan.CHANGE_LIFE_CYCLE"
        const val NOTIFY_EXTRA: String = "NOTIFY_EXTRA"
        const val CHANGE_SETTING: String = "com.hodoan.CHANGE_SETTING"
        const val SETTINGS_EXTRA: String = "SETTINGS_EXTRA"
        const val PREF_NAME: String = "LocalPushFlutter"
        const val SETTINGS_PREF: String = "SETTINGS_PREF"

        const val SUMMARY_ID = 0
        const val GROUP_KEY = "com.GROUP_KEY"

        fun getPublicKeyFromCertificate(cert: X509Certificate): ByteArray {
            return cert.publicKey.encoded
        }

        fun createNotificationChannel(context: Context, channelId: String): String {
            val channelName = "My Background Service"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName, NotificationManager.IMPORTANCE_HIGH
                )
                val notificationManager: NotificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
            return channelId
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.e("////", "onUnbind: ")
        val bundle = intent?.extras

        bundle?.getString(SETTINGS_EXTRA)?.let {
            val settings = PluginSettings.fromJson(JSONObject(it))
            iconNotification = settings.iconNotification
            socket = ISocketBase.register(contentResolver, this, settings)
            socket.updateSettings(settings)
        }
        Log.e(PushNotificationService::class.simpleName, "onBind: ")
        return null
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.e("////", "onUnbind: ")
        socket.disconnect()
        return super.onUnbind(intent)
    }

    private fun getIcon(): Int {
        val icons = (iconNotification ?: "").replaceFirst("@", "").split("/")
        Log.e(PushNotificationService::class.simpleName, "getIcon: $icons ${context.packageName}")
        val i = applicationContext.resources.getIdentifier(
            icons.last(),
            icons.first(),
            context.packageName
        )
        Log.e(PushNotificationService::class.simpleName, "getIcon: $i")
        return i
    }

    override fun onDestroy() {
        Log.e("////", "onDestroy: ")
        onUnbind(null)
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.e(PushNotificationService::class.simpleName, "onsc: ")
        val bundle = intent?.extras

        bundle?.getString(SETTINGS_EXTRA)?.let {
            val settings = PluginSettings.fromJson(JSONObject(it))
            iconNotification = settings.iconNotification
            channelId = settings.channelNotification
            socket = ISocketBase.register(contentResolver, this, settings)
            socket.updateSettings(settings)
        }

        super.onStartCommand(intent, flags, startId)

        val channelId = createNotificationChannel(applicationContext, channelId ?: context.packageName)

        val notification = createNotification(
            channelId,
            "Service Running",
            "This is a foreground service"
        )

        startForeground(101, notification)

        socket.createSocket()

        return START_NOT_STICKY
    }

    override fun newMessage(message: String) {
        showNotification(message)
    }
}