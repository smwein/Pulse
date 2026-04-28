import SwiftUI

/// A token color: holds the source oklch + a derived SwiftUI Color computed once.
public struct PulseColor: Hashable, Sendable {
    public let oklch: Oklch
    public let opacity: Double

    public init(_ oklch: Oklch, opacity: Double = 1) {
        self.oklch = oklch
        self.opacity = opacity
    }

    public var color: Color {
        let srgb = oklch.toLinearSrgb().toSrgb()
        return Color(.sRGB, red: srgb.r, green: srgb.g, blue: srgb.b, opacity: opacity)
    }
}

public enum PulseColors {
    // Backgrounds (dark → less dark)
    public static let bg0 = PulseColor(Oklch(L: 0.16, C: 0.005, h: 60))
    public static let bg1 = PulseColor(Oklch(L: 0.20, C: 0.006, h: 60))
    public static let bg2 = PulseColor(Oklch(L: 0.24, C: 0.008, h: 60))
    public static let bg3 = PulseColor(Oklch(L: 0.30, C: 0.010, h: 60))

    // Lines / dividers
    public static let line = PulseColor(Oklch(L: 0.32, C: 0.008, h: 60), opacity: 0.6)
    public static let lineSoft = PulseColor(Oklch(L: 0.40, C: 0.008, h: 60), opacity: 0.25)

    // Ink (text, brightest → dimmest)
    public static let ink0 = PulseColor(Oklch(L: 0.97, C: 0.005, h: 80))
    public static let ink1 = PulseColor(Oklch(L: 0.82, C: 0.008, h: 80))
    public static let ink2 = PulseColor(Oklch(L: 0.64, C: 0.010, h: 80))
    public static let ink3 = PulseColor(Oklch(L: 0.46, C: 0.012, h: 80))

    // Functional
    public static let good = PulseColor(Oklch(L: 0.78, C: 0.14, h: 150))
    public static let warn = PulseColor(Oklch(L: 0.78, C: 0.14, h: 80))
}
