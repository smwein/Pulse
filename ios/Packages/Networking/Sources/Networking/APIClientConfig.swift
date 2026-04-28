import Foundation

public struct APIClientConfig: Sendable {
    public let workerURL: URL
    public let deviceToken: String

    public init(workerURL: URL, deviceToken: String) {
        self.workerURL = workerURL
        self.deviceToken = deviceToken
    }
}
