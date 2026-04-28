import XCTest
@testable import Networking

final class AnthropicRequestTests: XCTestCase {
    func test_planGenerationBuilderProducesExpectedShape() throws {
        let req = AnthropicRequest.planGeneration(
            systemPrompt: "You are Pulse.",
            userMessage: "Build today's workout."
        )
        XCTAssertEqual(req.model, "claude-opus-4-7")
        XCTAssertEqual(req.maxTokens, 4096)
        XCTAssertEqual(req.system, "You are Pulse.")
        XCTAssertEqual(req.messages.count, 1)
        XCTAssertEqual(req.messages[0].role, .user)
        // Cache control should be set on system prompt for plan generation
        XCTAssertEqual(req.systemCacheControl, .ephemeral)
    }

    func test_adaptationBuilderUsesOpus() {
        let req = AnthropicRequest.adaptation(
            systemPrompt: "You are Pulse.",
            priorPlanJSON: "{}",
            feedbackJSON: "{}"
        )
        XCTAssertEqual(req.model, "claude-opus-4-7")
        XCTAssertGreaterThan(req.messages.count, 0)
    }

    func test_requestEncodesAsAnthropicWireFormat() throws {
        let req = AnthropicRequest.planGeneration(systemPrompt: "S", userMessage: "U")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "claude-opus-4-7")
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
        let system = json["system"] as! [[String: Any]]
        XCTAssertEqual(system[0]["type"] as? String, "text")
        XCTAssertEqual((system[0]["cache_control"] as? [String: String])?["type"], "ephemeral")
    }
}
