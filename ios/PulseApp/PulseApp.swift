import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories

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
        return AppContainer(modelContainer: modelContainer, api: api, manifestURL: Secrets.manifestURL)
    }
}
