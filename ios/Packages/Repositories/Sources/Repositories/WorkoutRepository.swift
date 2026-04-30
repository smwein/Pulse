import Foundation
import SwiftData
import Persistence

@MainActor
public final class WorkoutRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func todaysWorkout(now: Date = Date(),
                              calendar: Calendar = Calendar(identifier: .iso8601))
                              throws -> WorkoutEntity? {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
                    && $0.status != "superseded"
            },
            sortBy: [SortDescriptor(\.scheduledFor, order: .forward)]
        )
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    public func markCompleted(workoutID: UUID) throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutID }
        )
        guard let w = try ctx.fetch(descriptor).first else { return }
        w.status = "completed"
        try ctx.save()
    }

    /// Returns the most recently scheduled Workout, excluding superseded rows.
    public func latestWorkout() throws -> WorkoutEntity? {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.status != "superseded" },
            sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    /// Returns the next non-superseded scheduled Workout strictly after `after`.
    /// Used by the adaptation flow to find what to replace, since the next
    /// scheduled session isn't always literal-tomorrow.
    public func nextScheduledWorkout(after: Date) throws -> WorkoutEntity? {
        let cutoff = after
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor > cutoff && $0.status != "superseded"
            },
            sortBy: [SortDescriptor(\.scheduledFor, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    public func workoutForDate(_ date: Date,
                               calendar: Calendar = Calendar(identifier: .iso8601))
                               throws -> WorkoutEntity? {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
                    && $0.status != "superseded"
            },
            sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
        )
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    public func deleteWorkout(id: UUID) throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )
        for w in try ctx.fetch(descriptor) {
            ctx.delete(w)
        }
        try ctx.save()
    }

    public func workoutForID(_ id: UUID) throws -> WorkoutEntity? {
        let ctx = modelContainer.mainContext
        let target = id
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == target }
        )
        return try ctx.fetch(descriptor).first
    }
}
