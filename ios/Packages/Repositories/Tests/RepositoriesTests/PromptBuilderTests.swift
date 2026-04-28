import XCTest
import CoreModels
@testable import Repositories

final class PromptBuilderTests: XCTestCase {
    func test_systemPrompt_includesCoachIdentity() {
        let coach = Coach.byID("rex")!
        let s = PromptBuilder.planGenSystemPrompt(coach: coach)
        XCTAssertTrue(s.contains("Rex"))
        XCTAssertTrue(s.contains("CHECKPOINT"))
        XCTAssertTrue(s.contains("```json"))
    }

    func test_userMessage_includesAllProfileFieldsAndDate() {
        let p = Profile(id: UUID(), displayName: "Sam",
            goals: ["build muscle"], level: .regular,
            equipment: ["dumbbells"], frequencyPerWeek: 4,
            weeklyTargetMinutes: 180, activeCoachID: "rex",
            createdAt: Date())
        let date = Date(timeIntervalSince1970: 1_730_000_000)
        let m = PromptBuilder.planGenUserMessage(profile: p, today: date)
        XCTAssertTrue(m.contains("Sam"))
        XCTAssertTrue(m.contains("build muscle"))
        XCTAssertTrue(m.contains("regular"))
        XCTAssertTrue(m.contains("dumbbells"))
        XCTAssertTrue(m.contains("4"))
        XCTAssertTrue(m.contains("180"))
        XCTAssertTrue(m.contains("2024-10-27"))
    }

    func test_strictRetrySuffix_appendsValidJSONReminder() {
        let s = PromptBuilder.planGenSystemPrompt(coach: Coach.byID("ace")!,
                                                  strictRetry: true)
        XCTAssertTrue(s.contains("respond with valid JSON only"))
    }
}
