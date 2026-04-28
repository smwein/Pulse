import SwiftUI

public struct IconButton: View {
    public let systemName: String
    public let action: () -> Void

    public init(systemName: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(PulseColors.ink1.color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadius.sm, style: .continuous)
                        .fill(PulseColors.bg1.color)
                )
        }
        .buttonStyle(.plain)
    }
}
