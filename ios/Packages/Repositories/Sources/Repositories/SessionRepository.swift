import Foundation
import SwiftData
import CoreModels
import Persistence

@MainActor
public final class SessionRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @discardableResult
    public func start(workoutID: UUID, now: Date = Date()) throws -> SessionEntity {
        let ctx = modelContainer.mainContext
        var session: SessionEntity!
        try ctx.atomicWrite {
            let target = workoutID
            let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == target }))
            guard let workout = workouts.first else {
                throw SessionRepositoryError.workoutNotFound(workoutID)
            }
            workout.status = "in_progress"
            session = SessionEntity(id: UUID(), workoutID: workoutID, startedAt: now)
            ctx.insert(session)
        }
        return session
    }

    public func logSet(sessionID: UUID, exerciseID: String, setNum: Int,
                       reps: Int, load: String, rpe: Int, now: Date = Date()) throws {
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let sid = sessionID
            let exid = exerciseID
            let n = setNum
            let existing = try ctx.fetch(FetchDescriptor<SetLogEntity>(
                predicate: #Predicate {
                    $0.sessionID == sid && $0.exerciseID == exid && $0.setNum == n
                })).first
            if let row = existing {
                row.reps = reps
                row.load = load
                row.rpe = rpe
                row.loggedAt = now
            } else {
                // Need parent session for cascade-delete relationship.
                let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                    predicate: #Predicate { $0.id == sid })).first
                ctx.insert(SetLogEntity(sessionID: sid, exerciseID: exid,
                    setNum: n, reps: reps, load: load, rpe: rpe,
                    loggedAt: now, session: session))
            }
        }
    }

    public func finish(sessionID: UUID, now: Date = Date()) throws {
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let sid = sessionID
            guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first else {
                throw SessionRepositoryError.sessionNotFound(sid)
            }
            session.completedAt = now
            session.durationSec = Int(now.timeIntervalSince(session.startedAt))
            let workoutID = session.workoutID
            if let w = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == workoutID })).first {
                w.status = "completed"
            }
        }
    }

    public func discardSession(id: UUID) throws {
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let sid = id
            guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first else {
                return
            }
            let workoutID = session.workoutID
            // Cascade delete via SwiftData relationship handles SetLogEntity rows.
            ctx.delete(session)
            if let w = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == workoutID })).first {
                w.status = "scheduled"
            }
        }
    }

    /// Records the Watch-side session UUID on the local SessionEntity.
    /// Used by the WCSession bridge when a `.sessionLifecycle(.started)` arrives.
    public func setWatchSessionUUID(sessionID: UUID, watchSessionUUID: UUID) throws {
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let sid = sessionID
            guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first else {
                throw SessionRepositoryError.sessionNotFound(sid)
            }
            session.watchSessionUUID = watchSessionUUID
        }
    }

    /// Returns any in-progress session whose Workout is still flagged "in_progress".
    /// Used by `FirstRunGate` to detect orphaned sessions on relaunch.
    public func orphanedInProgressSession() throws -> SessionEntity? {
        let ctx = modelContainer.mainContext
        let sessions = try ctx.fetch(FetchDescriptor<SessionEntity>())
        return sessions.first(where: { $0.completedAt == nil })
    }
}

public enum SessionRepositoryError: Error, Equatable {
    case workoutNotFound(UUID)
    case sessionNotFound(UUID)
}
