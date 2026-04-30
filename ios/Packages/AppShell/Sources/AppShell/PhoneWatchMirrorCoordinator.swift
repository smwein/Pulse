import Foundation
import Logging
import Persistence
import Repositories
import SwiftData
import WatchBridge

@MainActor
public final class PhoneWatchMirrorCoordinator {
    private let transport: any WatchSessionTransport
    private let sessionRepo: SessionRepository
    private let onWatchEndedSession: (UUID) -> Void
    private var task: Task<Void, Never>?

    public init(transport: any WatchSessionTransport,
                modelContainer: ModelContainer,
                onWatchEndedSession: @escaping (UUID) -> Void = { _ in }) {
        self.transport = transport
        self.sessionRepo = SessionRepository(modelContainer: modelContainer)
        self.onWatchEndedSession = onWatchEndedSession
    }

    deinit {
        task?.cancel()
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [transport] in
            for await message in await transport.incoming {
                await handle(message)
            }
        }
    }

    public func handle(_ message: WCMessage) async {
        switch message {
        case .setLog(let log):
            do {
                try sessionRepo.logSet(sessionID: log.sessionID,
                                       exerciseID: log.exerciseID,
                                       setNum: log.setNum,
                                       reps: log.reps,
                                       load: log.load,
                                       rpe: log.rpe ?? 0,
                                       now: log.loggedAt)
                try? await transport.send(.ack(naturalKey: log.naturalKey), via: .reliable)
            } catch {
                PulseLogger.bridge.error("watch set log persist failed", error)
            }
        case .sessionLifecycle(.started(let watchSessionUUID)):
            do {
                if let session = try sessionRepo.orphanedInProgressSession() {
                    try sessionRepo.attachWatchSession(watchSessionUUID, to: session.id)
                }
            } catch {
                PulseLogger.bridge.error("watch session attach failed", error)
            }
        case .sessionLifecycle(.ended):
            do {
                if let session = try sessionRepo.orphanedInProgressSession() {
                    try sessionRepo.finish(sessionID: session.id)
                    onWatchEndedSession(session.id)
                }
            } catch {
                PulseLogger.bridge.error("watch session finish failed", error)
            }
        case .sessionLifecycle(.failed(let reason)):
            PulseLogger.bridge.info("watch session failed: \(reason.rawValue)")
        case .workoutPayload, .ack:
            break
        }
    }
}
