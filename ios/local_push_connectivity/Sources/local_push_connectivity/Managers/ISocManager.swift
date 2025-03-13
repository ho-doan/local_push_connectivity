//
//  ISocManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import Combine
import UserNotifications
import Network

@available(iOS 13.0, macOS 12, *)
public class ISocManager {
    public static func register(settings:Settings) -> ISocManager{
        if settings.pushManagerSettings.useTCP{
            if !settings.pushManagerSettings.publicKey.isEmpty{
                return TCPManager(settings: settings)
            }
            return TCP2Manager(settings: settings)
        }
        return WebSocketManager(settings: settings)
    }
    
    let messageWillWriteSubject = PassthroughSubject<Void, Never>()
    
    let messageSubject: CurrentValueSubject<String?, Never>
    var cancellables = Set<AnyCancellable>()
    
    public enum State: String, Equatable {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }
    
    public enum Error: Swift.Error {
        case notConnected
        case connectionFailed(Swift.Error)
        case connectionCancelled
    }
    
    public var state: State {
        stateSubject.value
    }
    
    public private(set) lazy var statePublisher = {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
    
    let dispatchQueue = DispatchQueue(label: "NetworkSession.dispatchQueue")
    
    let loggerDispatchQueue = DispatchQueue(label: "NetworkSession.loggerDispatchQueue")
    
    let stateSubject = CurrentValueSubject<State, Never>(.disconnected)
    
    let retryInterval = DispatchTimeInterval.seconds(5)
    
    var retryWorkItem: DispatchWorkItem?
    
    init() {
        messageSubject = CurrentValueSubject(nil)
        stateSubject.sink { state in
            print("State - \(state)")
        }.store(in: &cancellables)
        
        messageSubject.receive(on: DispatchQueue.main)
            .sink {
                [self] message in
                guard let mess = message else {
                    return
                }
                self.showNotification(payload: mess)
            }
            .store(in: &cancellables)
    }
    
    public func connect(){
        fatalError("This method must be overridden in a subclass")
    }
    
    public var appKilled = false
    
    public func connect(settings: Settings){
        fatalError("This method must be overridden in a subclass")
    }
    
    public func disconnect() {
        fatalError("This method must be overridden in a subclass")
    }
    
    func retry(after delay: DispatchTimeInterval, error: NWError?) {
        fatalError("This method must be overridden in a subclass")
    }
    
    func cancelRetry() {
        fatalError("This method must be overridden in a subclass")
    }
    
    func receiveData() {
        fatalError("This method must be overridden in a subclass")
    }
    
    func showNotification(payload: String) {
        if payload.isEmpty {
            return
        }
        guard let data = payload.data(using: .utf8) else {
            return
        }
        
        guard let textMessage = try? JSONDecoder().decode(TextMessage.self, from: data) else {
            return
        }
        
        if self.appKilled && textMessage.notification.Title.isEmpty {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = textMessage.notification.Title
        content.body = textMessage.notification.Body
        if !textMessage.notification.Title.isEmpty {
            content.sound = .default
        } else {
            content.sound = nil
            content.interruptionLevel = .passive
        }
        
        content.userInfo = [
            "payload": payload
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
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
