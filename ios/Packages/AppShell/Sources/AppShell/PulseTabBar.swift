import SwiftUI
import DesignSystem

public enum PulseTab: Hashable {
    case today, progress, debug
}

public struct PulseTabBar: View {
    @Binding public var selected: PulseTab
    @Environment(\.pulseTheme) private var theme

    public init(selected: Binding<PulseTab>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            tabButton(.today, label: "Today", systemImage: "flame")
            tabButton(.progress, label: "Progress", systemImage: "chart.line.uptrend.xyaxis")
            tabButton(.debug, label: "Debug", systemImage: "ladybug")
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(PulseColors.bg1.color)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(PulseColors.line.color)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }

    private func tabButton(_ tab: PulseTab, label: String, systemImage: String) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                Text(label).pulseFont(.eyebrow)
            }
            .foregroundStyle(selected == tab ? theme.accent.base.color : PulseColors.ink2.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadius.sm)
                    .fill(selected == tab ? PulseColors.bg2.color : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
