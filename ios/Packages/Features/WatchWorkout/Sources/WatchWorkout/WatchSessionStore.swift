import Foundation
import Observation
import WatchBridge
import Logging
import HealthKitClient

public enum WatchSessionState: Equatable, Sendable {
    case idle
    case ready             // payload received, session not started
    case starting          // HKWorkoutSession start in flight
    case active            // session active, awaiting set confirmations
    case resting(setNum: Int, exerciseID: String)
    case ended
    case failed(reason: LifecycleEvent.FailureReason)
}

/// Indirection so tests don't need a real HKWorkoutSession.
public protocol WorkoutSessionFactory: Sendable {
    func startSession(activityKind: String) async throws -> UUID
    func endSession() async throws
    func recoverIfActive() async -> UUID?
}

@MainActor
@Observable
public final class WatchSessionStore {
    public private(set) var state: WatchSessionState = .idle
    public private(set) var payload: WorkoutPayloadDTO?
    public private(set) var watchSessionUUID: UUID?

    private let transport: any WatchSessionTransport
    private let outbox: SetLogOutbox
    private let factory: WorkoutSessionFactory
    private let payloadStorage: PayloadFileStorage
    private let authGate: HealthKitAuthGate?

    private var loggedSetCounts: [String: Int] = [:]  // exerciseID → count

    public var currentExerciseID: String? {
        guard let payload else { return nil }
        for ex in payload.exercises {
            let logged = loggedSetCounts[ex.exerciseID] ?? 0
            if logged < ex.sets.count { return ex.exerciseID }
        }
        return nil
    }

    public var currentSetNum: Int? {
        guard let id = currentExerciseID else { return nil }
        return (loggedSetCounts[id] ?? 0) + 1
    }

    public init(transport: any WatchSessionTransport,
                outbox: SetLogOutbox,
                sessionFactory: WorkoutSessionFactory,
                payloadStorage: PayloadFileStorage = PayloadFileStorage(
                    directory: FileManager.default.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask)[0]),
                authGate: HealthKitAuthGate? = nil) {
        self.transport = transport
        self.outbox = outbox
        self.factory = sessionFactory
        self.payloadStorage = payloadStorage
        self.authGate = authGate
    }

    public func receivePayload(_ payload: WorkoutPayloadDTO) async {
        do {
            try payloadStorage.write(payload)
        } catch {
            PulseLogger.session.error("failed to persist payload", error)
        }
        self.payload = payload
        self.state = .ready
    }

    public func start() async throws {
        guard let payload else { return }
        // Idempotent: only `.ready` is a valid entry. Two quick taps must not
        // call the factory twice — a second factory failure would wipe the
        // success of the first.
        guard state == .ready else { return }
        // JIT HealthKit auth — skip the gate entirely if no gate was injected.
        // Mirrors the phone-side TG11.1 pattern; reuses HealthKitAuthGate from
        // HealthKitClient instead of introducing a parallel protocol.
        if let authGate {
            var status = authGate.writeAuthorizationStatus()
            if status == .undetermined {
                try? await authGate.requestWriteAuthorization()
                status = authGate.writeAuthorizationStatus()
            }
            if status == .denied {
                state = .failed(reason: .healthKitDenied)
                // Terminal events route over .reliable for delivery guarantees,
                // matching the sessionStartFailed path below.
                try? await transport.send(
                    .sessionLifecycle(.failed(reason: .healthKitDenied)),
                    via: .reliable)
                throw NSError(domain: "WatchSessionStore", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "HealthKit write access denied"])
            }
        }
        state = .starting
        do {
            let uuid = try await factory.startSession(activityKind: payload.activityKind)
            watchSessionUUID = uuid
            state = .active
            try await transport.send(.sessionLifecycle(.started(watchSessionUUID: uuid)),
                                     via: .live)
        } catch {
            state = .failed(reason: .sessionStartFailed)
            // Terminal events route over .reliable so an unreachable phone
            // doesn't drop the failure signal — `.started` stays on .live for
            // low-latency happy-path UI.
            try? await transport.send(.sessionLifecycle(.failed(reason: .sessionStartFailed)),
                                      via: .reliable)
            throw error
        }
    }

    public func endSession() async throws {
        do {
            try await factory.endSession()
        } catch {
            PulseLogger.session.error("HKWorkoutSession.end failed", error)
        }
        state = .ended
        try? payloadStorage.clear()
        // Terminal event over .reliable — see start()'s failure path for rationale.
        try? await transport.send(.sessionLifecycle(.ended), via: .reliable)
    }

    public func confirmCurrentSet() async {
        guard let exID = currentExerciseID, let setNum = currentSetNum,
              let payload, let ex = payload.exercises.first(where: { $0.exerciseID == exID }),
              let prescription = ex.sets.first(where: { $0.setNum == setNum })
        else { return }
        let log = SetLogDTO(sessionID: payload.sessionID, exerciseID: exID, setNum: setNum,
                            reps: prescription.prescribedReps, load: prescription.prescribedLoad,
                            rpe: nil, loggedAt: Date())
        do { try outbox.enqueue(log) } catch {
            PulseLogger.session.error("outbox enqueue failed", error)
        }
        // Bump counter before the wire send so a re-entrant tap during the await
        // suspension can't double-log. Outbox is the source of truth either way.
        loggedSetCounts[exID, default: 0] += 1
        try? await transport.send(.setLog(log), via: .reliable)

        // Transition to rest unless this was the last set of the workout.
        if currentExerciseID == nil {
            // Last set logged — auto-end so the HK session doesn't leak when
            // the UI just renders "Done" with no further action.
            try? await endSession()
        } else {
            state = .resting(setNum: setNum, exerciseID: exID)
        }
    }

    public func advanceFromRest() async {
        guard case .resting = state else { return }
        if currentExerciseID == nil {
            state = .ended
        } else {
            state = .active
        }
    }

    /// On watch app relaunch: if a `HKWorkoutSession` is still active and a
    /// persisted payload exists, restore state to `.active` so the UI can
    /// resume the workout. No-op if either signal is missing.
    public func recoverIfActive() async {
        let recovered = await factory.recoverIfActive()
        let stored = (try? payloadStorage.read()) ?? nil
        guard let uuid = recovered, let payload = stored else { return }
        self.payload = payload
        self.watchSessionUUID = uuid
        self.state = .active
    }

    /// Replay any pending outbox entries when reachability is known to be good.
    /// Caller decides timing (e.g., on watch app relaunch). Idempotent — entries
    /// stay in the outbox until an `.ack` drains them.
    public func replayOutbox() async {
        guard await transport.isReachable else { return }
        let pending = (try? outbox.pending()) ?? []
        for log in pending {
            try? await transport.send(.setLog(log), via: .reliable)
        }
    }

    /// Long-lived: subscribes to `transport.incoming` and drains the outbox
    /// on `.ack`. Cancel via the wrapping Task on app teardown.
    /// Per `WatchSessionTransport` semantics, attach at most one consumer per
    /// transport — `LiveWatchSessionTransport` fans out separate streams,
    /// `FakeTransport` shares one.
    public func bridgeIncomingAcks() async {
        for await msg in await transport.incoming {
            if case .ack(let key) = msg {
                try? outbox.drain(naturalKey: key)
            }
        }
    }
}
