import Flutter
import UIKit

import local_push_connectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let _ = Bundle.main.object(forInfoDictionaryKey: "NEAppPushBundleId") as? String{
            PushConfigurationManager.shared.initialize()
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        let settingManager = SettingManager(nil)
        var settings = settingManager.fetch()!
        settings.appKilled = false
        try? settingManager.set(settings: settings)
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        let settingManager = SettingManager(nil)
        var settings = settingManager.fetch()!
        settings.appKilled = true
        try? settingManager.set(settings: settings)
    }
}
