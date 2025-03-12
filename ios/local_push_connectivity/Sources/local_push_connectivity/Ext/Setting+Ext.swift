//
//  Setting+Ext.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation

public extension Settings {
    var user: User {
        User(uuid: uuid)
    }
}

public extension Settings.PushManagerSettings {
    var isEmpty: Bool {
        if !ssid.isEmpty && !host.isEmpty {
            return false
        }
        return true
    }
    
    var isEmptyInApp: Bool {
        if !host.isEmpty {
            return false
        }
        return true
    }
}
