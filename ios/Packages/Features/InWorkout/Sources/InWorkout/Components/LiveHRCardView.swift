import SwiftUI
import DesignSystem

public struct LiveHRCardView: View {
    @Bindable public var model: LiveHRCardModel
    public init(model: LiveHRCardModel) { self.model = model }
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill").foregroundStyle(.red)
            if let bpm = model.displayBPM {
                Text("\(bpm)").font(.system(.title3, design: .rounded)).bold()
                    .monospacedDigit()
                Text("bpm").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("—").font(.system(.title3, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
