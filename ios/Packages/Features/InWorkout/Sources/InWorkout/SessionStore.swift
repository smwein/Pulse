import Foundation
import Observation
import CoreModels
import Persistence
import Repositories
import SwiftData

@MainActor
@Observable
public final class SessionStore {
    public enum Phase: Sendable { case work, rest }
    public enum Lifecycle: Sendable, Equatable {
        case completed(UUID)
        case discarded
        case failed(String)
    }

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

    public var onLifecycle: (Lifecycle) -> Void = { _ in }

    private let repo: SessionRepository?

    /// Test-only: skip persistence.
    public static func preview(flat: [FlatEntry]) -> SessionStore {
        SessionStore(workoutID: UUID(), flat: flat, repo: nil)
    }

    public init(workoutID: UUID, flat: [FlatEntry], repo: SessionRepository?) {
        self.workoutID = workoutID
        self.flat = flat
        self.repo = repo
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
                restoreProgress(from: session)
            } catch {
                onLifecycle(.failed("Couldn't start this workout. Please try again."))
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
            onLifecycle(.completed(sessionID))
        } else {
            onLifecycle(.completed(UUID()))
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

    private func restoreProgress(from session: SessionEntity) {
        let logged = session.setLogs
        guard !logged.isEmpty else { return }
        let completedKeys = Set(logged.map { "\($0.exerciseID)#\($0.setNum)" })
        if let nextIndex = flat.firstIndex(where: { !completedKeys.contains("\($0.exerciseID)#\($0.setNum)") }) {
            idx = nextIndex
            phase = .work
            secs = 0
            let next = flat[nextIndex]
            draft = Draft(reps: next.prescribedReps, load: next.prescribedLoad, rpe: 0)
        } else {
            idx = max(flat.count - 1, 0)
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
