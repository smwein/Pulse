import Foundation

public actor FakeTransport: WatchSessionTransport {
    public struct Sent: Equatable, Sendable {
        public let message: WCMessage
        public let channel: WCChannel
    }

    public private(set) var sent: [Sent] = []
    public var reachable: Bool = false
    public var sendError: Error?

    public var isReachable: Bool { reachable }

    private let _incoming: AsyncStream<WCMessage>
    private let _continuation: AsyncStream<WCMessage>.Continuation

    public var incoming: AsyncStream<WCMessage> { _incoming }

    public init() {
        var cont: AsyncStream<WCMessage>.Continuation!
        _incoming = AsyncStream { cont = $0 }
        _continuation = cont
    }

    public func setReachable(_ v: Bool) { reachable = v }
    public func setSendError(_ e: Error?) { sendError = e }

    public func send(_ message: WCMessage, via channel: WCChannel) async throws {
        if let e = sendError { throw e }
        sent.append(Sent(message: message, channel: channel))
    }

    public func simulateIncoming(_ message: WCMessage) {
        _continuation.yield(message)
    }
}
