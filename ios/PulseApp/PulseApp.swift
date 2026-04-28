import SwiftUI

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Pulse — bootstrap")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
        }
    }
}
