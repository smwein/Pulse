import Foundation
#if canImport(HealthKit)
import HealthKit
@testable import HealthKitClient

final class FakeHKHealthStore: HKHealthStoreProtocol, @unchecked Sendable {
    var authorizationCalled = false
    var samplesByType: [HKSampleType: [HKSample]] = [:]
    var shouldThrow: Error?

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                              read typesToRead: Set<HKObjectType>?) async throws {
        authorizationCalled = true
        if let shouldThrow { throw shouldThrow }
    }

    func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        if let shouldThrow { throw shouldThrow }
        return samplesByType[type] ?? []
    }
}
#endif
