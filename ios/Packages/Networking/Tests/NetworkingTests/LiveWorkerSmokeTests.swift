import XCTest
@testable import Networking

/// Hits the real worker. Skipped unless PULSE_LIVE_TEST=1 is in env.
/// Reads PULSE_WORKER_URL and PULSE_DEVICE_TOKEN from env.
final class LiveWorkerSmokeTests: XCTestCase {
    func test_liveWorkerStreamsHaikuLikeOutput() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PULSE_LIVE_TEST"] == "1" else {
            throw XCTSkip("PULSE_LIVE_TEST != 1")
        }
        let urlStr = try XCTUnwrap(env["PULSE_WORKER_URL"], "PULSE_WORKER_URL missing")
        let token  = try XCTUnwrap(env["PULSE_DEVICE_TOKEN"], "PULSE_DEVICE_TOKEN missing")
        let url    = try XCTUnwrap(URL(string: urlStr))

        let client = APIClient(config: APIClientConfig(workerURL: url, deviceToken: token))
        let req = AnthropicRequest(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 64,
            system: "You are a brief assistant.",
            systemCacheControl: nil,
            messages: [.init(role: .user, content: "Reply with a single word: ping")]
        )

        var sawDelta = false
        var sawStop = false
        for try await event in client.streamEvents(request: req) {
            if event.event == "content_block_delta" { sawDelta = true }
            if event.event == "message_stop" { sawStop = true }
        }
        XCTAssertTrue(sawDelta, "expected at least one content_block_delta")
        XCTAssertTrue(sawStop, "expected message_stop")
    }
}
