import Foundation
import Observation
import CoreModels
import HealthKitClient
import Logging
import Persistence
import Repositories
import SwiftData
import WatchBridge

@MainActor
@Observable
public final class SessionStore {
    public enum Phase: Sendable { case work, rest }
    public enum Lifecycle: Sendable { case completed(SessionEntity), discarded }

    public struct FlatEntry: Hashable, Sendable {
        public let blockLabel: String
        public let exerciseID: String
        public let exerciseName: String
        public let setNum: Int
        public let prescribedReps: Int
        public let prescribedLoad: String
        public let restSec: Int

        public init(blockLabel: String, exerciseID: String, exerciseName: String,
                    setNum: Int, prescribedReps: Int, prescribedLoad: String, restSec: Int) {
            self.blockLabel = blockLabel
            self.exerciseID = exerciseID
            self.exerciseName = exerciseName
            self.setNum = setNum
            self.prescribedReps = prescribedReps
            self.prescribedLoad = prescribedLoad
            self.restSec = restSec
        }
    }

    public struct Draft: Sendable {
        public var reps: Int
        public var load: String
        public var rpe: Int   // 0 = unset, 1-10 = user-set
    }

    public private(set) var workoutID: UUID
    public private(set) var sessionID: UUID?
    public private(set) var flat: [FlatEntry]
    public private(set) var idx: Int = 0
    public private(set) var phase: Phase = .work
    public private(set) var secs: Int = 0
    public var draft: Draft

    // Watch bridge surface — observed by InWorkoutView to react to lifecycle.
    public private(set) var watchSessionUUID: UUID?
    public private(set) var watchSessionEnded: Bool = false
    public private(set) var watchFailureReason: LifecycleEvent.FailureReason?

    public var onLifecycle: (Lifecycle) -> Void = { _ in }

    private let repo: SessionRepository?
    private let authGate: HealthKitAuthGate?

    /// Test-only: skip persistence.
    public static func preview(flat: [FlatEntry]) -> SessionStore {
        SessionStore(workoutID: UUID(), flat: flat, repo: nil)
    }

    public init(workoutID: UUID, flat: [FlatEntry], repo: SessionRepository?,
                authGate: HealthKitAuthGate? = nil) {
        self.workoutID = workoutID
        self.flat = flat
        self.repo = repo
        self.authGate = authGate
        let first = flat.first
        self.draft = Draft(reps: first?.prescribedReps ?? 0,
                           load: first?.prescribedLoad ?? "",
                           rpe: 0)
    }

    public var current: FlatEntry? { flat.indices.contains(idx) ? flat[idx] : nil }
    public var isLastSet: Bool { idx == flat.count - 1 }

    public func start() async {
        if let repo {
            do {
                let session = try repo.start(workoutID: workoutID)
                sessionID = session.id
            } catch {
                // Surface via lifecycle? For Plan 4, log + drop silently.
            }
        }
    }

    public func logCurrentSet() async {
        guard let cur = current else { return }
        if let sessionID, let repo {
            try? repo.logSet(sessionID: sessionID,
                             exerciseID: cur.exerciseID,
                             setNum: cur.setNum,
                             reps: draft.reps,
                             load: draft.load,
                             rpe: draft.rpe)
        }
        if isLastSet {
            await finish()
            return
        }
        idx += 1
        if let next = current {
            draft = Draft(reps: next.prescribedReps,
                          load: next.prescribedLoad,
                          rpe: 0)
        }
        phase = .rest
        secs = 0
    }

    public func tick(by deltaSec: Int) {
        guard phase == .rest else { return }
        secs += deltaSec
        if let cur = current, secs >= cur.restSec {
            phase = .work
            secs = 0
        }
    }

    public func finish() async {
        if let sessionID, let repo {
            try? repo.finish(sessionID: sessionID)
            let dummy = SessionEntity(id: sessionID, workoutID: workoutID,
                                      startedAt: Date())
            onLifecycle(.completed(dummy))
        } else {
            let dummy = SessionEntity(id: UUID(), workoutID: workoutID,
                                      startedAt: Date())
            onLifecycle(.completed(dummy))
        }
    }

    public func discard() async {
        if let sessionID, let repo {
            try? repo.discardSession(id: sessionID)
        }
        idx = 0
        phase = .work
        secs = 0
        if let first = flat.first {
            draft = Draft(reps: first.prescribedReps,
                          load: first.prescribedLoad, rpe: 0)
        }
        onLifecycle(.discarded)
    }
}

extension SessionStore {
    /// Long-lived task: subscribes to `transport.incoming` and dispatches each
    /// message to the appropriate handler. Caller is responsible for cancelling
    /// the returned `Task` on session end.
    public func bridgeIncoming(transport: any WatchSessionTransport) async {
        for await msg in await transport.incoming {
            switch msg {
            case .setLog(let dto):
                await applyRemoteSetLog(dto)
                try? await transport.send(.ack(naturalKey: dto.naturalKey), via: .live)
            case .sessionLifecycle(.started(let uuid)):
                self.watchSessionUUID = uuid
                if let sid = sessionID, let repo {
                    try? repo.setWatchSessionUUID(sessionID: sid, watchSessionUUID: uuid)
                }
            case .sessionLifecycle(.ended):
                self.watchSessionEnded = true
            case .sessionLifecycle(.failed(let r)):
                PulseLogger.session.error("watch lifecycle failed: \(r.rawValue)")
                self.watchFailureReason = r
                if r == .healthKitDenied {
                    // Surface to Home banner — Home reads this key.
                    UserDefaults.standard.set(true, forKey: SharedDefaultsKeys.watchHKDeniedBanner)
                    // Reset the dismiss flag so the banner shows up again on a fresh denial.
                    UserDefaults.standard.set(false, forKey: SharedDefaultsKeys.watchHKDeniedBannerDismissed)
                }
            case .ack, .workoutPayload:
                break
            }
        }
    }

    /// Starts the local session and, if the Watch is reachable, pushes the
    /// workout payload via `transferUserInfo` (reliable channel). When
    /// unreachable, falls through to the Plan 4 no-Watch path silently.
    public func startWithWatch(transport: any WatchSessionTransport) async {
        // Reset stale Watch state so a previous session's terminal flags don't
        // poison the new one.
        watchSessionUUID = nil
        watchSessionEnded = false
        watchFailureReason = nil
        // JIT HealthKit write-auth: only request if the user hasn't seen the
        // prompt yet. .denied stays denied; .authorized skips the prompt.
        if let authGate, authGate.writeAuthorizationStatus() == .undetermined {
            try? await authGate.requestWriteAuthorization()
        }
        await self.start()
        guard await transport.isReachable else { return }
        guard let payload = currentPayload() else { return }
        try? await transport.send(.workoutPayload(payload), via: .reliable)
    }

    /// Builds a `WorkoutPayloadDTO` from the in-flight session's flattened entries.
    /// Groups consecutive `FlatEntry` rows by `exerciseID`, preserving first-occurrence
    /// order. Note: this codebase doesn't carry the workout title or activity kind
    /// through to `SessionStore`; hardcoded placeholders are used (forward-flag).
    private func currentPayload() -> WorkoutPayloadDTO? {
        guard let sid = sessionID else { return nil }
        var byExercise: [(id: String, name: String, sets: [WorkoutPayloadDTO.SetPrescription])] = []
        for entry in flat {
            if let i = byExercise.firstIndex(where: { $0.id == entry.exerciseID }) {
                byExercise[i].sets.append(.init(setNum: entry.setNum,
                    prescribedReps: entry.prescribedReps,
                    prescribedLoad: entry.prescribedLoad))
            } else {
                byExercise.append((id: entry.exerciseID, name: entry.exerciseName,
                    sets: [.init(setNum: entry.setNum,
                                 prescribedReps: entry.prescribedReps,
                                 prescribedLoad: entry.prescribedLoad)]))
            }
        }
        let exercises = byExercise.map {
            WorkoutPayloadDTO.Exercise(exerciseID: $0.id, name: $0.name, sets: $0.sets)
        }
        return WorkoutPayloadDTO(sessionID: sid, workoutID: workoutID,
                                 title: "Workout",
                                 activityKind: "traditionalStrengthTraining",
                                 exercises: exercises)
    }

    /// Forwards a remote set log (originated from the Watch) to the repository.
    /// Idempotency is provided by `SessionRepository.logSet`'s upsert key
    /// (sessionID, exerciseID, setNum) — two identical applies result in one row.
    public func applyRemoteSetLog(_ dto: SetLogDTO) async {
        guard let repo else { return }
        do {
            try repo.logSet(sessionID: dto.sessionID,
                            exerciseID: dto.exerciseID,
                            setNum: dto.setNum,
                            reps: dto.reps,
                            load: dto.load,
                            rpe: dto.rpe ?? 0,
                            now: dto.loggedAt)
        } catch {
            PulseLogger.session.error("applyRemoteSetLog failed", error)
        }
    }
}

public extension SessionStore {
    static func flatten(workout: WorkoutEntity) -> [FlatEntry] {
        guard let blocks = try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: workout.blocksJSON) else {
            return []
        }
        var out: [FlatEntry] = []
        for block in blocks {
            for ex in block.exercises {
                for set in ex.sets {
                    out.append(.init(blockLabel: block.label,
                                     exerciseID: ex.exerciseID,
                                     exerciseName: ex.name,
                                     setNum: set.setNum,
                                     prescribedReps: set.reps,
                                     prescribedLoad: set.load,
                                     restSec: set.restSec))
                }
            }
        }
        return out
    }
}
