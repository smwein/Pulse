import SwiftUI
import DesignSystem
import HealthKitClient

public struct HealthStepView: View {
    @Binding var didConnect: Bool
    private let client: HealthKitClient

    public init(didConnect: Binding<Bool>, client: HealthKitClient = .live()) {
        self._didConnect = didConnect
        self.client = client
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Connect Apple Health")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pulse reads your last 7 days of activity, heart rate, and sleep to personalize the plan and adapt it after each session. Read-only — Pulse never writes to Health.")
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            VStack(spacing: PulseSpacing.md) {
                PulseButton(didConnect ? "Connected" : "Connect", variant: .primary) {
                    Task {
                        try? await client.requestAuthorization()
                        await MainActor.run { didConnect = true }
                    }
                }
                .disabled(didConnect)
                Text("You can change this later in Settings.")
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
