package com.hodoan.local_push_connectivity

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import com.hodoan.local_push_connectivity.models.PluginSettings
import com.hodoan.local_push_connectivity.services.PushNotificationService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject

/** LocalPushConnectivityPlugin */
class LocalPushConnectivityPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, PluginRegistry.NewIntentListener,
    StreamHandler {
    private lateinit var settings: PluginSettings
    private lateinit var pref: SharedPreferences

    private lateinit var channel: MethodChannel
    private var sink: EventSink? = null

    private lateinit var context: Context

    private var activity: Activity? = null

    private var resultInitial: Result? = null

    var message: String? = null
    private var result: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "local_push_connectivity")
        val eventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "local_push_connectivity/events")
        eventChannel.setStreamHandler(this)
        context = flutterPluginBinding.applicationContext
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "initial" -> {
                val map = call.arguments as? Map<*, *>
                if (map == null || map["iconNotification"] == null) {
                    result.error("1", "arguments invalid", "can not parse arguments")
                    return
                }
                pref = context.getSharedPreferences(
                    PushNotificationService.PREF_NAME,
                    Context.MODE_PRIVATE
                )
                val settingString = pref.getString(PushNotificationService.SETTINGS_PREF, "")
                settings = if (settingString != null && settingString != "") {
                    PluginSettings.fromJson(JSONObject(settingString))
                        .copyWith(PluginSettings.fromMap(map))
                } else {
                    PluginSettings.fromMap(map)
                }
                if (settings.publicKey != null && settings.publicKey!!.length > 1) {
                    settings.useTcp = true
                    settings.wsPath = null
                } else if (settings.wsPath != null && settings.wsPath!!.length > 1) {
                    settings.useTcp = false
                    settings.publicKey = null
                } else {
                    settings.useTcp = true
                }

                if (activity != null) {
                    result.success(null)
                } else {
                    resultInitial = result
                }
                startService(null)
            }

            "config" -> {
                val map = call.arguments as? Map<*, *>
                if (map == null) {
                    result.error("1", "arguments invalid", "can not parse arguments")
                    return
                }

                val newSettings = PluginSettings.fromMap(map)
                settings = settings.copyWith(newSettings)
                if (settings.publicKey != null && settings.publicKey!!.length > 1) {
                    settings.useTcp = true
                    settings.wsPath = null
                } else if (settings.wsPath != null && settings.wsPath!!.length > 1) {
                    settings.useTcp = false
                    settings.publicKey = null
                } else {
                    settings.useTcp = true
                }

                startService(result)
            }

            "setUser" -> {
                val map = call.arguments as? Map<*, *>
                if (map == null || map["userId"] == null) {
                    result.error("1", "arguments invalid", "can not parse arguments")
                    return
                }

                val newSettings = PluginSettings.fromMap(map)
                settings = settings.copyWith(newSettings.userId)
                startService(result)
            }

            "requestPermission" -> {
                val permissionLst: Array<Boolean> =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pers = arrayListOf<Boolean>()
                        for (i in permissions().toTypedArray()) {
                            pers += context.checkSelfPermission(i) == PackageManager.PERMISSION_GRANTED
                        }
                        pers.toTypedArray()
                    } else {
                        val pers = arrayListOf<Boolean>()
                        for (i in permissions().toTypedArray()) {
                            pers +=
                                ActivityCompat.checkSelfPermission(
                                    context,
                                    i
                                ) == PackageManager.PERMISSION_GRANTED
                        }
                        pers.toTypedArray()
                    }
                if (!permissionLst.any { !it }) {
                    result.success(true)
                    return
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    activity!!.requestPermissions(
                        permissions().toTypedArray(), 111
                    )
                } else {
                    ActivityCompat.requestPermissions(
                        activity!!, permissions().toTypedArray(), 111
                    )
                }

                this.result = result
            }

            "start" -> startService(result)
            "stop" -> stopService(result)
            else -> result.notImplemented()
        }
    }

    private fun stopService(result: Result?) {
        try {
            activity?.let {
                if (isServiceRunning(it, PushNotificationService::class.java)) {
                    settings.userId = null
                    startService(null)
                }
                result?.success(true)
                return
            }
            result?.error("3", "stop service error", "activity is null")
        } catch (e: Exception) {
            Log.e(LocalPushConnectivityPlugin::class.simpleName, "stopService: $e")
            result?.error("3", "stop service error", e.localizedMessage)
        }
    }

    @SuppressLint("CommitPrefEdits")
    private fun startService(result: Result?) {
        pref.edit().apply {
            putString(PushNotificationService.SETTINGS_PREF, settings.toJson().toString())
        }
        if (isServiceRunning(activity!!, PushNotificationService::class.java)) {
            val intent = Intent(PushNotificationService.CHANGE_SETTING)

            intent.putExtra(PushNotificationService.SETTINGS_EXTRA, settings.toJson().toString())
            activity!!.sendBroadcast(intent)
            result?.success(true)
            return
        }

        if (activity == null) {
            result?.error("2", "activity is null", null)
            return
        }

        val intent = Intent(activity, PushNotificationService::class.java)

        intent.putExtra(PushNotificationService.SETTINGS_EXTRA, settings.toJson().toString())

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity!!.startForegroundService(intent)
            } else {
                activity!!.startService(intent)
            }
            result?.success(true)
        } catch (e: Exception) {
            result?.error("3", "start service error", e.localizedMessage)
        }
    }

    private fun permissions(): ArrayList<String> {
        val permissionLst = arrayListOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            permissionLst += Manifest.permission.FOREGROUND_SERVICE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLst += Manifest.permission.POST_NOTIFICATIONS
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            permissionLst += Manifest.permission.FOREGROUND_SERVICE
        }
        return permissionLst
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onDetachedFromActivity()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity

        binding.addRequestPermissionsResultListener(this)
        binding.addOnNewIntentListener(this)

        var intent = activity!!.intent
        var newMessage = intent.getStringExtra("payload")

        activity?.application?.registerActivityLifecycleCallbacks(object :
            Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                val i = Intent(PushNotificationService.CHANGE_LIFE_CYCLE).apply {
                    putExtra(PushNotificationService.NOTIFY_EXTRA, false)
                }
                activity.sendBroadcast(i)
            }

            override fun onActivityStarted(activity: Activity) {
                try {
                    intent = activity.intent
                    if (intent.getStringExtra("payload") != null) {
                        newMessage = intent.getStringExtra("payload")
                    }
                    if (newMessage != null && sink != null) {
                        intent.removeExtra("payload")
                        val json = JSONObject()
                        json.put("type", true)
                        json.put("data", newMessage)
                        Handler(Looper.getMainLooper()).post {
                            sink!!.success(json.toString())
                        }
                        Log.e(
                            LocalPushConnectivityPlugin::class.simpleName,
                            "onActivityStarted: $sink"
                        )
                    } else {
                        message = newMessage
                    }
                    Log.e(
                        LocalPushConnectivityPlugin::class.simpleName,
                        "onActivityStarted: $newMessage $sink"
                    )
                } catch (e: Exception) {
                    Log.e(
                        LocalPushConnectivityPlugin::class.simpleName,
                        "onActivityStarted error: $e"
                    )
                }
            }

            override fun onActivityResumed(activity: Activity) {
                val i = Intent(PushNotificationService.CHANGE_LIFE_CYCLE).apply {
                    putExtra(PushNotificationService.NOTIFY_EXTRA, false)
                }
                activity.sendBroadcast(i)
            }

            override fun onActivityPaused(activity: Activity) {
                newMessage = null
                intent.removeExtra("payload")
                val i = Intent(PushNotificationService.CHANGE_LIFE_CYCLE).apply {
                    putExtra(PushNotificationService.NOTIFY_EXTRA, true)
                }
                activity.sendBroadcast(i)
            }

            override fun onActivityStopped(activity: Activity) {
                val i = Intent(PushNotificationService.CHANGE_LIFE_CYCLE).apply {
                    putExtra(PushNotificationService.NOTIFY_EXTRA, true)
                }
                activity.sendBroadcast(i)
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

            override fun onActivityDestroyed(activity: Activity) {
                val i = Intent(PushNotificationService.CHANGE_LIFE_CYCLE).apply {
                    putExtra(PushNotificationService.NOTIFY_EXTRA, true)
                }
                activity.sendBroadcast(i)
            }
        })
        resultInitial?.success(null)
        resultInitial = null
        if (newMessage != null && sink != null) {
            val json = JSONObject()
            json.put("type", true)
            json.put("data", newMessage)
            Handler(Looper.getMainLooper()).post {
                sink!!.success(json.toString())
            }
        } else {
            message = newMessage
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        binding.removeRequestPermissionsResultListener(this)
        Log.e(
            LocalPushConnectivityPlugin::class.simpleName,
            "onReattachedToActivityForConfigChanges: "
        )
    }

    override fun onDetachedFromActivity() {
        channel.setMethodCallHandler(null)
        activity = null
        Log.e(LocalPushConnectivityPlugin::class.simpleName, "onDetachedFromActivity: ")
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        val r = requestCode == 111 && !grantResults.toList()
            .any { it != PackageManager.PERMISSION_GRANTED }
        result?.success(r)
        result = null
        return r
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val newMessage = intent.getStringExtra("payload")
        val fromNotify = intent.getBooleanExtra("from_notify", false)
        if (fromNotify) {
            val json = JSONObject()
            json.put("type", true)
            json.put("data", newMessage)
            Handler(Looper.getMainLooper()).post {
                sink!!.success(json.toString())
            }
        } else {
            val json = JSONObject()
            json.put("type", false)
            json.put("data", newMessage)
            Handler(Looper.getMainLooper()).post {
                sink!!.success(json.toString())
            }
        }
        return true
    }

    companion object {
        fun isServiceRunning(activity: Activity, serviceClass: Class<*>): Boolean {
            val activityManager =
                activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            Log.e(
                LocalPushConnectivityPlugin::class.simpleName,
                "isServiceRunning: ${
                    activityManager.getRunningServices(Int.MAX_VALUE).map { it.service.className }
                } ${serviceClass.name}",
            )
            for (serviceInfo in activityManager.getRunningServices(Int.MAX_VALUE)) {
                if (serviceClass.name == serviceInfo.service.className) {
                    return true // Service is running
                }
            }
            return false // Service is not running
        }
    }

    override fun onListen(arguments: Any?, events: EventSink?) {
        sink = events
        if (message != null) {
            val json = JSONObject()
            json.put("type", true)
            json.put("data", message)
            Handler(Looper.getMainLooper()).post {
                sink!!.success(json.toString())
            }
            message = null
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
