//
//  PushConfigurationManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import NetworkExtension

#if os(iOS)
import UIKit
#endif

@available(iOS 14.0, *)
public class PushConfigurationManager: NSObject, UserSettingsObserverDelegate {
    public func userSettingsDidChange(settings: Settings) {
        if self.pushManagerSettings == settings.pushManagerSettings {
            return
        }
        if settings.pushManagerSettings.isEmpty{
            return
        }
        #if os(iOS)
        self.pushManagerSettings = settings.pushManagerSettings
        save(pushManager: pushManager ?? NEAppPushManager(), with: settings.pushManagerSettings)
        #endif
    }
    
    public static let shared = PushConfigurationManager()
    
    private let dispatchQueue = DispatchQueue(label: "PushConfigurationManager.dispatchQueue")
    #if os(iOS)
    private var pushManager: NEAppPushManager?
    #endif
    private var pushManagerSettings: Settings.PushManagerSettings?
    private let pushManagerDescription = "SimplePushDefaultConfiguration"
    private let pushProviderBundleIdentifier = (Bundle.main.object(forInfoDictionaryKey: "NEAppPushBundleId") as? String)!
    
    var settingManager: SettingManager!
    
    public override init() {
        super.init()
        settingManager = SettingManager(self)
    }
    
    public func initialize() {
        print("Loading existing push manager.")
        if let _ = Bundle.main.object(forInfoDictionaryKey: "NEAppPushBundleId") as? String{
#if os(iOS)
            NEAppPushManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    print("Failed to load all managers from preferences: \(error)")
                    return
                }
                
                guard let manager = managers?.first else {
                    return
                }
                manager.delegate = self
                
                self.dispatchQueue.async {
                    self.prepare(pushManager: manager)
                }
            }
#endif
        }
    }
    
    #if os(iOS)
    private func prepare(pushManager: NEAppPushManager) {
        self.pushManager = pushManager
        self.pushManager?.isEnabled = true

        if pushManager.delegate == nil {
            pushManager.delegate = self
        }
    }
    #endif
    
    #if os(iOS)
    private func save(pushManager: NEAppPushManager, with pushManagerSettings: Settings.PushManagerSettings) {
        pushManager.localizedDescription = pushManagerDescription
        pushManager.providerBundleIdentifier = pushProviderBundleIdentifier
        pushManager.delegate = self
        pushManager.isEnabled = true

        //        let host: String = pushManager.providerConfiguration["host"] as? String ?? "-11"
        //
        //        if pushManager.matchSSIDs == [pushManagerSettings.ssid] && host == pushManagerSettings.host {
        //            return pushManager.load()
        //        }

        pushManager.providerConfiguration = [
            "host": pushManagerSettings.host
        ]
        pushManager.matchSSIDs = [pushManagerSettings.ssid]
        pushManager.saveToPreferences { error in
            if let neError = error as? NEAppPushManagerError {
                print("NEAppPushError: \(neError.localizedDescription)")
            }
            else if let error = error {
                print("========= saveToPreferences \(error.localizedDescription)")
            }
            print("========= saveToPreferences ok")
        }

        (self.pushManager ?? pushManager).load {
            p in
            if p != nil {
                self.pushManager = p
            }
        }
        
        self.prepare(pushManager: self.pushManager ?? pushManager)
    }
    #endif
}
#if os(iOS)
@available(iOS 14.0, *)
extension PushConfigurationManager: NEAppPushDelegate {
    public func appPushManager(_ manager: NEAppPushManager, didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] = [:]) {
        #if os(iOS)
        print("appPushManager \(manager.isActive)")
        #endif
    }
}

@available(iOS 14.0, *)
extension NEAppPushManager {
    func load(completion: @escaping (NEAppPushManager?) -> Void) {
        loadFromPreferences { error in
            if error != nil {
                completion(nil)
            }
            completion(self)
        }
    }
    
    func remove(completion: @escaping (Bool) -> Void) {
        removeFromPreferences(completionHandler: { error in
            if error != nil {
                completion(false)
            }
            completion(true)
        })
    }
}
#endif

