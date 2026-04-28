import XCTest
@testable import Networking

final class CheckpointExtractorTests: XCTestCase {
    func test_extractsSingleCheckpoint() {
        var ex = CheckpointExtractor()
        let result = ex.feed("Considering recovery ⟦CHECKPOINT: scanning recent sessions⟧ now picking moves")
        XCTAssertEqual(result.checkpoints, ["scanning recent sessions"])
        XCTAssertEqual(result.passthroughText, "Considering recovery  now picking moves")
    }

    func test_buffersAcrossChunksWhenCheckpointSplits() {
        var ex = CheckpointExtractor()
        let r1 = ex.feed("intro ⟦CHECKPOINT: half")
        XCTAssertTrue(r1.checkpoints.isEmpty)
        XCTAssertEqual(r1.passthroughText, "intro ")
        let r2 = ex.feed(" of marker⟧ tail")
        XCTAssertEqual(r2.checkpoints, ["half of marker"])
        XCTAssertEqual(r2.passthroughText, " tail")
    }

    func test_extractsMultipleCheckpointsInOrder() {
        var ex = CheckpointExtractor()
        let r = ex.feed("a⟦CHECKPOINT: one⟧b⟦CHECKPOINT: two⟧c")
        XCTAssertEqual(r.checkpoints, ["one", "two"])
        XCTAssertEqual(r.passthroughText, "abc")
    }
}
