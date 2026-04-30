import Foundation
import SwiftData
import Persistence

public struct WeeklyProgressStats: Equatable, Sendable {
    public let weekStart: Date
    public let completedSessionCount: Int
    public let completedMinutes: Int
    public let scheduledWorkoutCount: Int
    public let completedDates: [Date]
    public let streakDays: Int
    public let loggedSetCount: Int

    public init(weekStart: Date, completedSessionCount: Int, completedMinutes: Int,
                scheduledWorkoutCount: Int, completedDates: [Date], streakDays: Int,
                loggedSetCount: Int) {
        self.weekStart = weekStart
        self.completedSessionCount = completedSessionCount
        self.completedMinutes = completedMinutes
        self.scheduledWorkoutCount = scheduledWorkoutCount
        self.completedDates = completedDates
        self.streakDays = streakDays
        self.loggedSetCount = loggedSetCount
    }
}

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

    public func weeklyProgress(now: Date = Date(),
                               calendar: Calendar = Calendar(identifier: .iso8601))
                               throws -> WeeklyProgressStats {
        let cal = calendar
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        let ctx = modelContainer.mainContext

        let sessions = try ctx.fetch(FetchDescriptor<SessionEntity>())
        let completedThisWeek = sessions.filter { session in
            guard let completedAt = session.completedAt else { return false }
            return completedAt >= weekStart && completedAt < weekEnd
        }
        let completedMinutes = completedThisWeek.reduce(0) { total, session in
            total + ((session.durationSec ?? 0) / 60)
        }
        let completedSessionIDs = Set(completedThisWeek.map(\.id))
        let loggedSetCount = try ctx.fetch(FetchDescriptor<SetLogEntity>())
            .filter { completedSessionIDs.contains($0.sessionID) }
            .count

        let scheduledWorkouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor >= weekStart && $0.scheduledFor < weekEnd
                    && $0.status != "superseded"
            }
        ))

        let completedDays = Set(sessions.compactMap { session -> Date? in
            guard let completedAt = session.completedAt else { return nil }
            return cal.startOfDay(for: completedAt)
        })
        let completedDates = Array(Set(completedThisWeek.compactMap { session -> Date? in
            guard let completedAt = session.completedAt else { return nil }
            return cal.startOfDay(for: completedAt)
        })).sorted()

        return WeeklyProgressStats(
            weekStart: weekStart,
            completedSessionCount: completedThisWeek.count,
            completedMinutes: completedMinutes,
            scheduledWorkoutCount: scheduledWorkouts.count,
            completedDates: completedDates,
            streakDays: Self.streakDays(endingAt: now, completedDays: completedDays, calendar: cal),
            loggedSetCount: loggedSetCount
        )
    }

    private static func streakDays(endingAt now: Date, completedDays: Set<Date>,
                                   calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        if !completedDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
           completedDays.contains(yesterday) {
            day = yesterday
        }
        var streak = 0
        while completedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
