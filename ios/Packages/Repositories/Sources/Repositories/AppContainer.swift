import Foundation
import SwiftData
import Networking
import HealthKitClient
import WatchBridge

/// Single point of injection for repository dependencies. The app target builds
/// one of these in `@main` and hands it to the SwiftUI environment.
public struct AppContainer: Sendable {
    public let modelContainer: ModelContainer
    public let api: APIClient
    public let manifestURL: URL
    public let healthKit: HealthKitClient
    public let transport: any WatchSessionTransport

    public init(modelContainer: ModelContainer, api: APIClient, manifestURL: URL,
                healthKit: HealthKitClient, transport: any WatchSessionTransport) {
        self.modelContainer = modelContainer
        self.api = api
        self.manifestURL = manifestURL
        self.healthKit = healthKit
        self.transport = transport
    }
}
