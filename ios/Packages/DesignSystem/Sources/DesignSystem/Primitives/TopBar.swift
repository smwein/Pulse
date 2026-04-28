import SwiftUI

public struct TopBar<Trailing: View>: View {
    public let eyebrow: String?
    public let title: String
    private let trailing: Trailing

    public init(eyebrow: String? = nil, title: String,
                @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .pulseFont(.eyebrow)
                        .foregroundStyle(PulseColors.ink2.color)
                }
                Text(title)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }
}
