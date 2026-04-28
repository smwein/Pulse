import XCTest
@testable import Networking

final class APIClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.reset()
    }

    func test_streamsSSEEventsFromMockedResponse() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"hi"}}

        event: message_stop
        data: {"type":"message_stop"}


        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Device-Token"), "test-token")
            XCTAssertEqual(req.httpMethod, "POST")
            return (HTTPURLResponse(url: req.url!, statusCode: 200,
                                    httpVersion: nil,
                                    headerFields: ["Content-Type": "text/event-stream"])!,
                    body)
        }

        let session = URLSession(configuration: MockURLProtocol.sessionConfig())
        let client = APIClient(config: APIClientConfig(
            workerURL: URL(string: "https://test.workers.dev/")!,
            deviceToken: "test-token"
        ), session: session)

        let request = AnthropicRequest.planGeneration(systemPrompt: "S", userMessage: "U")
        var collected: [SSEEvent] = []
        for try await event in client.streamEvents(request: request) {
            collected.append(event)
        }
        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(collected[0].event, "content_block_delta")
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() { handler = nil }

    static func sessionConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
