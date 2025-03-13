//
//  WebSocketManager.swift
//  local_push_connectivity
//
//  Created by Ho Doan on 12/2/24.
//

import Foundation
import Network
import UserNotifications

@available(iOS 13.0, macOS 12, *)
class WebSocketManager : ISocManager {
    
    let settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    public private(set) var connection: URLSessionWebSocketTask?
    
    public override func connect() {
        if settings.user.uuid?.isEmpty ?? true {
            self.retry(after: .seconds(4), error: nil)
            return
        }
        connect(settings: settings)
    }
    
    public override func connect(settings: Settings) {
        print("======== ws connecting")
        self.appKilled = settings.appKilled
        
        let port: Int = settings.pushManagerSettings.port ?? -1
        let host = settings.pushManagerSettings.host
        
        let url = URL(string: "\(settings.pushManagerSettings.wss ? "wss" : "ws")://\(host):\(port)\(settings.pushManagerSettings.part)")!
        
        print("======== ws connecting \(url)")
        self.state = .connecting
        
        let urlSession = URLSession(configuration: .default)
        let urlRequest = URLRequest(url: url, timeoutInterval: 30)
        
        if #available(iOS 13.0, *) {
            connection = urlSession.webSocketTask(with: urlRequest)
            connection!.resume()
            self.state = .connected
        }
        
        print("======== ws connected")
        var messageInit:[String:Any] = [:]
        messageInit["MessageType"] = "register"
        messageInit["SendId"] = settings.uuid
        messageInit["ReceiveId"] = ""
        messageInit["DeviceId"] = settings.deviceId
        if let messageJson = try? JSONSerialization.data(withJSONObject: messageInit){
            let message = String(data: messageJson, encoding: .utf8)!
            if #available(iOS 13.0, *) {
                let data = URLSessionWebSocketTask.Message.string(message)
                self.connection?.send(data){ error in
                    if let error = error {
                        print("Failed to send data: \(error)")
                        return
                    }
                    print("Data sent: \(message)")
                    self.receiveData()
                }
            }
        }
    }
    
    public override func disconnect() {
        dispatchQueue.async { [weak self] in
            guard let self = self, [.connecting, .connected].contains(self.state) else {
                return
            }
            
            print("Disconnect was called")
            
            self.state = .disconnecting
            self.cancelRetry()
            self.connection?.cancel()
            self.state = .disconnected
        }
    }
    
    // MARK: - Retry
    
    override func retry(after delay: DispatchTimeInterval, error: NWError?) {
        retryWorkItem = DispatchWorkItem {
            print("Retrying to connect with remote server...")
            self.connect()
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
        print("Received string...")
        if #available(iOS 13.0, *) {
            self.connection!.receive(completionHandler: { [weak self] result in
                switch result {
                    case .failure(let error):
                        print("===ws err: \(error.localizedDescription)")
                        self?.disconnect()
                        self?.retry(after: .seconds(5), error: nil)
                    case .success(let message):
                        switch message {
                            case .string(let text):
                                print("Received string: \(text) \(self == nil)")
                                DispatchQueue.main.async {
                                    self?.showNotification(payload: text)
                                    
                                    self?.receiveData()
                                }
                            case .data(let data):
                                print("Received data: \(data) \(self == nil)")
                                let receivedMessage = String(data: data, encoding: .utf8)
                                if let mess = receivedMessage {
                                    DispatchQueue.main.async {
                                        self?.showNotification(payload: mess)
                                    }
                                }
                            @unknown default:
                                print("===ws err: \(result)")
                                fatalError()
                        }
                }
            })
        }
    }
}
