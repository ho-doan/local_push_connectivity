package com.hodoan.local_push_connectivity.models

import org.json.JSONObject

data class PluginSettings(
    var host: String? = null,
    var deviceId: String? = null,
    var userId: String? = null,
    var iconNotification: String? = null,
    var port: Int? = null,
    var channelNotification: String? = null,

    var wss: Boolean? = null,
    var wsPath: String? = null,
    var useTcp: Boolean? = null,
    var publicKey: String? = null
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("host", host)
            put("deviceId", deviceId)
            put("userId", userId)
            put("iconNotification", iconNotification)
            put("channelNotification", channelNotification)
            put("port", port)
            put("wss", wss)
            put("part", wsPath)
            put("useTCP", useTcp)
            put("publicHasKey", publicKey)
        }
    }

    fun copyWith(settings: PluginSettings): PluginSettings {
        return PluginSettings(
            host = settings.host ?: host,
            deviceId = settings.deviceId ?: deviceId,
            userId = settings.userId ?: userId,
            iconNotification = settings.iconNotification ?: iconNotification,
            channelNotification = settings.channelNotification ?: channelNotification,
            port = settings.port ?: port,
            wss = settings.wss ?: wss,
            wsPath = settings.wsPath ?: wsPath,
            useTcp = settings.useTcp ?: useTcp,
            publicKey = settings.publicKey ?: publicKey
        )
    }

    fun copyWith(user: String?): PluginSettings {
        return PluginSettings(
            host = host,
            deviceId = deviceId,
            userId = user,
            iconNotification = iconNotification,
            channelNotification = channelNotification,
            port = port,
            wss = wss,
            wsPath = wsPath,
            useTcp = useTcp,
            publicKey = publicKey
        )
    }

    companion object {
        fun fromJson(json: JSONObject): PluginSettings {
            return PluginSettings(
                host = json.optString("host"),
                deviceId = json.optString("deviceId"),
                userId = json.optString("userId"),
                iconNotification = json.optString("iconNotification"),
                channelNotification = json.optString("channelNotification"),
                port = json.optInt("port"),
                wss = json.optBoolean("wss"),
                wsPath = json.optString("part"),
                useTcp = json.optBoolean("useTCP"),
                publicKey = json.optString("publicHasKey")
            )
        }

        fun fromMap(map: Map<*, *>): PluginSettings {
            return PluginSettings(
                host = map["host"] as? String,
                deviceId = map["deviceId"] as? String,
                userId = map["userId"] as? String,
                iconNotification = map["iconNotification"] as? String,
                channelNotification = map["channelNotification"] as? String,
                port = map["port"] as? Int,
                wss = map["wss"] as? Boolean,
                wsPath = map["part"] as? String,
                useTcp = map["useTCP"] as? Boolean,
                publicKey = map["publicHasKey"] as? String
            )
        }


    }
}