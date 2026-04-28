import SwiftUI
import DesignSystem
import Repositories

public struct RootScaffold<DebugContent: View>: View {
    @State private var selectedTab: PulseTab = .today
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let debugContent: () -> DebugContent

    public init(appContainer: AppContainer, themeStore: ThemeStore,
                @ViewBuilder debugContent: @escaping () -> DebugContent) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.debugContent = debugContent
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(eyebrow: "PULSE", title: tabTitle) {
                    IconButton(systemName: "wrench.and.screwdriver") {
                        selectedTab = .debug
                    }
                }
                Group {
                    switch selectedTab {
                    case .today: todayPlaceholder
                    case .progress: progressPlaceholder
                    case .debug: debugContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PulseTabBar(selected: $selectedTab)
            }
        }
        .pulseTheme(themeStore)
        .preferredColorScheme(.dark)
    }

    private var tabTitle: String {
        switch selectedTab {
        case .today:    return "Today"
        case .progress: return "Progress"
        case .debug:    return "Debug"
        }
    }

    private var todayPlaceholder: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.lg) {
                PulseCard {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("Today")
                            .pulseFont(.h2)
                            .foregroundStyle(PulseColors.ink0.color)
                        Text("Plan 2 foundation shell. Real feature ships in Plan 3.")
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink2.color)
                    }
                }
                ExercisePlaceholder(label: "PREVIEW")
                    .frame(height: 220)
            }
            .padding(PulseSpacing.lg)
        }
    }

    private var progressPlaceholder: some View {
        VStack(spacing: PulseSpacing.lg) {
            Ring(progress: 0.42)
            Text("Weekly ring (placeholder)")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
