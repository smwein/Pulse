import XCTest
import SwiftData
@testable import Persistence

final class SetLogEntityTests: XCTestCase {
    func test_setLogPersistsAttachedToSession() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session)
        let log = SetLogEntity(sessionID: session.id, exerciseID: "back_squat",
                               setNum: 1, reps: 5, load: "60 kg", rpe: 7,
                               loggedAt: Date(), session: session)
        ctx.insert(log)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SessionEntity>())
        XCTAssertEqual(fetched.first?.setLogs.count, 1)
        XCTAssertEqual(fetched.first?.setLogs.first?.exerciseID, "back_squat")
    }
}
