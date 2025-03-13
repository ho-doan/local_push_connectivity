//
//  Settings.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation

#if os(iOS)
import UIKit
#endif

public struct Settings: Codable, Equatable {
    public struct PushManagerSettings: Codable, Equatable {
        public var ssid: String = ""
        public var host: String = ""
        public var port: Int? = nil
        public var wss: Bool = false
        public var part: String = ""
        public var useTCP: Bool = false
        public var publicKey: String = ""
        
        public init(ssid: String, host: String, port: Int?, wss: Bool = false, part: String = "",useTCP : Bool = false, publicKey : String = "") {
            self.ssid = ssid
            self.host = host
            self.port = port
            self.wss = wss
            self.part = part
            self.useTCP = useTCP
            self.publicKey=publicKey
        }
        
        public init(){}
    }
    
    public var uuid: String? = nil
    public var deviceId: String? = nil
    public var appKilled: Bool = false
    public var pushManagerSettings = PushManagerSettings()
    
    public init(uuid: String, deviceId: String?, appKilled: Bool = false, pushManagerSettings: Settings.PushManagerSettings = PushManagerSettings()) {
        self.uuid = uuid
        self.deviceId = deviceId
        self.appKilled = appKilled
        self.pushManagerSettings = pushManagerSettings
    }
    
    public init(){}
}
