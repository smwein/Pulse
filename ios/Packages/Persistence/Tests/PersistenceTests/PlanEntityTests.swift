import XCTest
import SwiftData
@testable import Persistence

final class PlanEntityTests: XCTestCase {
    @MainActor
    func test_persistAndFetchPlanWithExternalStorage() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let payload = #"{"weekStart":"2026-04-27","workouts":[]}"#.data(using: .utf8)!
        let plan = PlanEntity(id: UUID(),
                              weekStart: Date(),
                              generatedAt: Date(),
                              modelUsed: "claude-opus-4-7",
                              promptTokens: 1200,
                              completionTokens: 800,
                              payloadJSON: payload)
        ctx.insert(plan)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PlanEntity>())
        XCTAssertEqual(fetched.first?.payloadJSON, payload)
    }
}
