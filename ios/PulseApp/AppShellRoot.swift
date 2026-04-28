import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories
import AppShell

struct AppShellRoot: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    var body: some View {
        RootScaffold(appContainer: appContainer, themeStore: themeStore) {
            DebugStreamView(api: appContainer.api, themeStore: themeStore)
        }
    }
}
