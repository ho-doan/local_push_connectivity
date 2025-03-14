//
//  SettingManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import Combine

public protocol UserSettingsObserverDelegate: AnyObject {
    func userSettingsDidChange(settings: Settings)
}

// @available(iOS 13.0, *)
public class SettingManager: NSObject {
    private static let settingsKey = "settings"
    private static let groupId = Bundle.main.object(forInfoDictionaryKey: "GroupNEAppPushLocal") as? String
    private static let userDefaults: UserDefaults = Self.groupId != nil ? UserDefaults(suiteName: Self.groupId)! : UserDefaults.standard
    
    private let delegate: UserSettingsObserverDelegate?
    
    private var settings: Settings = Settings()
    
    public init(_ delegate: UserSettingsObserverDelegate?) {
        self.delegate = delegate
        super.init()
        Self.userDefaults.addObserver(self, forKeyPath: Self.settingsKey, options: [.new], context: nil)
        
        var setting = Self.fetch()
        if setting == nil {
            print("Error settings nil ==========")
            setting = Settings()
            
            do {
                try Self.set(settings: setting!)
            } catch {
                print("Error encoding settings - \(error)")
            }
        }
        self.settings = settings
    }
    
    private static func set(settings: Settings) throws {
        let encoder = JSONEncoder()
        let encodedSettings = try encoder.encode(settings)
        userDefaults.set(encodedSettings, forKey: Self.settingsKey)
    }
    
    public func set(settings: Settings) throws {
        let encoder = JSONEncoder()
        let encodedSettings = try encoder.encode(settings)
        
        Self.userDefaults.set(encodedSettings, forKey: Self.settingsKey)
    }
    
    private static func fetch() -> Settings? {
        guard let encodedSettings = userDefaults.data(forKey: settingsKey) else {
            print("Error settings nil")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(Settings.self, from: encodedSettings)
            return settings
        } catch {
            print("Error decoding settings - \(error)")
            return nil
        }
    }
    
    public func fetch() -> Settings? {
        guard let encodedSettings = Self.userDefaults.data(forKey: Self.settingsKey) else {
            print("Error settings nil")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(Settings.self, from: encodedSettings)
            return settings
        } catch {
            print("Error decoding settings - \(error)")
            return nil
        }
    }
    
    func refresh() throws {
        guard let settings = Self.fetch() else {
            return
        }
        if settings != self.settings{
            self.settings = settings
            delegate?.userSettingsDidChange(settings: settings)
        }
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        print("observeValue settings ===")
        do {
            try refresh()
        } catch {
            print("Error refreshing settings - \(error)")
        }
    }
}
