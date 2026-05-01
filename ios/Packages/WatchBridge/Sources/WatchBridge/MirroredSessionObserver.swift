import Foundation

public protocol MirroredSessionObserver: Actor {
    var heartRateBPM: AsyncStream<Int> { get }
    func startObserving() async
    func stopObserving() async
}
