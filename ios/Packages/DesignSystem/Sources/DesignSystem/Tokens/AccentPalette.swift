import Foundation

/// Derives the 4 accent tones from a single hue (0...360).
/// Mirrors the design CSS:
///   --accent:      oklch(72% 0.18 var(--accent-h))
///   --accent-soft: oklch(72% 0.18 var(--accent-h) / 0.18)
///   --accent-ink:  oklch(20% 0.05 var(--accent-h))
///   --glow:        oklch(72% 0.18 var(--accent-h) / 0.5)  (used in box-shadow)
public struct AccentPalette: Hashable, Sendable {
    public let hue: Double
    public let base: PulseColor
    public let soft: PulseColor
    public let ink: PulseColor
    public let glow: PulseColor

    public init(hue: Int) {
        self.init(hue: Double(hue))
    }

    public init(hue: Double) {
        self.hue = hue
        self.base = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue))
        self.soft = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue), opacity: 0.18)
        self.ink  = PulseColor(Oklch(L: 0.20, C: 0.05, h: hue))
        self.glow = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue), opacity: 0.5)
    }
}
