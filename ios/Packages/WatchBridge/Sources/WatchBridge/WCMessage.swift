import Foundation

public enum WCMessage: Codable, Equatable, Sendable {
    case workoutPayload(WorkoutPayloadDTO)
    case setLog(SetLogDTO)
    case sessionLifecycle(LifecycleEvent)
    case ack(naturalKey: String)
}

public extension WCMessage {
    enum CodecError: Error { case missingPayload, invalidPayload }

    static let userInfoKey = "wcmsg.v1"

    func asUserInfo() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [Self.userInfoKey: data]
    }

    init(userInfo: [String: Any]) throws {
        guard let data = userInfo[Self.userInfoKey] as? Data else {
            throw CodecError.missingPayload
        }
        do {
            self = try JSONDecoder().decode(WCMessage.self, from: data)
        } catch {
            throw CodecError.invalidPayload
        }
    }
}
