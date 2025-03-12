//
//  MessageManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import UserNotifications

public protocol MessageManagerDelegate {
    func onMessage(message: String,_ foreground: Bool)
}

public class MessageManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = MessageManager()
    
    public var delegate: MessageManagerDelegate? = nil
    
    public func initial() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission() {
            _ in
        }
    }
    
    public func requestNotificationPermission(result completionHandler: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]){
            granted, error in
            if granted == true && error == nil {
                print("notification permission granted")
                completionHandler(true)
            } else {
                print("notification permission denied")
                completionHandler(false)
            }
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let payload = response.notification.request.content.userInfo["payload"] as? String {
            delegate?.onMessage(message: payload, true)
        }
        //        let isShowNotify = response.notification.request.content.userInfo["showNotify"] as? Bool ?? true
        //                if isShowNotify {
        //                    return
        //                }
        //        return completionHandler()
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if let payload = notification.request.content.userInfo["payload"] as? String {
            delegate?.onMessage(message: payload, false)
        }
        //        let isShowNotify = notification.request.content.userInfo["showNotify"] as? Bool ?? false
        //        if !isShowNotify {
        //            return
        //        }
        //        if #available(iOS 14.0, *) {
        //            return completionHandler([.badge, .sound, .banner])
        //        } else {
        //            completionHandler([.badge, .sound, .alert])
        //        }
    }
    
    public func showNotificationError(payload: String) {
        let content = UNMutableNotificationContent()
        content.title = "Logger"
        content.body = payload
        content.sound = .default
        content.userInfo = [
            "message": payload,
            "showNotify": true,
        ]
        
        let request = UNNotificationRequest(identifier: "silentNotification", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) {
            error in
            if let err = error {
                print("Error submitting local notification: \(err)")
                return
            }
            
            print("local notification posted successfully")
        }
    }
    
}
