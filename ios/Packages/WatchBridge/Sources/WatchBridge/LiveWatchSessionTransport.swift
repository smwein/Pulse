import Foundation
import Logging
#if canImport(WatchConnectivity)
import WatchConnectivity

public actor LiveWatchSessionTransport: NSObject, WatchSessionTransport, WCSessionDelegate {
    // Continuations are appended on every `incoming` access and never removed on consumer
    // cancellation. Plan 5 attaches a single consumer for the app's lifetime; revisit if
    // that ever changes (use AsyncStream.onTermination to self-prune).
    private var continuations: [AsyncStream<WCMessage>.Continuation] = []
    private let session: WCSession

    public var isReachable: Bool { session.isReachable }
    public var incoming: AsyncStream<WCMessage> {
        AsyncStream { cont in continuations.append(cont) }
    }

    public init(session: WCSession = .default) {
        self.session = session
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    public func send(_ message: WCMessage, via channel: WCChannel) async throws {
        let userInfo = try message.asUserInfo()
        switch channel {
        case .reliable:
            session.transferUserInfo(userInfo)
        case .live:
            guard session.isReachable else {
                // Live channel requires reachability; fall back to reliable.
                session.transferUserInfo(userInfo); return
            }
            session.sendMessage(userInfo, replyHandler: nil) { error in
                PulseLogger.bridge.error("sendMessage failed", error)
            }
        }
    }

    private func dispatch(_ msg: WCMessage) {
        for c in continuations { c.yield(msg) }
    }

    // MARK: WCSessionDelegate
    public nonisolated func session(_ session: WCSession,
                                    activationDidCompleteWith state: WCSessionActivationState,
                                    error: Error?) {
        if let error { PulseLogger.bridge.error("WCSession activation failed", error) }
    }
    public nonisolated func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any] = [:]) {
        do {
            let msg = try WCMessage(userInfo: userInfo)
            Task { await self.dispatch(msg) }
        } catch {
            PulseLogger.bridge.error("WCMessage decode failed", error)
        }
    }
    public nonisolated func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        do {
            let msg = try WCMessage(userInfo: message)
            Task { await self.dispatch(msg) }
        } catch {
            PulseLogger.bridge.error("WCMessage decode failed", error)
        }
    }
    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
