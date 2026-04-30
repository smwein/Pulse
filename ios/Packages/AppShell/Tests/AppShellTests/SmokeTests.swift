import XCTest
import Persistence
import SwiftData
import WatchBridge
@testable import AppShell

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }

    @MainActor
    func test_phoneWatchMirror_persistsIncomingWatchSetAndAcks() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workoutID = UUID()
        let workout = WorkoutEntity(id: workoutID, planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "in_progress", blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8))
        let sessionID = UUID()
        ctx.insert(workout)
        ctx.insert(SessionEntity(id: sessionID, workoutID: workoutID, startedAt: Date()))
        try ctx.save()
        let transport = FakeTransport()
        let mirror = PhoneWatchMirrorCoordinator(transport: transport,
                                                 modelContainer: container)
        let log = SetLogDTO(sessionID: sessionID, exerciseID: "row",
                            setNum: 1, reps: 8, load: "100",
                            rpe: nil, loggedAt: Date())

        await mirror.handle(.setLog(log))

        let logs = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.exerciseID, "row")
        let sent = await transport.sent
        XCTAssertEqual(sent.first?.message, .ack(naturalKey: log.naturalKey))
    }

    @MainActor
    func test_phoneWatchMirror_finishesInProgressSessionOnWatchEnded() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workoutID = UUID()
        let workout = WorkoutEntity(id: workoutID, planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "in_progress", blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8))
        let sessionID = UUID()
        ctx.insert(workout)
        ctx.insert(SessionEntity(id: sessionID, workoutID: workoutID, startedAt: Date()))
        try ctx.save()
        var completedID: UUID?
        let mirror = PhoneWatchMirrorCoordinator(transport: FakeTransport(),
                                                 modelContainer: container,
                                                 onWatchEndedSession: { completedID = $0 })

        await mirror.handle(.sessionLifecycle(.ended))

        let session = try ctx.fetch(FetchDescriptor<SessionEntity>()).first
        XCTAssertNotNil(session?.completedAt)
        XCTAssertEqual(completedID, sessionID)
    }
}
