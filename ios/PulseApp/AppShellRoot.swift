import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories
import AppShell
import WatchBridge

struct AppShellRoot: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore
    let watchTransport: (any WatchSessionTransport)?

    var body: some View {
        FirstRunGate(appContainer: appContainer, themeStore: themeStore) {
            RootScaffold(
                appContainer: appContainer,
                themeStore: themeStore,
                watchTransport: watchTransport
            ) {
                DebugSwitcher(appContainer: appContainer, themeStore: themeStore)
            }
        }
    }
}

private struct DebugSwitcher: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore
    @State private var which: Which = .stream

    enum Which: String, CaseIterable, Identifiable {
        case stream = "Stream", smoke = "Smoke"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Debug", selection: $which) {
                ForEach(Which.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(PulseSpacing.md)
            switch which {
            case .stream: DebugStreamView(api: appContainer.api, themeStore: themeStore)
            case .smoke:  DebugFeatureSmokeView(appContainer: appContainer, themeStore: themeStore)
            }
        }
    }
}
