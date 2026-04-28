import XCTest
@testable import Networking

final class SSEStreamParserTests: XCTestCase {
    func test_parsesCompleteEventsFromSingleChunk() throws {
        var parser = SSEStreamParser()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-stream", withExtension: "txt", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let events = parser.feed(data)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0].event, "message_start")
        XCTAssertEqual(events[1].event, "content_block_delta")
        XCTAssertTrue(events[1].data.contains("Hello"))
    }

    func test_buffersIncompleteEventAcrossChunks() {
        var parser = SSEStreamParser()
        let first = "event: foo\ndata: {\"x\":1".data(using: .utf8)!
        XCTAssertTrue(parser.feed(first).isEmpty)
        let second = "}\n\nevent: bar\ndata: {}\n\n".data(using: .utf8)!
        let events = parser.feed(second)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].event, "foo")
        XCTAssertEqual(events[0].data, "{\"x\":1}")
        XCTAssertEqual(events[1].event, "bar")
    }

    func test_handlesEventsWithoutExplicitEventName() {
        var parser = SSEStreamParser()
        let chunk = "data: {\"only\":\"data\"}\n\n".data(using: .utf8)!
        let events = parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].event, "message")  // default per SSE spec
    }
}
