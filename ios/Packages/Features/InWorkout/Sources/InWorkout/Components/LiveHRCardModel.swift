import Foundation
import Observation

@MainActor
@Observable
public final class LiveHRCardModel {
    private struct Sample { let bpm: Int; let at: Date }
    private var samples: [Sample] = []
    private let now: @Sendable () -> Date

    public init(now: @Sendable @escaping () -> Date = { Date() }) { self.now = now }

    public func record(bpm: Int, at: Date) {
        samples.append(.init(bpm: bpm, at: at))
        let cutoff = at.addingTimeInterval(-5)
        samples.removeAll { $0.at < cutoff }
    }

    public var displayBPM: Int? {
        guard let latest = samples.last else { return nil }
        if now().timeIntervalSince(latest.at) > 10 { return nil }
        let recent = samples.filter { now().timeIntervalSince($0.at) <= 5 }
        guard !recent.isEmpty else { return nil }
        let mean = Double(recent.reduce(0) { $0 + $1.bpm }) / Double(recent.count)
        return Int(mean.rounded())
    }
}
