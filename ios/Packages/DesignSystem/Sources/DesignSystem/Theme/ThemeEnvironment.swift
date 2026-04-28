import SwiftUI

private struct ThemeStoreKey: EnvironmentKey {
    static let defaultValue: ThemeStore = ThemeStore()
}

public extension EnvironmentValues {
    var pulseTheme: ThemeStore {
        get { self[ThemeStoreKey.self] }
        set { self[ThemeStoreKey.self] = newValue }
    }
}

public extension View {
    func pulseTheme(_ store: ThemeStore) -> some View {
        self.environment(\.pulseTheme, store)
    }
}
