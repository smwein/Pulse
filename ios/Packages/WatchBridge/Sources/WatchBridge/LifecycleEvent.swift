import Foundation

public enum LifecycleEvent: Codable, Equatable, Sendable {
    case started(watchSessionUUID: UUID)
    case ended
    case failed(reason: FailureReason)

    public enum FailureReason: String, Codable, CaseIterable, Sendable {
        case healthKitDenied
        case sessionStartFailed
        case payloadInvalid
    }
}
