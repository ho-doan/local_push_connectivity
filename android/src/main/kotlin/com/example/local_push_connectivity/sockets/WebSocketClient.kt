package com.hodoan.local_push_connectivity.sockets

import android.content.ContentResolver
import android.util.Log
import com.hodoan.local_push_connectivity.services.PushNotificationService
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.plugins.websocket.webSocket
import io.ktor.websocket.Frame
import io.ktor.websocket.readText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class WebSocketClient(
    contentResolver: ContentResolver,
    private val receiverCallback: ReceiverCallback
) : ISocketBase(contentResolver, receiverCallback) {

    private val client = HttpClient(CIO) {
        install(WebSockets) {
            pingInterval = 20_000
        }
    }

    override fun disconnect() {
        isConnected = false
        settings.userId = null
        thread?.interrupt()
        thread = null
        scope.cancel()
    }

    private suspend fun mConnect() {
        val url =
            "${if (settings.wss == true) "wss" else "ws"}://${settings.host}:${settings.port}${settings.wsPath}"
        client.webSocket(url) {
            isConnected = true
            send(Frame.Text(messageRegister()))
            for (message in incoming) {
                when (message) {
                    is Frame.Text -> receiverCallback.newMessage(message.readText())
                    is Frame.Binary -> TODO()
                    is Frame.Close -> TODO()
                    is Frame.Ping -> TODO()
                    is Frame.Pong -> TODO()
                }
            }

            Log.e(PushNotificationService::class.simpleName, "reconnect socket")
            Thread.sleep(5000)
            createSocket()
        }
    }

    private val scope = CoroutineScope(Job() + Dispatchers.Default)

    override fun connect() {
        startTimer()
        try {
            if (checkBeforeConnect()) return

            scope.launch {
                mConnect()
            }
        } catch (e: Exception) {
            Log.e(PushNotificationService::class.simpleName, "Socket communication error", e)
            Log.e(PushNotificationService::class.simpleName, "reconnect socket")
            Thread.sleep(5000)
            createSocket()
        }
    }
}