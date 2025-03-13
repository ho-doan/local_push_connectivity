import Flutter
import UIKit
import Network
import Foundation

struct Message: Decodable, Encodable{
    var type: Bool
    var data: String
}

extension LocalPushConnectivityPlugin: MessageManagerDelegate{
    public func onMessage(message: String, _ foreground: Bool) {
        let m = Message(type: foreground, data: message)
        let jsonData = try! JSONEncoder().encode(m)
        self.messEvent.sendData(String(data: jsonData, encoding: .utf8))
    }
}

public class LocalPushConnectivityPlugin: NSObject, FlutterPlugin, UserSettingsObserverDelegate {
    public func userSettingsDidChange(settings: Settings) {
        if Bundle.main.object(forInfoDictionaryKey: "NEAppPushBundleId") as? String == nil {
            sManager?.disconnect()
            sManager = nil
            let channel = ISocManager.register(settings: settings)
            let retryWorkItem = DispatchWorkItem {
                print("Retrying to connect with update...")
                self.sManager = channel
                if settings.user.uuid?.isEmpty ?? true {
                    channel?.disconnect()
                }
                else if !settings.pushManagerSettings.isEmptyInApp {
                    channel?.connect(settings: settings)
                } else {
                    MessageManager.shared.showNotificationError(payload: "hh ---- \(settings)")
                }
            }
            let dispatchQueue = DispatchQueue(label: "LocalPushConnectivityPlugin.dispatchQueue")
            dispatchQueue.asyncAfter(deadline: .now() + 6, execute: retryWorkItem)
        }
    }
    
    private let  messEvent = MessageEventChannel()
    private let dispatchQueue = DispatchQueue(label: "FilterControlProvider.dispatchQueue")
    
    private var sManager: ISocManager? = nil
    
    lazy var settingManager = SettingManager(self)
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LocalPushConnectivityPlugin()
        let eventChannel = FlutterEventChannel(
            name: "local_push_connectivity/events",
            binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance.messEvent)
        let channel = FlutterMethodChannel(name: "local_push_connectivity", binaryMessenger: registrar.messenger())
        MessageManager.shared.initial()
        MessageManager.shared.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "getPlatformVersion":
                result("iOS " + UIDevice.current.systemVersion)
            case "initial":
                if #available(iOS 15.0, *) {
                    if let arguments = call.arguments as? [String: Any],
                       let host = arguments["host"] as? String,
                       let deviceId = UIDevice.current.identifierForVendor?.uuidString,
                       let port = arguments["port"] as? Int {
                        let userId = arguments["userId"] as? String
                        let ssid = arguments["ssid"] as? String ?? ""
                        let wss = arguments["wss"] as? Bool ?? false
                        let part = arguments["part"] as? String ?? ""
                        let publicKey = arguments["publicHasKey"] as? String ?? ""
                        
                        var useTCP = false
                        
                        if part == "" {
                            useTCP = true
                        }
                        
                        var settings = settingManager.fetch()!
                        
                        settings.deviceId = deviceId
                        
                        if userId != nil{
                            settings.uuid = userId
                        }
                        
                        settings.pushManagerSettings.part = part
                        settings.pushManagerSettings.wss = wss
                        settings.pushManagerSettings.useTCP = useTCP
                        settings.pushManagerSettings.publicKey = publicKey
                        
                        settings.pushManagerSettings.host = host
                        
                        if ssid != "" {
                            settings.pushManagerSettings.ssid = ssid
                        }
                        
                        settings.pushManagerSettings.port = port
                        
                        try? settingManager.set(settings: settings)
                        
                        //                        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                        //                            .sink {
                        //                                [weak self] _ in
                        //                                if userId != nil {
                        //                                    var settings = SettingManager.shared.settings
                        //                                    settings.uuid = userId
                        //                                    try? SettingManager.shared.set(settings: settings)
                        //                                    try? self?.settingManager.set(settings: settings)
                        //                                }
                        //                            }
                        //                            .store(in: &cancellables)
                        
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                        return
                    }
                }
                result(nil)
            case "configSSID":
                if #available(iOS 15.0, *) {
                    if let arguments = call.arguments as? [String: Any],
                       let ssid = arguments["ssid"] as? String {
                        
                        var settings = settingManager.fetch()!
                        
                        settings.pushManagerSettings.ssid = ssid
                        
                        try? settingManager.set(settings: settings)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                        return
                    }
                }
                result(nil)
            case "config":
                if #available(iOS 15.0, *) {
                    if let arguments = call.arguments as? [String: Any],
                       let host = arguments["host"] as? String,
                       let port = arguments["port"] as? Int {
                        
                        let wss = arguments["wss"] as? Bool ?? false
                        let part = arguments["part"] as? String ?? ""
                        let publicKey = arguments["publicHasKey"] as? String ?? ""
                        
                        var useTCP = false
                        
                        if(part == ""){
                            useTCP = true
                        }
                        
                        var settings = settingManager.fetch()!
                        
                        settings.pushManagerSettings.part = part
                        settings.pushManagerSettings.wss = wss
                        settings.pushManagerSettings.useTCP = useTCP
                        settings.pushManagerSettings.publicKey = publicKey
                        
                        settings.pushManagerSettings.host = host
                        settings.pushManagerSettings.port = port
                        
                        try? settingManager.set(settings: settings)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                        return
                    }
                }
                result(nil)
            case "setUser":
                let args = call.arguments as? [String: Any]
                guard let userId = args?["userId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: "can not parse arguments"))
                    return
                }
                if #available(iOS 15.0, *) {
                    var settings = settingManager.fetch()!
                    settings.uuid = userId
                    try? settingManager.set(settings: settings)
                }
                result(nil)
            case "requestPermission":
                MessageManager.shared.requestNotificationPermission(){
                    res in
                    result(res)
                }
            case "start":
                //            var settings = SettingManager.shared.settings
                //            try? SettingManager.shared.set(settings: settings)
                result(true)
            case "stop":
                if #available(iOS 15.0, *) {
                    var settings = settingManager.fetch()!
                    settings.uuid = nil
                    try? settingManager.set(settings: settings)
                }
                result(true)
            default:
                result(FlutterMethodNotImplemented)
        }
    }
}

class MessageEventChannel: NSObject, FlutterStreamHandler{
    private var sink:FlutterEventSink? = nil
    private var messageWhenAppKilled: String? = nil
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        if let mess = messageWhenAppKilled {
            sendData(mess)
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func sendData(_ data: String?) {
        if sink == nil {
            messageWhenAppKilled = data
        }
        if data == nil {return}
        self.sink?(data)
        return
    }
}
