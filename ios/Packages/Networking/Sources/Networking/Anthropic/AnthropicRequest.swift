import Foundation

public enum CacheControl: String, Sendable {
    case ephemeral
}

public struct AnthropicRequest: Sendable {
    public var model: String
    public var maxTokens: Int
    public var system: String
    public var systemCacheControl: CacheControl?
    public var messages: [AnthropicMessage]
    public var stream: Bool

    public init(model: String, maxTokens: Int, system: String,
                systemCacheControl: CacheControl?, messages: [AnthropicMessage],
                stream: Bool = true) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.systemCacheControl = systemCacheControl
        self.messages = messages
        self.stream = stream
    }
}

public extension AnthropicRequest {
    static func planGeneration(systemPrompt: String, userMessage: String) -> AnthropicRequest {
        AnthropicRequest(
            model: "claude-opus-4-7",
            maxTokens: 4096,
            system: systemPrompt,
            systemCacheControl: .ephemeral,
            messages: [.init(role: .user, content: userMessage)]
        )
    }

    static func adaptation(systemPrompt: String, priorPlanJSON: String,
                           feedbackJSON: String) -> AnthropicRequest {
        let user = """
        Prior plan:
        \(priorPlanJSON)

        Latest workout feedback:
        \(feedbackJSON)

        Produce an updated plan + diff.
        """
        return AnthropicRequest(
            model: "claude-opus-4-7",
            maxTokens: 4096,
            system: systemPrompt,
            systemCacheControl: .ephemeral,
            messages: [.init(role: .user, content: user)]
        )
    }
}

extension AnthropicRequest: Codable {
    private struct SystemBlock: Codable {
        let type: String
        let text: String
        var cache_control: [String: String]?
    }

    private enum CodingKeys: String, CodingKey {
        case model, max_tokens, system, messages, stream
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model, forKey: .model)
        try c.encode(maxTokens, forKey: .max_tokens)
        try c.encode(stream, forKey: .stream)
        try c.encode(messages, forKey: .messages)
        var block = SystemBlock(type: "text", text: system, cache_control: nil)
        if let cc = systemCacheControl { block.cache_control = ["type": cc.rawValue] }
        try c.encode([block], forKey: .system)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try c.decode(String.self, forKey: .model)
        self.maxTokens = try c.decode(Int.self, forKey: .max_tokens)
        self.stream = try c.decodeIfPresent(Bool.self, forKey: .stream) ?? false
        self.messages = try c.decode([AnthropicMessage].self, forKey: .messages)
        let blocks = try c.decode([SystemBlock].self, forKey: .system)
        self.system = blocks.first?.text ?? ""
        self.systemCacheControl = (blocks.first?.cache_control?["type"] == "ephemeral") ? .ephemeral : nil
    }
}
