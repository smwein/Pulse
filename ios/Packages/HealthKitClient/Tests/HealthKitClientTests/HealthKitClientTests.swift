import XCTest
#if canImport(HealthKit)
import HealthKit
@testable import HealthKitClient

final class HealthKitClientTests: XCTestCase {
    func test_sevenDayActivitySummary_sumsExerciseMinutes() async {
        let fake = FakeHKHealthStore()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let type = HKQuantityType(.appleExerciseTime)
        let s1 = HKQuantitySample(type: type,
            quantity: HKQuantity(unit: .minute(), doubleValue: 30),
            start: now.addingTimeInterval(-3 * 86_400),
            end: now.addingTimeInterval(-3 * 86_400 + 1800))
        let s2 = HKQuantitySample(type: type,
            quantity: HKQuantity(unit: .minute(), doubleValue: 45),
            start: now.addingTimeInterval(-1 * 86_400),
            end: now.addingTimeInterval(-1 * 86_400 + 2700))
        fake.samplesByType[type] = [s1, s2]
        let client = HealthKitClient(store: fake, now: { now })
        let summary = await client.sevenDayActivitySummary()
        XCTAssertEqual(summary?.weeklyActiveMinutes, 75)
        XCTAssertEqual(summary?.targetActiveMinutes, 240)
    }

    func test_sevenDayHRSummary_averagesRestingHRAndHRV() async {
        let fake = FakeHKHealthStore()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let restingType = HKQuantityType(.restingHeartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        fake.samplesByType[restingType] = [
            HKQuantitySample(type: restingType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()),
                                     doubleValue: 56),
                start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(-86_400)),
            HKQuantitySample(type: restingType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()),
                                     doubleValue: 60),
                start: now.addingTimeInterval(-86_400 * 2), end: now.addingTimeInterval(-86_400 * 2)),
        ]
        fake.samplesByType[hrvType] = [
            HKQuantitySample(type: hrvType,
                quantity: HKQuantity(unit: .secondUnit(with: .milli), doubleValue: 50),
                start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(-86_400)),
        ]
        let client = HealthKitClient(store: fake, now: { now })
        let summary = await client.sevenDayHRSummary()
        XCTAssertEqual(summary?.avgRestingHR, 58)
        XCTAssertEqual(summary?.avgHRVSDNN, 50)
    }

    func test_sevenDaySummary_returnsEmptyWhenStoreIsNil() async {
        let client = HealthKitClient(store: nil)
        let summary = await client.sevenDaySummary()
        XCTAssertTrue(summary.isEmpty)
    }

    func test_sevenDaySummary_propagatesErrorAsNil() async {
        let fake = FakeHKHealthStore()
        struct DummyError: Error {}
        fake.shouldThrow = DummyError()
        let client = HealthKitClient(store: fake)
        let summary = await client.sevenDaySummary()
        XCTAssertTrue(summary.isEmpty)
    }
}
#endif
