//
//  TCPManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import Combine
import Network
import UserNotifications

@available(iOS 13.0, *)
public class TCPManager : ISocManager {
    let settings: Settings
    
    public init(settings: Settings) {
        self.settings = settings
    }
  
    public private(set) var connection: NWConnection?
    
    public override func connect() {
        if settings.user.uuid?.isEmpty ?? true {
            return
        }
        connect(settings: settings)
    }
    
    public override func connect(settings: Settings) {
        self.appKilled = settings.appKilled
        let tls = ConnectionOptions.TLS.Client(publicKeyHash: settings.pushManagerSettings.publicKey).options
        let parameters = NWParameters(tls: tls, tcp: ConnectionOptions.TCP.options)
        
        let port: Int = settings.pushManagerSettings.port ?? -1
        let host = settings.pushManagerSettings.host
        
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port))!, using: parameters)
        
        connection.betterPathUpdateHandler = { isBetterPathAvailable in
            print("A better path is available: \(isBetterPathAvailable)")
            
            guard isBetterPathAvailable else {
                return
            }
            self.disconnect()
        }
        
        dispatchQueue.async { [weak self] in
            guard let self = self, self.stateSubject.value == .disconnected else {
                return
            }
            
            self.stateSubject.send(.connecting)
            
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else {
                    return
                }
                
                switch state {
                case .waiting(let error):
                    print(error.debugDescription)
                    self.retry(after: self.retryInterval, error: error)
                case .ready:
                    self.stateSubject.send(.connected)
                    MessageManager.shared.showNotificationError(payload: "\(state)")
                    var messageInit:[String:Any] = [:]
                    messageInit["MessageType"] = "register"
                    messageInit["SendId"] = settings.uuid
                    messageInit["ReceiveId"] = ""
                    messageInit["DeviceId"] = settings.deviceId
                    if let messageJson = try? JSONSerialization.data(withJSONObject: messageInit){
                        let message = String(data: messageJson, encoding: .utf8)!
                        let data = message.data(using: .utf8)
                        self.connection?.send(content: data, completion: .contentProcessed({ error in
                            if let error = error {
                                print("Failed to send data: \(error)")
                                return
                            }
                            print("Data sent: \(message)")
                            self.receiveData()
                        }))
                    }
                case .failed(let error):
                    print(error.debugDescription)
                    self.disconnect()
                    self.retry(after: .seconds(5), error: error)
                case .cancelled:
                    self.stateSubject.send(.disconnected)
                    self.disconnect()
                default:
                    break
                }
            }
            
            connection.start(queue: self.dispatchQueue)
            
            self.connection = connection
        }
    }
    
    public override func disconnect() {
        dispatchQueue.async { [weak self] in
            guard let self = self, [.connecting, .connected].contains(self.stateSubject.value) else {
                return
            }
            
            print("Disconnect was called")
            
            self.stateSubject.send(.disconnecting)
            self.cancelRetry()
            self.connection?.cancel()
        }
    }
    
    // MARK: - Retry
    
    override func retry(after delay: DispatchTimeInterval, error: NWError?) {
        cancelRetry()
        
        guard let connection = connection else {
            return
        }
        
        switch error {
        case .posix(let code):
            print("POSIX Error Code - \(code)")
        case .tls(let code):
            print("TLS Error Code - \(code)")
        case .dns(let code):
            print("DNS Error Code - \(code)")
        default:
            print("Unknown error type encountered in \(#function)")
        }
        
        retryWorkItem = DispatchWorkItem {
            print("Retrying to connect with remote server...")
            connection.restart()
        }
        
        dispatchQueue.asyncAfter(deadline: .now() + delay, execute: retryWorkItem!)
    }
    
    override func cancelRetry() {
        guard let retryWorkItem = retryWorkItem else {
            return
        }
        
        retryWorkItem.cancel()
        self.retryWorkItem = nil
    }
    
    // MARK: - Receive
    
    override func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 3072) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let receivedMessage = String(data: data, encoding: .utf8)
                if let mess = receivedMessage {
                    DispatchQueue.main.async {
                        self.messageSubject.send(mess)
                    }
                }
            }
            if isComplete {
                print("Connection closed by the server")
            } else if let error = error {
                print("Error receiving data: \(error)")
            } else {
                self.receiveData()
            }
        }
    }
}
