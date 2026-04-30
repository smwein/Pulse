import SwiftUI
import WatchBridge

public struct IdleView: View {
    public let payload: WorkoutPayloadDTO?
    public let onStart: () -> Void
    public init(payload: WorkoutPayloadDTO?, onStart: @escaping () -> Void) {
        self.payload = payload; self.onStart = onStart
    }
    public var body: some View {
        VStack(spacing: 8) {
            if let p = payload {
                Text(p.title).font(.headline)
                Button("Start", action: onStart)
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Waiting for phone…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
