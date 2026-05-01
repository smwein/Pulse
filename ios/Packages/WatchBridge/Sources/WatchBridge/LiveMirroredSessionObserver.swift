import Foundation
// Guard on `os(iOS) || os(watchOS)` rather than `canImport(HealthKit)`: macOS 26
// imports HealthKit but does NOT expose `workoutSessionMirroringStartHandler` or
// `associatedWorkoutBuilder`. Same approach as `LiveWorkoutSessionFactory` (TG6).
#if os(iOS) || os(watchOS)
import HealthKit

/// Real-device implementation. The Phone registers a mirroring handler on
/// `HKHealthStore`; once the Watch's `HKWorkoutSession` starts mirroring, the
/// associated `HKLiveWorkoutBuilder`'s delegate is invoked with HR sample
/// updates. Verified against iOS 26 SDK: `workoutSessionMirroringStartHandler`
/// (iOS 17+), `associatedWorkoutBuilder()` (iOS 26+/watchOS 5+), and the Swift
/// selector `workoutBuilder(_:didCollectDataOf:)` (Obj-C `didCollectDataOfTypes:`).
@available(iOS 26.0, watchOS 10.0, *)
public actor LiveMirroredSessionObserver: MirroredSessionObserver {
    private let store: HKHealthStore
    private var continuations: [AsyncStream<Int>.Continuation] = []
    private var delegate: HRBuilderDelegate?

    public var heartRateBPM: AsyncStream<Int> {
        AsyncStream { cont in continuations.append(cont) }
    }

    public init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    public func startObserving() async {
        // Registering the handler is idempotent — assigning twice replaces.
        store.workoutSessionMirroringStartHandler = { [weak self] mirrored in
            // The handler runs on an arbitrary background queue per Apple docs;
            // hop back into the actor.
            Task { [weak self] in await self?.attach(to: mirrored) }
        }
    }

    private func attach(to session: HKWorkoutSession) async {
        let builder = session.associatedWorkoutBuilder()
        let delegate = HRBuilderDelegate { [weak self] bpm in
            Task { [weak self] in await self?.publish(bpm) }
        }
        builder.delegate = delegate
        // Retain the delegate — `HKLiveWorkoutBuilder.delegate` is `weak`,
        // so we must hold a strong reference.
        self.delegate = delegate
    }

    private func publish(_ bpm: Int) {
        for c in continuations { c.yield(bpm) }
    }

    public func stopObserving() async {
        store.workoutSessionMirroringStartHandler = nil
        for c in continuations { c.finish() }
        continuations = []
        delegate = nil
    }
}

/// Bridges `HKLiveWorkoutBuilderDelegate` callbacks to a Swift closure.
/// Lives in a private final class because the delegate must inherit `NSObject`.
/// `@unchecked Sendable` matches the pattern used by `LiveWorkoutSessionFactory`:
/// the delegate is mutated only by HK on its callback queue, and the captured
/// closure hops back into the owning actor.
@available(iOS 26.0, watchOS 10.0, *)
private final class HRBuilderDelegate: NSObject, HKLiveWorkoutBuilderDelegate, @unchecked Sendable {
    let onBPM: (Int) -> Void
    init(onBPM: @escaping (Int) -> Void) { self.onBPM = onBPM }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)) else { return }
        let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        if let q = stats?.mostRecentQuantity() {
            let bpm = Int(q.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            onBPM(bpm)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#endif
