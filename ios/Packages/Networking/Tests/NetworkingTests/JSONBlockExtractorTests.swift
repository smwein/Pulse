import XCTest
@testable import Networking

final class JSONBlockExtractorTests: XCTestCase {
    func test_extractsFencedJSONBlock() {
        let text = """
        Here is your plan:

        ```json
        {"workouts": [{"id": "W1"}]}
        ```

        End of message.
        """
        XCTAssertEqual(
            JSONBlockExtractor.extract(from: text),
            #"{"workouts": [{"id": "W1"}]}"#
        )
    }

    func test_extractsFirstUnlabeledBlockWhenMultiplePresent() {
        let text = """
        ```json
        {"draft": true}
        ```
        Updated:
        ```json
        {"final": true}
        ```
        """
        // extract(from:) now returns the first unlabeled block (plan-gen uses a
        // single block so the "last vs first" distinction doesn't matter in practice).
        XCTAssertEqual(JSONBlockExtractor.extract(from: text), #"{"draft": true}"#)
    }

    func test_returnsNilWhenNoBlockPresent() {
        XCTAssertNil(JSONBlockExtractor.extract(from: "no fences here"))
    }

    func test_extractAllLabeled_returnsBlocksInOrderWithLabels() {
        let text = """
        Some prose.
        ```json adjustment
        {"id":"a1","label":"L","detail":"D"}
        ```
        ```json workout
        {"id":"w1","title":"X"}
        ```
        More prose.
        ```json
        {"unlabeled":true}
        ```
        """
        let blocks = JSONBlockExtractor.extractAllLabeled(from: text)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].label, "adjustment")
        XCTAssertEqual(blocks[1].label, "workout")
        XCTAssertNil(blocks[2].label)
    }
}
