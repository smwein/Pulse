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

    func test_extractsLastBlockWhenMultiplePresent() {
        let text = """
        ```json
        {"draft": true}
        ```
        Updated:
        ```json
        {"final": true}
        ```
        """
        XCTAssertEqual(JSONBlockExtractor.extract(from: text), #"{"final": true}"#)
    }

    func test_returnsNilWhenNoBlockPresent() {
        XCTAssertNil(JSONBlockExtractor.extract(from: "no fences here"))
    }
}
