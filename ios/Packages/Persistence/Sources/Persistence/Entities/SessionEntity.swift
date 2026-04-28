import Foundation
import SwiftData

@Model
public final class SessionEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var workoutID: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var avgHR: Int?
    public var kcal: Int?
    public var durationSec: Int?
    public var watchSessionUUID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SetLogEntity.session)
    public var setLogs: [SetLogEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \FeedbackEntity.session)
    public var feedback: FeedbackEntity?

    public init(id: UUID, userID: UUID? = nil, workoutID: UUID, startedAt: Date,
                completedAt: Date? = nil, avgHR: Int? = nil, kcal: Int? = nil,
                durationSec: Int? = nil, watchSessionUUID: UUID? = nil) {
        self.id = id
        self.userID = userID
        self.workoutID = workoutID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.avgHR = avgHR
        self.kcal = kcal
        self.durationSec = durationSec
        self.watchSessionUUID = watchSessionUUID
    }
}
