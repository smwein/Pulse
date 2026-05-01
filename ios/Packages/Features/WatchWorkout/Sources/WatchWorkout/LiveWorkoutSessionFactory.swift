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
        // Returns the recovered HKWorkoutSession (or nil if none active). API
        // requires iOS 26+/watchOS 5+; the file is `#if os(watchOS)` and the
        // package targets watchOS 10+, so availability is satisfied.
        //
        // HKWorkoutSession has no public UUID property (TG6 fix used synthetic
        // UUIDs that aren't persisted across crashes). Generate a fresh UUID;
        // the phone tracks SessionEntity by sessionID (in the persisted
        // payload), not by watchSessionUUID, so a fresh correlation token is
        // fine. Forward-flag: if we want UUID continuity across kill-recover,
        // persist it alongside the payload.
        let recovered: HKWorkoutSession? = await withCheckedContinuation { cont in
            store.recoverActiveWorkoutSession { session, _ in
                cont.resume(returning: session)
            }
        }
        guard let session = recovered else { return nil }
        self.session = session
        self.builder = session.associatedWorkoutBuilder()
        return UUID()
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
