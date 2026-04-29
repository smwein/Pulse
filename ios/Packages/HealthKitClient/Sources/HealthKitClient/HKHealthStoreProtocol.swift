import Foundation
#if canImport(HealthKit)
import HealthKit

/// Narrow protocol over the parts of HKHealthStore we use, so tests can inject a fake.
public protocol HKHealthStoreProtocol: Sendable {
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                              read typesToRead: Set<HKObjectType>?) async throws
    func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample]
}

extension HKHealthStore: HKHealthStoreProtocol {
    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                                     read typesToRead: Set<HKObjectType>?) async throws {
        try await requestAuthorization(toShare: typesToShare ?? [],
                                       read: typesToRead ?? [])
    }
    public func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: results ?? []) }
            }
            self.execute(q)
        }
    }
}
#else
public protocol HKHealthStoreProtocol: Sendable {}
#endif
