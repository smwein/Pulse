import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitClient: Sendable {
    private let store: HKHealthStoreProtocol?
    private let now: @Sendable () -> Date

    public init(store: HKHealthStoreProtocol?, now: @Sendable @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    /// Real-device convenience: builds a wrapped `HKHealthStore` if HealthKit is available.
    #if canImport(HealthKit)
    public static func live() -> HealthKitClient {
        HealthKitClient(store: HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil)
    }
    #else
    public static func live() -> HealthKitClient { HealthKitClient(store: nil) }
    #endif

    public func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard let store else { return }
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.sleepAnalysis),
        ]
        try await store.requestAuthorization(toShare: nil, read: read)
        #endif
    }

    public func sevenDayActivitySummary(target: Int = 240) async -> SevenDayActivitySummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let type = HKQuantityType(.appleExerciseTime)
        guard let samples = try? await store.samples(of: type, predicate: predicate) as? [HKQuantitySample] else {
            return nil
        }
        let totalMin = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .minute()) }
        return SevenDayActivitySummary(weeklyActiveMinutes: Int(totalMin),
                                       targetActiveMinutes: target)
        #else
        return nil
        #endif
    }

    public func sevenDayHRSummary() async -> SevenDayHRSummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        async let resting = avg(store: store, type: HKQuantityType(.restingHeartRate),
                                 unit: HKUnit.count().unitDivided(by: .minute()),
                                 predicate: predicate)
        async let hrv = avg(store: store, type: HKQuantityType(.heartRateVariabilitySDNN),
                             unit: HKUnit.secondUnit(with: .milli),
                             predicate: predicate)
        let r = await resting
        let h = await hrv
        if r == nil && h == nil { return nil }
        return SevenDayHRSummary(avgRestingHR: r.map { Int($0.rounded()) },
                                 avgHRVSDNN: h.map { Int($0.rounded()) })
        #else
        return nil
        #endif
    }

    public func sevenDaySleepSummary() async -> SevenDaySleepSummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        guard let samples = try? await store.samples(of: HKCategoryType(.sleepAnalysis),
                                                      predicate: predicate)
                as? [HKCategorySample] else {
            return nil
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        let totalSec = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let avgHours = totalSec / 3600.0 / 7.0
        return SevenDaySleepSummary(avgSleepHours: avgHours > 0 ? avgHours : nil)
        #else
        return nil
        #endif
    }

    public func sevenDaySummary() async -> SevenDayHealthSummary {
        async let a = sevenDayActivitySummary()
        async let h = sevenDayHRSummary()
        async let s = sevenDaySleepSummary()
        return await SevenDayHealthSummary(activity: a, hr: h, sleep: s)
    }

    #if canImport(HealthKit)
    private func avg(store: HKHealthStoreProtocol, type: HKQuantityType,
                     unit: HKUnit, predicate: NSPredicate) async -> Double? {
        guard let samples = try? await store.samples(of: type, predicate: predicate)
                as? [HKQuantitySample], !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return total / Double(samples.count)
    }
    #endif
}

public extension HealthKitClient {
    #if canImport(HealthKit)
    private static let writeTypes: [HKSampleType] = [
        HKObjectType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]
    #endif

    public func requestWriteAuthorization() async throws {
        #if canImport(HealthKit)
        guard let store else { return }
        try await store.requestAuthorization(toShare: Set(Self.writeTypes), read: nil)
        #endif
    }

    /// Returns true when *all* write categories are authorized.
    /// HealthKit auth status is per-type; we treat partial as not-ready.
    public func writeAuthorizationStatus() -> WriteAuthStatus {
        #if canImport(HealthKit)
        guard let store = store as? HKHealthStore else { return .undetermined }
        let statuses = Self.writeTypes.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }
        if statuses.contains(.sharingDenied) { return .denied }
        return .undetermined
        #else
        return .undetermined
        #endif
    }
}

public enum WriteAuthStatus: Sendable, Equatable {
    case undetermined
    case authorized
    case denied
}

/// Testability seam for write-auth flows: lets `SessionStore` (and future
/// callers) make the JIT auth check without holding a real `HKHealthStore`.
public protocol HealthKitAuthGate: Sendable {
    func writeAuthorizationStatus() -> WriteAuthStatus
    func requestWriteAuthorization() async throws
}

extension HealthKitClient: HealthKitAuthGate {}
