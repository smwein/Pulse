import SwiftUI
import DesignSystem
import Networking

struct DebugStreamView: View {
    let api: APIClient
    let themeStore: ThemeStore

    @State private var lines: [String] = ["⟦ ready ⟧"]
    @State private var inFlight = false
    @State private var selectedCoach: String = "ace"

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            HStack(spacing: PulseSpacing.sm) {
                ForEach(["ace", "rex", "vera", "mira"], id: \.self) { id in
                    PulsePill(id.uppercased(), variant: selectedCoach == id ? .accent : .default)
                        .onTapGesture {
                            selectedCoach = id
                            themeStore.setActiveCoach(id: id)
                        }
                }
            }

            consoleView

            PulseButton(inFlight ? "Streaming…" : "Ping worker",
                        variant: .primary, size: .large) {
                Task { await runSmoke() }
            }
            .disabled(inFlight)
            .opacity(inFlight ? 0.6 : 1)
        }
        .padding(PulseSpacing.lg)
    }

    private var consoleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .pulseFont(.mono)
                        .foregroundStyle(PulseColors.ink1.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(PulseSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .fill(PulseColors.bg1.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .strokeBorder(PulseColors.line.color, lineWidth: 1)
        )
    }

    private func runSmoke() async {
        inFlight = true
        defer { inFlight = false }
        lines.removeAll()
        lines.append("⟦ POST \(api.config.workerURL.absoluteString) ⟧")

        let request = AnthropicRequest(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 64,
            system: "You are a brief assistant.",
            systemCacheControl: nil,
            messages: [.init(role: .user, content: "Say a one-word greeting.")]
        )
        do {
            for try await event in api.streamEvents(request: request) {
                let snippet = event.data.prefix(80)
                lines.append("· \(event.event): \(snippet)")
            }
            lines.append("⟦ done ⟧")
        } catch {
            lines.append("✗ \(String(describing: error))")
        }
    }
}
