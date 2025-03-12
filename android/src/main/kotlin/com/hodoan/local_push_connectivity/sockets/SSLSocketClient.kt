package com.hodoan.local_push_connectivity.sockets

import android.annotation.SuppressLint
import android.content.ContentResolver
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import com.hodoan.local_push_connectivity.models.PluginSettings
import com.hodoan.local_push_connectivity.services.PushNotificationService
import java.io.InputStream
import java.io.OutputStreamWriter
import java.security.MessageDigest
import java.security.cert.X509Certificate
import java.util.Base64
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.X509TrustManager

class SSLSocketClient(
    contentResolver: ContentResolver,
    private val receiverCallback: ReceiverCallback,
) : ISocketBase(contentResolver, receiverCallback) {
    private var socket: SSLSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStreamWriter? = null

    override fun connect() {
        startTimer()
        try {
            if (checkBeforeConnect()) return
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(
                null,
                arrayOf(@SuppressLint("CustomX509TrustManager")
                object : X509TrustManager {
                    @SuppressLint("TrustAllX509TrustManager")
                    override fun checkClientTrusted(
                        chain: Array<out X509Certificate>,
                        authType: String?
                    ) {
                    }

                    @RequiresApi(Build.VERSION_CODES.O)
                    override fun checkServerTrusted(
                        chain: Array<out X509Certificate>,
                        authType: String?
                    ) {
                        val serverPublicKeyData =
                            PushNotificationService.getPublicKeyFromCertificate(chain[0])
                        val serverPublicKeyHash =
                            cryptoKitSHA256(serverPublicKeyData)
                        if (serverPublicKeyHash != settings.publicKey) {
                            throw Exception("Presented certificate doesn't match.")
                        }
                        // The server certificate is valid and matches the pinned certificate.
                    }

                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                }), null
            )
            val sslSocketFactory = sslContext.socketFactory

            socket = sslSocketFactory.createSocket(settings.host, settings.port!!) as SSLSocket

            socket?.let {
                it.enabledProtocols = arrayOf("TLSv1.2", "TLSv1.3")
                it.enabledCipherSuites = socket!!.supportedCipherSuites
                it.startHandshake()

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

    override fun disconnect() {
        isConnected = false
        settings.userId = null
        thread?.interrupt()
        socket = null
        thread = null
    }

    companion object {
        @RequiresApi(Build.VERSION_CODES.O)
        private fun cryptoKitSHA256(data: ByteArray): String {
            val messageDigest = MessageDigest.getInstance("SHA-256")
            val hash = messageDigest.digest(data)
            return Base64.getEncoder().encodeToString(hash)
        }
    }
}