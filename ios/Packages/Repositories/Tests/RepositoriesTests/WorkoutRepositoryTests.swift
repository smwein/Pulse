import XCTest
import SwiftData
import Persistence
@testable import Repositories

final class WorkoutRepositoryTests: XCTestCase {
    @MainActor
    func test_todaysWorkoutReturnsScheduledForToday() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        for date in [yesterday, today, tomorrow] {
            ctx.insert(WorkoutEntity(
                id: UUID(),
                planID: UUID(),
                scheduledFor: date,
                title: "T\(date.timeIntervalSince1970)",
                subtitle: "",
                workoutType: "Strength",
                durationMin: 30,
                status: "scheduled",
                blocksJSON: Data("[]".utf8),
                exercisesJSON: Data("[]".utf8)
            ))
        }
        try ctx.save()

        let repo = WorkoutRepository(modelContainer: container)
        let result = try repo.todaysWorkout(now: today.addingTimeInterval(60 * 60 * 4))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title.hasPrefix("T\(today.timeIntervalSince1970)"), true)
    }

    @MainActor
    func test_markCompletedUpdatesStatus() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(),
            planID: UUID(),
            scheduledFor: Date(),
            title: "x",
            subtitle: "",
            workoutType: "Strength",
            durationMin: 30,
            status: "scheduled",
            blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)
        )
        ctx.insert(w); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        try repo.markCompleted(workoutID: w.id)
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(fetched?.status, "completed")
    }

    @MainActor
    func test_latestWorkout_returnsMostRecentByScheduledFor() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let older = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
            title: "A", subtitle: "", workoutType: "Strength", durationMin: 30,
            status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        let newer = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
            title: "B", subtitle: "", workoutType: "Strength", durationMin: 45,
            status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(older); ctx.insert(newer); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        let latest = try repo.latestWorkout()
        XCTAssertEqual(latest?.title, "B")
    }

    @MainActor
    func test_latestWorkout_returnsNilWhenEmpty() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = WorkoutRepository(modelContainer: container)
        XCTAssertNil(try repo.latestWorkout())
    }

    @MainActor
    func test_deleteWorkout_removesByID() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let id = UUID()
        let w = WorkoutEntity(id: id, planID: UUID(),
            scheduledFor: Date(), title: "A", subtitle: "",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(w); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        try repo.deleteWorkout(id: id)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).count, 0)
    }

    @MainActor
    func test_workoutForID_returnsMatchingRow() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let id = UUID()
        ctx.insert(WorkoutEntity(id: id, planID: UUID(),
            scheduledFor: Date(), title: "Find me", subtitle: "",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        XCTAssertEqual(try repo.workoutForID(id)?.title, "Find me")
        XCTAssertNil(try repo.workoutForID(UUID()))
    }

    @MainActor
    func test_latestWorkout_filtersSuperseded() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_730_000_000)
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: oldDate,
            title: "Keep", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: newDate,
            title: "Hide", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "superseded",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        let latest = try repo.latestWorkout()
        XCTAssertEqual(latest?.title, "Keep")
    }

    @MainActor
    func test_workoutForDate_filtersSupersededAndPicksLatestNonSupersedeed() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = iso.startOfDay(for: Date(timeIntervalSince1970: 1_730_000_000))
        let earlier = day.addingTimeInterval(3_600)
        let later   = day.addingTimeInterval(7_200)
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: earlier,
            title: "Old", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "superseded",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: later,
            title: "New", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        XCTAssertEqual(try repo.workoutForDate(day)?.title, "New")
    }

    @MainActor
    func test_weeklyProgress_countsCompletedSessionsMinutesSetsAndScheduledWorkouts() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-04-30T12:00:00Z")!
        let weekStart = iso.dateInterval(of: .weekOfYear, for: now)!.start
        let workoutID = UUID()
        ctx.insert(WorkoutEntity(id: workoutID, planID: UUID(),
            scheduledFor: weekStart.addingTimeInterval(86_400),
            title: "A", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "completed",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: weekStart.addingTimeInterval(2 * 86_400),
            title: "B", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: weekStart.addingTimeInterval(3 * 86_400),
            title: "Hide", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "superseded",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))

        let sessionID = UUID()
        let session = SessionEntity(
            id: sessionID,
            workoutID: workoutID,
            startedAt: weekStart.addingTimeInterval(86_400),
            completedAt: weekStart.addingTimeInterval(86_400 + 2_700),
            durationSec: 2_700
        )
        ctx.insert(session)
        ctx.insert(SetLogEntity(sessionID: sessionID, exerciseID: "push-up",
                                setNum: 1, reps: 10, load: "BW", rpe: 7,
                                loggedAt: now, session: session))
        ctx.insert(SetLogEntity(sessionID: sessionID, exerciseID: "push-up",
                                setNum: 2, reps: 10, load: "BW", rpe: 8,
                                loggedAt: now, session: session))
        try ctx.save()

        let stats = try WorkoutRepository(modelContainer: container)
            .weeklyProgress(now: now, calendar: iso)

        XCTAssertEqual(stats.weekStart, weekStart)
        XCTAssertEqual(stats.completedSessionCount, 1)
        XCTAssertEqual(stats.completedMinutes, 45)
        XCTAssertEqual(stats.scheduledWorkoutCount, 2)
        XCTAssertEqual(stats.loggedSetCount, 2)
        XCTAssertEqual(stats.completedDates, [iso.startOfDay(for: session.completedAt!)])
    }

    @MainActor
    func test_weeklyProgress_streakContinuesFromYesterday() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-04-30T12:00:00Z")!
        let today = iso.startOfDay(for: now)
        let yesterday = iso.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = iso.date(byAdding: .day, value: -2, to: today)!
        for day in [yesterday, twoDaysAgo] {
            ctx.insert(SessionEntity(id: UUID(), workoutID: UUID(),
                                     startedAt: day,
                                     completedAt: day.addingTimeInterval(1_800),
                                     durationSec: 1_800))
        }
        try ctx.save()

        let stats = try WorkoutRepository(modelContainer: container)
            .weeklyProgress(now: now, calendar: iso)

        XCTAssertEqual(stats.streakDays, 2)
    }
}
