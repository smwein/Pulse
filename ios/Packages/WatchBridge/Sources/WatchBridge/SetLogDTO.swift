import Foundation

public struct SetLogDTO: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let exerciseID: String
    public let setNum: Int
    public let reps: Int
    public let load: String
    public let rpe: Int?
    public let loggedAt: Date

    public init(sessionID: UUID, exerciseID: String, setNum: Int, reps: Int,
                load: String, rpe: Int?, loggedAt: Date) {
        self.sessionID = sessionID; self.exerciseID = exerciseID; self.setNum = setNum
        self.reps = reps; self.load = load; self.rpe = rpe; self.loggedAt = loggedAt
    }

    /// Idempotency key — matches `SessionRepository.logSet`'s upsert key.
    public var naturalKey: String {
        "\(sessionID.uuidString)|\(exerciseID)|\(setNum)"
    }
}
