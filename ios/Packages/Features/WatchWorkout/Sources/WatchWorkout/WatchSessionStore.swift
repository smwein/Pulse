import Foundation
import Observation
import WatchBridge
import Logging

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

    private var loggedSetCounts: [String: Int] = [:]  // exerciseID → count
    private var loggedSetKeys: Set<String> = []

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
                                                        in: .userDomainMask)[0])) {
        self.transport = transport
        self.outbox = outbox
        self.factory = sessionFactory
        self.payloadStorage = payloadStorage
    }

    public func receivePayload(_ payload: WorkoutPayloadDTO) async {
        do {
            try payloadStorage.write(payload)
        } catch {
            PulseLogger.session.error("failed to persist payload", error)
        }
        self.payload = payload
        self.state = .ready
        self.loggedSetCounts = [:]
        self.loggedSetKeys = []
    }

    public func start() async throws {
        guard let payload else { return }
        // Idempotent: only `.ready` is a valid entry. Two quick taps must not
        // call the factory twice — a second factory failure would wipe the
        // success of the first.
        guard state == .ready else { return }
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
        markLogged(exerciseID: exID, setNum: setNum)
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

    public func receiveSetLog(_ log: SetLogDTO) async {
        guard payload?.sessionID == log.sessionID else { return }
        guard markLogged(exerciseID: log.exerciseID, setNum: log.setNum) else { return }
        if currentExerciseID == nil {
            state = .ended
            try? payloadStorage.clear()
        } else if state == .active {
            state = .resting(setNum: log.setNum, exerciseID: log.exerciseID)
        }
    }

    public func receiveLifecycle(_ event: LifecycleEvent) async {
        switch event {
        case .ended:
            state = .ended
            try? payloadStorage.clear()
        case .failed(let reason):
            state = .failed(reason: reason)
        case .started(let uuid):
            watchSessionUUID = uuid
        }
    }

    public func receiveAck(naturalKey: String) {
        do {
            try outbox.drain(naturalKey: naturalKey)
        } catch {
            PulseLogger.session.error("outbox drain failed", error)
        }
    }

    @discardableResult
    private func markLogged(exerciseID: String, setNum: Int) -> Bool {
        let key = "\(exerciseID)#\(setNum)"
        guard loggedSetKeys.insert(key).inserted else { return false }
        loggedSetCounts[exerciseID, default: 0] += 1
        return true
    }
}
