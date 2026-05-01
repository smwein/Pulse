import XCTest
@testable import WatchBridge

final class FakeMirroredObserverTests: XCTestCase {
    func test_publishesHRSamples() async {
        let obs = FakeMirroredObserver()
        var received: [Int] = []
        let task = Task {
            for await bpm in await obs.heartRateBPM {
                received.append(bpm)
                if received.count >= 3 { break }
            }
        }
        // Give the consumer a tick to attach.
        try? await Task.sleep(nanoseconds: 10_000_000)
        await obs.simulateBPM(72)
        await obs.simulateBPM(74)
        await obs.simulateBPM(76)
        _ = await task.value
        XCTAssertEqual(received, [72, 74, 76])
    }
}
