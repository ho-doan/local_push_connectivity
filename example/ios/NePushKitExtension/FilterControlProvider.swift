//
//  FilterControlProvider.swift
//  NePushKitExtension
//
//  Created by Ho Doan on 3/12/25.
//

import Foundation
import NetworkExtension
import local_push_connectivity

class FilterControlProvider: NEAppPushProvider, UserSettingsObserverDelegate {
    func userSettingsDidChange(settings: Settings) {
        self.channel?.disconnect()
        self.channel = nil
        
        let channel = ISocManager.register(settings: settings)
        let retryWorkItem = DispatchWorkItem {
            print("Retrying to connect with update...")
            self.channel = channel
            if settings.user.uuid?.isEmpty ?? true {
                channel?.disconnect()
            }
            else if !settings.pushManagerSettings.isEmptyInApp {
                channel?.connect(settings: settings)
            } else {
                MessageManager.shared.showNotificationError(payload: "error ---- \(settings)")
            }
        }
        let dispatchQueue = DispatchQueue(label: "LocalPushConnectivityPlugin.dispatchQueue")
        dispatchQueue.asyncAfter(deadline: .now() + 6, execute: retryWorkItem)
    }
    
    private let dispatchQueue = DispatchQueue(label: "FilterControlProvider.dispatchQueue")
    private let messageManager = MessageManager.shared
    private var channel: ISocManager? = nil
    
    lazy var settingManager = SettingManager(self)
    
    override func start() {
        guard let _ = providerConfiguration?["host"] as? String else {
            self.messageManager.showNotificationError(payload: "providerConfiguration nill")
            return
        }
        
        if self.channel == nil {
            let settings = settingManager.fetch()!
            self.channel = ISocManager.register(settings: settings)
        } else {
            self.channel?.disconnect()
        }
        
        let retryWorkItem = DispatchWorkItem {
            print("Retrying to connect with update...")
            self.channel?.connect()
        }
        
        let dispatchQueue = DispatchQueue(label: "LocalPushConnectivityPlugin.dispatchQueue")
        dispatchQueue.asyncAfter(deadline: .now() + 6, execute: retryWorkItem)
        
    }
    
    override func stop(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        self.channel?.disconnect()
        completionHandler()
    }
}
