import XCTest
import SwiftData
import CoreModels
import Networking
import Persistence
@testable import Repositories

final class PlanRepositoryTests: XCTestCase {
    @MainActor
    func test_listLatestReturnsMostRecentPlanFirst() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let older = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        let newer = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_730_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_730_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        ctx.insert(older); ctx.insert(newer); try ctx.save()

        let repo = PlanRepository.makeForTests(modelContainer: container)
        let latest = try repo.listLatest(limit: 5)
        XCTAssertEqual(latest.first?.id, newer.id)
    }
}
