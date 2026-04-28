import Foundation
import SwiftData

@Model
public final class AdaptationEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var feedbackID: UUID
    public var appliedToPlanID: UUID
    public var generatedAt: Date
    public var modelUsed: String
    public var promptTokens: Int
    public var completionTokens: Int
    @Attribute(.externalStorage) public var diffJSON: Data
    public var rationale: String

    public init(id: UUID, userID: UUID? = nil, feedbackID: UUID, appliedToPlanID: UUID,
                generatedAt: Date, modelUsed: String, promptTokens: Int,
                completionTokens: Int, diffJSON: Data, rationale: String) {
        self.id = id
        self.userID = userID
        self.feedbackID = feedbackID
        self.appliedToPlanID = appliedToPlanID
        self.generatedAt = generatedAt
        self.modelUsed = modelUsed
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.diffJSON = diffJSON
        self.rationale = rationale
    }
}
