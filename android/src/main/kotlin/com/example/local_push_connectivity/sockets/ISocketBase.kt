package com.hodoan.local_push_connectivity.sockets

import android.annotation.SuppressLint
import android.content.ContentResolver
import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.util.Log
import com.hodoan.local_push_connectivity.models.PluginSettings
import com.hodoan.local_push_connectivity.services.PushNotificationService
import org.json.JSONObject
import java.util.Timer
import java.util.TimerTask

interface ReceiverCallback {
    fun newMessage(message: String)
}

abstract class ISocketBase(
    private val contentResolver: ContentResolver,
    receiverCallback: ReceiverCallback,
) {
    lateinit var settings: PluginSettings

    init {
        settings = PluginSettings()
    }

    abstract fun disconnect()
    abstract fun connect()
    fun checkBeforeConnect(): Boolean {
        return (settings.userId == null || settings.userId == "" || settings.port == null || settings.host == null || settings.deviceId == null)
    }

    @SuppressLint("HardwareIds")
    fun updateSettings(settings: PluginSettings) {
        this.settings = this.settings.copyWith(settings)
        if (settings.userId == null) {
            this.settings.userId = null
        }
        if (this.settings.deviceId == null || this.settings.deviceId == "") {
            this.settings.deviceId =
                Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        }
        createSocket()
    }

    fun messageRegister(): String {
        val registerMessage = JSONObject()
        Log.e("///", "deviceId: ${settings.deviceId}")
        registerMessage.put("MessageType", "register")
        registerMessage.put("SendId", settings.userId)
        registerMessage.put("ReceiveId", "")
        registerMessage.put("DeviceId", settings.deviceId)
        return registerMessage.toString()
    }

    private var timer: Timer? = null
    var isConnected = false
    fun startTimer() {
        stopTimer()
        timer = Timer()
        val timerTask = object : TimerTask() {
            override fun run() {
                Log.e(
                    "////",
                    "socket status: $isConnected"
                )
            }
        }
        timer!!.schedule(timerTask, 0, 8000)
    }

    private fun stopTimer() {
        timer?.cancel()
        timer = null
    }

    var thread: Thread? = null

    fun createSocket() {
        thread = Thread {
            Log.e("///////", "onReceive: start thread")
            connect()
        }

        thread?.start()
    }

    companion object {
        fun register(
            contentResolver: ContentResolver,
            receiverCallback: ReceiverCallback,
            settings: PluginSettings
        ): ISocketBase {
            if (settings.useTcp == true) {
                if (settings.publicKey != null && settings.publicKey!!.length > 1) {
                    val socket = SSLSocketClient(contentResolver, receiverCallback)
                    socket.updateSettings(settings)
                    return socket
                }
                val socket = SocketClient(contentResolver, receiverCallback)
                socket.updateSettings(settings)
                return socket
            }
            val socket = WebSocketClient(contentResolver, receiverCallback)
            socket.updateSettings(settings)
            return socket
        }
    }
}