import Foundation

/// A logged set, sent over WatchConnectivity from Watch → Phone, then persisted.
public struct SetLogEntry: Codable, Hashable, Sendable {
    public var exerciseID: String
    public var setNum: Int
    public var reps: Int
    public var load: String
    public var rpe: Int          // 1...10
    public var loggedAt: Date

    public init(exerciseID: String, setNum: Int, reps: Int, load: String, rpe: Int, loggedAt: Date) {
        self.exerciseID = exerciseID
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.rpe = rpe
        self.loggedAt = loggedAt
    }
}
