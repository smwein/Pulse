import Foundation

public struct SSEEvent: Hashable, Sendable {
    public let event: String
    public let data: String
    public let id: String?

    public init(event: String, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}
