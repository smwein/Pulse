import SwiftUI

public struct RestView: View {
    public let secondsRemaining: Int
    public let onSkip: () -> Void
    public init(secondsRemaining: Int, onSkip: @escaping () -> Void) {
        self.secondsRemaining = secondsRemaining; self.onSkip = onSkip
    }
    public var body: some View {
        VStack(spacing: 8) {
            Text("Rest").font(.headline)
            Text("\(secondsRemaining)s").font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Button("Skip", action: onSkip).buttonStyle(.bordered).controlSize(.small)
        }
    }
}
