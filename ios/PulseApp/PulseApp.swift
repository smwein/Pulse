import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories
import HealthKitClient
import WatchBridge

@main
struct PulseApp: App {
    @State private var container = makeAppContainer()
    @State private var theme = ThemeStore(activeCoachID: "ace")

    var body: some Scene {
        WindowGroup {
            AppShellRoot(appContainer: container, themeStore: theme)
                .modelContainer(container.modelContainer)
        }
    }

    private static func makeAppContainer() -> AppContainer {
        let modelContainer: ModelContainer
        do {
            let url = URL.applicationSupportDirectory.appending(path: "pulse.sqlite")
            try? FileManager.default.createDirectory(
                at: URL.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            modelContainer = try PulseModelContainer.onDisk(url: url)
        } catch {
            assertionFailure("Persistence setup failed: \(error). Falling back to in-memory.")
            modelContainer = try! PulseModelContainer.inMemory()
        }
        let api = APIClient(config: APIClientConfig(
            workerURL: Secrets.workerURL,
            deviceToken: Secrets.deviceToken
        ))
        // `LiveMirroredSessionObserver` uses `HKLiveWorkoutBuilder`, which is iOS 26+
        // (project deployment target is iOS 17). Pre-iOS-26 devices fall back to the
        // protocol fake — HR card stays inert, but the rest of the app boots.
        let mirroredObserver: any MirroredSessionObserver
        if #available(iOS 26.0, *) {
            mirroredObserver = LiveMirroredSessionObserver()
        } else {
            mirroredObserver = FakeMirroredObserver()
        }
        return AppContainer(modelContainer: modelContainer, api: api, manifestURL: Secrets.manifestURL,
                            healthKit: HealthKitClient.live(),
                            transport: LiveWatchSessionTransport(),
                            mirroredObserver: mirroredObserver)
    }
}
