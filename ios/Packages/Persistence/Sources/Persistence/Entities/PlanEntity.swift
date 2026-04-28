import Foundation
import SwiftData

@Model
public final class PlanEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var weekStart: Date
    public var generatedAt: Date
    public var modelUsed: String
    public var promptTokens: Int
    public var completionTokens: Int
    @Attribute(.externalStorage) public var payloadJSON: Data

    public init(id: UUID, userID: UUID? = nil, weekStart: Date, generatedAt: Date,
                modelUsed: String, promptTokens: Int, completionTokens: Int,
                payloadJSON: Data) {
        self.id = id
        self.userID = userID
        self.weekStart = weekStart
        self.generatedAt = generatedAt
        self.modelUsed = modelUsed
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.payloadJSON = payloadJSON
    }
}
