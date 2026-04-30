import XCTest
@testable import HealthKitClient
#if canImport(HealthKit)
import HealthKit

final class WriteAuthTests: XCTestCase {
    func test_requestWriteAuthorization_passesExpectedTypes() async throws {
        let fake = FakeHKHealthStore()
        let client = HealthKitClient(store: fake)
        try await client.requestWriteAuthorization()
        let expected: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        XCTAssertEqual(fake.lastShareTypes, expected)
    }
}
#endif
