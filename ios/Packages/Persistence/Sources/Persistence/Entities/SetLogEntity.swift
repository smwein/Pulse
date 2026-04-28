import Foundation
import SwiftData

@Model
public final class SetLogEntity {
    public var sessionID: UUID
    public var exerciseID: String
    public var setNum: Int
    public var reps: Int
    public var load: String
    public var rpe: Int
    public var loggedAt: Date
    public var session: SessionEntity?

    public init(sessionID: UUID, exerciseID: String, setNum: Int, reps: Int,
                load: String, rpe: Int, loggedAt: Date, session: SessionEntity? = nil) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.rpe = rpe
        self.loggedAt = loggedAt
        self.session = session
    }
}
