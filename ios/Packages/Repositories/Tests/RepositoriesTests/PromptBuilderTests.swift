import XCTest
import CoreModels
import HealthKitClient
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

    func test_availableExercises_section_appearsWhenNonEmpty() {
        let exercises: [(id: String, name: String, equipment: [String])] = [
            (id: "Back_Squat", name: "Back Squat", equipment: ["barbell"]),
            (id: "Air_Bike", name: "Air Bike", equipment: [])
        ]
        let s = PromptBuilder.planGenSystemPrompt(coach: Coach.byID("rex")!,
                                                  availableExercises: exercises)
        XCTAssertTrue(s.contains("Available exercises"))
        XCTAssertTrue(s.contains("Back_Squat"))
        XCTAssertTrue(s.contains("Air_Bike"))
        XCTAssertTrue(s.contains("Only use IDs from this list"))
    }

    func test_availableExercises_section_absentWhenEmpty() {
        let s = PromptBuilder.planGenSystemPrompt(coach: Coach.byID("rex")!)
        XCTAssertFalse(s.contains("Available exercises"))
        XCTAssertFalse(s.contains("Only use IDs from this list"))
    }

    func test_availableExercises_cappedAt50Entries() {
        let exercises = (0..<100).map { i in
            (id: "Ex_\(i)", name: "Exercise \(i)", equipment: ["dumbbell"])
        }
        let s = PromptBuilder.planGenSystemPrompt(coach: Coach.byID("rex")!,
                                                  availableExercises: exercises)
        // Should contain exactly 50 entries, not 100
        let count = s.components(separatedBy: "Ex_").count - 1
        XCTAssertEqual(count, PromptBuilder.maxCatalogEntries)
    }

    func test_planGenUserMessage_omitsHealthBlockWhenSummariesEmpty() {
        let profile = ProfileRepositoryTests.fixtureProfile()
        let date = Date(timeIntervalSince1970: 1_730_000_000)
        let s = PromptBuilder.planGenUserMessage(profile: profile, today: date, summaries: nil)
        XCTAssertFalse(s.contains("7-DAY HEALTH SUMMARY"))
    }

    func test_planGenUserMessage_includesHealthBlockWhenSummariesPresent() {
        let profile = ProfileRepositoryTests.fixtureProfile()
        let date = Date(timeIntervalSince1970: 1_730_000_000)
        let summaries = SevenDayHealthSummary(
            activity: .init(weeklyActiveMinutes: 187, targetActiveMinutes: 240),
            hr: .init(avgRestingHR: 58, avgHRVSDNN: 52),
            sleep: .init(avgSleepHours: 7.4))
        let s = PromptBuilder.planGenUserMessage(profile: profile, today: date, summaries: summaries)
        XCTAssertTrue(s.contains("7-DAY HEALTH SUMMARY"))
        XCTAssertTrue(s.contains("avg resting HR: 58 bpm"))
        XCTAssertTrue(s.contains("avg HRV (SDNN): 52 ms"))
        XCTAssertTrue(s.contains("avg sleep: 7.4 hrs"))
        XCTAssertTrue(s.contains("weekly active minutes: 187 / 240 target"))
    }
}
