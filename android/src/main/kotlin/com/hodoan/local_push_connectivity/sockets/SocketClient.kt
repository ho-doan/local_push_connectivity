package com.hodoan.local_push_connectivity.sockets

import android.content.ContentResolver
import android.util.Log
import com.hodoan.local_push_connectivity.services.PushNotificationService
import java.io.InputStream
import java.io.OutputStreamWriter
import java.net.Socket

class SocketClient(
    contentResolver: ContentResolver,
    private var receiverCallback: ReceiverCallback
) : ISocketBase(contentResolver, receiverCallback) {
    private var socket: Socket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStreamWriter? = null
    override fun disconnect() {
        isConnected = false
        settings.userId = null
        thread?.interrupt()
        socket = null
        thread = null
    }

    override fun connect() {
        startTimer()
        try {
            if (checkBeforeConnect()) return
            socket = Socket(settings.host, settings.port!!)
            socket?.let {
                outputStream = OutputStreamWriter(it.getOutputStream())

                outputStream?.let { out ->
                    out.write(messageRegister())
                    out.flush()
                }

                inputStream = it.getInputStream()

                isConnected = true

                var str = ""
                while (!it.isClosed) {
                    if (it.isClosed) break
                    val data = inputStream?.read()
                    if((data ?: 0) > 0) {
                        str += data?.toChar()
                        if (inputStream?.available() == 0) {
                            Log.e("///", "on Socket Receive: $str")
                            if (str.isNotBlank()) {
                                receiverCallback.newMessage(str)
                                str = ""
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(PushNotificationService::class.simpleName, "Socket communication error", e)
            Log.e(PushNotificationService::class.simpleName, "reconnect socket")
            Thread.sleep(5000)
            createSocket()
        } finally {
            if (socket?.isClosed == false) {
                isConnected = true
                socket?.close()
            }
            inputStream?.close()
            outputStream?.close()
            inputStream = null
            outputStream = null
            socket = null
        }
    }
}