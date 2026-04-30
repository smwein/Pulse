import Foundation

public enum WCChannel: Sendable, Equatable {
    case reliable   // transferUserInfo — queued, survives unreachability
    case live       // sendMessage — best-effort, requires reachability
}

public protocol WatchSessionTransport: Actor {
    var isReachable: Bool { get }
    /// Whether successive accesses return the same stream or a fresh one is implementation-defined.
    /// `LiveWatchSessionTransport` fans out (one continuation per call); `FakeTransport` shares a
    /// single stream. Callers should attach at most one concurrent consumer.
    var incoming: AsyncStream<WCMessage> { get }
    func send(_ message: WCMessage, via channel: WCChannel) async throws
}
