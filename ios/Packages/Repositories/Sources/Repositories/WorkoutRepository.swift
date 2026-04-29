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
                              calendar: Calendar = Calendar(identifier: .gregorian))
                              throws -> WorkoutEntity? {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
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

    /// Returns the most recently scheduled Workout, regardless of date.
    public func latestWorkout() throws -> WorkoutEntity? {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
        )
        descriptor.fetchLimit = 1
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
