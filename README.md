# BlockSocket

This package gets bitcoin block information from a websocket server every time a new block is published. 
It is meant to be used as a block source for LDK. Currently only supports mainnet with the Blockchain.com websocket API as it's the only public API which provides the required information.

Work in progress, use at your own risk.

## Installation

Add this github repository https://github.com/bdgwallet/blocksocket-swift as a dependency in your Xcode project.   
You can then import and use the `BlockSocket` library in your Swift code.

```swift
import BlockSocket
```

## Setup

To initalise a BlockSocket you need to tell it what what `BlockSocketSource` it should connect to. The only supported option currently is `.blockchain_com`.

```swift
blockSocket = BlockSocket.init(source: BlockSocketSource.blockchain_com)
```

## Example

In this case the blockSocket is an @ObservedObject, which enables the WalletView to automatically update depending on .socketState and latest.block. The two files required:

**WalletApp.swift**
```swift
import SwiftUI
import BlockSocket

@main
struct WalletApp: App {
    @ObservedObject var blockSocket: BlockSocket
    
    init() {
        // Initialize BlockSocket
        blockSocket = BlockSocket.init(source: BlockSocketSource.blockchain_com)
    }
    
    var body: some Scene {
        WindowGroup {
            WalletView()
                .environmentObject(blockSocket)
        }
    }
}
```

**WalletView.swift**
```swift
import SwiftUI
import BlockSocket

struct WalletView: View {
    @EnvironmentObject var blockSocket: BlockSocket
    
    var body: some View {
        VStack (spacing: 50){
            Text("Hello, wallet!")
            switch blockSocket.socketState {
            case .connected:
                Text("Latest block: \(blockSocket.latestBlock?.height ?? 0)")
            case .disconnected:
                Text("BlockSocket not connected")
            }
        }.onDisappear {
            blockSocket.disconnect()
        }
    }
}
```

## Public functions

BlockSocket has the following public functions:
```swift
init(source: BlockSocketSource)
disconnect()
```

## Public variables

BDK Manager has the following `@Published` public variables, meaning they can be observed and lead to updates in SwiftUI:
```swift
.latestBlockHeight: UInt32?
.latestBlockHash: String?
.socketState: SocketState // .connected, .disconnected
```
