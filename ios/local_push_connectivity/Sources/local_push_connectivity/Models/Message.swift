//
//  Message.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/5/24.
//

import Foundation

struct AnyDecodable: Decodable {
   let value: Any

   init(from decoder: Decoder) throws {
       let container = try decoder.singleValueContainer()

       if let intValue = try? container.decode(Int.self) {
           value = intValue
       } else if let doubleValue = try? container.decode(Double.self) {
           value = doubleValue
       } else if let stringValue = try? container.decode(String.self) {
           value = stringValue
       } else if let boolValue = try? container.decode(Bool.self) {
           value = boolValue
       } else if let dictionaryValue = try? container.decode([String: AnyDecodable].self) {
           value = dictionaryValue.mapValues { $0.value }
       } else if let arrayValue = try? container.decode([AnyDecodable].self) {
           value = arrayValue.map { $0.value }
       } else if container.decodeNil() {
           value = NSNull()
       } else {
           throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
       }
   }
}


struct Notification : Decodable {
   var Title: String
   var Body: String
}

struct TextMessage : Decodable {
   var notification: Notification
   var Data: [String:Any]
   
   private enum CodingKeys: String, CodingKey {
       case Data
       case Notification
   }

   init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)
       notification = try container.decode(Notification.self, forKey: .Notification)
       Data = try container.decode([String: AnyDecodable].self, forKey: .Data).mapValues { $0.value }
   }
}
