//
//  User.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation

public struct User: Codable, Equatable, Hashable {
    public var uuid: String?
    
    public init(uuid: String?) {
        self.uuid = uuid
    }
}