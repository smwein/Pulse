import Foundation

public enum WCMessage: Codable, Equatable, Sendable {
    case workoutPayload(WorkoutPayloadDTO)
    case setLog(SetLogDTO)
    case sessionLifecycle(LifecycleEvent)
    case ack(naturalKey: String)
}
