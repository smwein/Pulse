import SwiftUI
import WatchWorkout

@main
struct PulseWatchApp: App {
    @State private var container = WatchAppContainer()
    var body: some Scene {
        WindowGroup {
            WatchAppRoot(store: container.store)
        }
    }
}
