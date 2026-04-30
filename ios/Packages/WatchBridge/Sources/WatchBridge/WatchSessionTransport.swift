import Foundation

public enum WCChannel: Sendable, Equatable {
    case reliable   // transferUserInfo — queued, survives unreachability
    case live       // sendMessage — best-effort, requires reachability
}

public protocol WatchSessionTransport: Actor {
    var isReachable: Bool { get }
    var incoming: AsyncStream<WCMessage> { get }
    func send(_ message: WCMessage, via channel: WCChannel) async throws
}
