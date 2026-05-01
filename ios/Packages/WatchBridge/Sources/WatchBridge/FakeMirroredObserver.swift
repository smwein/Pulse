import Foundation

public actor FakeMirroredObserver: MirroredSessionObserver {
    private var continuations: [AsyncStream<Int>.Continuation] = []
    public var heartRateBPM: AsyncStream<Int> {
        AsyncStream { cont in continuations.append(cont) }
    }
    public init() {}
    public func startObserving() async {}
    public func stopObserving() async {
        for c in continuations { c.finish() }
        continuations = []
    }
    public func simulateBPM(_ value: Int) {
        for c in continuations { c.yield(value) }
    }
}
