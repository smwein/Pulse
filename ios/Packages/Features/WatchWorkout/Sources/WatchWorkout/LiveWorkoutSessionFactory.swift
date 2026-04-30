import Foundation
import Logging
// Guard on `os(watchOS)` rather than `canImport(HealthKit)`: HealthKit *is* importable on
// macOS, but `HKWorkoutSession.init(healthStore:configuration:)`, `associatedWorkoutBuilder`,
// `startMirroringToCompanionDevice`, and the async `beginCollection`/`endCollection`
// overloads are all marked `API_UNAVAILABLE(macos)`. The macOS test slice doesn't need
// this file at all — protocol is the seam, real device verifies behavior.
#if os(watchOS)
import HealthKit

/// `@unchecked Sendable` because mutable `session`/`builder` state is intended to be
/// confined to the `WatchSessionStore`'s @MainActor lifetime — the protocol's Sendable
/// requirement is satisfied by that confinement, not by internal synchronization.
public final class LiveWorkoutSessionFactory: WorkoutSessionFactory, @unchecked Sendable {
    private let store: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    public init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    public func startSession(activityKind: String) async throws -> UUID {
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = Self.activityType(for: activityKind)
        cfg.locationType = .indoor
        let s = try HKWorkoutSession(healthStore: store, configuration: cfg)
        let b = s.associatedWorkoutBuilder()
        b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: cfg)
        // HKWorkoutSession exposes no public UUID — generate our own correlation
        // token for the Phone-side mirrored session.
        let uuid = UUID()
        s.startActivity(with: Date())  // non-throwing, void
        try await b.beginCollection(at: Date())
        // Companion mirroring — Phone receives lifecycle + builder data.
        try? await s.startMirroringToCompanionDevice()
        self.session = s
        self.builder = b
        return uuid
    }

    public func endSession() async throws {
        guard let s = session, let b = builder else { return }
        s.end()
        try await b.endCollection(at: Date())
        _ = try await b.finishWorkout()  // writes HKWorkout
        self.session = nil
        self.builder = nil
    }

    public func recoverIfActive() async -> UUID? {
        // iOS 17/watchOS 10+: HKHealthStore exposes a recovery API. The exact name
        // varies across SDK versions; resolve at implementation time. This stub
        // returns nil until the device-side path is wired up in Task Group 13.
        return nil
    }

    private static func activityType(for kind: String) -> HKWorkoutActivityType {
        switch kind {
        case "traditionalStrengthTraining": return .traditionalStrengthTraining
        case "functionalStrengthTraining":  return .functionalStrengthTraining
        case "coreTraining":                return .coreTraining
        case "flexibility":                 return .flexibility
        case "mixedCardio":                 return .mixedCardio
        default:                            return .traditionalStrengthTraining
        }
    }
}
#endif
