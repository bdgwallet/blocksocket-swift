//  Created by Daniel Nordh on 3/29/22.
//

import Foundation

public class BlockSocket: NSObject, ObservableObject {
    // Public variables
    //@Published public var latestBlock: Block?
    
    // Private variables
    private var webSocket: URLSessionWebSocketTask?
    private var urlString: String?
    private var opened = false
    private var pingTimer: Timer?
    
    // Initialize a BlockSocket instance
    public init(source: BlockSocketSource) {
        switch source.type {
        case .blockchain_com:
            self.urlString = BLOCKCHAIN_COM_URL
        case .mempool_space:
            self.urlString = MEMPOOL_SPACE_URL
        case .custom:
            if source.customUrl != nil {
                self.urlString = source.customUrl!
            } else {
                print("No custom URL provided")
            }
        }
    }
    
    public func connect() {
        if !opened {
            openWebSocket()
        }
        
        self.webSocket?.send(URLSessionWebSocketTask.Message.data("{ action: 'want', data: ['blocks'] }".data(using: .utf8)!))) { error in
            if let error = error {
                print("Failed with Error \(error.localizedDescription)")
            } else {
                self.receiveMessage()
                self.keepAlive()
            }
        }
    }
    
    private func receiveMessage() {
        self.webSocket?.receive(completionHandler: { result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let message):
                switch message {
                case .string(let messageString):
                    print(messageString)
                case .data(let data):
                    print(data.description)
                default:
                    print("Unknown type received from WebSocket")
                }
            }
            self.receiveMessage()
        })
    }
    
    private func openWebSocket() {
        if self.urlString != nil {
            if let url = URL(string: self.urlString!) {
                let request = URLRequest(url: url)
                let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
                self.webSocket = session.webSocketTask(with: request)
                self.webSocket?.resume()
                self.opened = true
            } else {
                self.webSocket = nil
            }
        }
    }
    
    public func disconnect() {
        self.pingTimer?.invalidate()
        self.webSocket?.cancel(with: .goingAway, reason: nil)
        self.webSocket = nil
        opened = false
    }
    
    private func keepAlive() {
        self.pingTimer = Timer.scheduledTimer(withTimeInterval: KEEPALIVE_INTERVAL, repeats: true) { timer in
            self.webSocket?.sendPing(pongReceiveHandler: { error in
                if let error = error {
                    print("Failed with Error \(error.localizedDescription)")
                } else {
                    self.receiveMessage()
                }
            })
        }
        self.pingTimer?.fire()
    }
}

// WebSocket delegate
extension BlockSocket: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.webSocket = nil
        self.opened = false
    }
}

// Helpers
public struct BlockSocketSource {
    public let type: BlockSocketSourceType
    public let customUrl: String?
    
    public init(type: BlockSocketSourceType, customUrl: String?) {
        self.type = type
        self.customUrl = customUrl
    }
}

public enum BlockSocketSourceType {
    case blockchain_com
    case mempool_space
    case custom
}

// Public API URLs
// TODO: Check if this is available for testnet
let BLOCKCHAIN_COM_URL = "wss://ws.blockchain.info/inv"
let MEMPOOL_SPACE_URL = "wss://mempool.space/api/v1/ws"

// Defaults
let KEEPALIVE_INTERVAL = 60.0
