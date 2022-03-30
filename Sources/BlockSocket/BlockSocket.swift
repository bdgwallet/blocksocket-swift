//
//  BlockSocket.swift
//
//  Created by Daniel Nordh on 3/29/22.
//

import Foundation
import Starscream

public class BlockSocket: ObservableObject, WebSocketDelegate {
    // Public variables
    @Published public var latestBlock: SocketBlock?
    
    // Private variables
    private var socket: WebSocket
    private var source: BlockSocketSource
    private var isConnected = false
    private var pingTimer: Timer?
    
    // Initialize, connect to websocket source, get latest block and subscribe to new blocks
    public init(source: BlockSocketSource) {
        self.source = source
        let urlString = source == BlockSocketSource.blockchain_com ? BLOCKCHAIN_COM_URL : MEMPOOL_SPACE_URL
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 5
        self.socket = WebSocket(request: request)
        self.socket.delegate = self
        self.socket.connect()
    }
    
    // Unsubscribe to new blocks and disconnect websocket source
    public func disconnect() {
        if isConnected {
            self.unsubscribeToBlocks()
            self.socket.disconnect()
        }
    }
    
    // Handle websocket events
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            isConnected = true
            print("BlockSocket connected")
            self.getLatestBlock()
            self.subscribeToBlocks()
        case .disconnected(let reason, let code):
            isConnected = false
            print("BlockSocket disconnected: \(reason) with code: \(code)")
        case .text(let string):
            switch self.source {
            case .blockchain_com:
                handleBlockchain_com(response: string)
            }
        case .reconnectSuggested(_):
            self.socket.connect()
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            handleError(error)
        default:
            break
        }
    }
    
    // Send message to get most recently mined block
    private func getLatestBlock() {
        switch self.source {
        case .blockchain_com:
            sendMessage(message: BLOCKCHAIN_COM_MSG_BLOCKLATEST)
        }
    }
    
    // Send message to subscribe to future blocks
    private func subscribeToBlocks() {
        switch self.source {
        case .blockchain_com:
            sendMessage(message: BLOCKCHAIN_COM_MSG_BLOCKSUB)
        }
    }
    
    // Send message to unsubscribe from future blocks
    private func unsubscribeToBlocks() {
        switch self.source {
        case .blockchain_com:
            sendMessage(message: BLOCKCHAIN_COM_MSG_BLOCKUNSUB)
        }
    }
    
    // Send a message to websocket
    private func sendMessage(message: [String:Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            if let dataString = String(data: data, encoding: .utf8){
                self.socket.write(string: dataString)
            }
        } catch {
            print("Failed to send message: ", error)
        }
    }
    
    // Handle response from Blockchain.com websocket API that includes a block
    private func handleBlockchain_com(response: String) {
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: Data(response.utf8), options: []) as? [String: Any]
            let op: String = jsonArray!["op"] != nil ? jsonArray!["op"] as! String : ""
            if op == "block" {
                let blockInfo = jsonArray!["x"] as! [String:Any]
                self.getBlockInfoBlockchain_com(blockInfo: blockInfo)
            } else {
                print("Received non block op: \(op)")
            }
        } catch let error {
            print(error)
        }
    }
    
    // Convert blockinfo from Blockchain.com to SocketBlock and set as latest
    private func getBlockInfoBlockchain_com(blockInfo: [String:Any]) {
        let blockHeight = blockInfo["height"] as! Int
        let blockHash = blockInfo["hash"] as! String
        self.latestBlock = SocketBlock(height: blockHeight, hash: blockHash)
    }
    
    // Handle websocket errors
    private func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
}

// Helpers
public enum BlockSocketSource {
    case blockchain_com
    //case mempool_space // Ignore for now, does not provide latest block, only next one
}

public struct SocketBlock: Codable {
    let height: Int
    let hash: String
}

// Public API URLs
// TODO: Check if any are available for testnet
let BLOCKCHAIN_COM_URL = "wss://ws.blockchain.info/inv"
let MEMPOOL_SPACE_URL = "wss://mempool.space/api/v1/ws"

let BLOCKCHAIN_COM_MSG_BLOCKLATEST = ["op" : "ping_block"]
let BLOCKCHAIN_COM_MSG_BLOCKSUB = ["op" : "blocks_sub"]
let BLOCKCHAIN_COM_MSG_BLOCKUNSUB = ["op" : "blocks_unsub"]

let MEMPOOL_SPACE_MSG_BLOCKSUB: [String:Any] = ["action" : "want", "data" : ["blocks"]]
