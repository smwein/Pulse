import SwiftUI

public enum PulseFontFamily: Hashable, Sendable {
    case display    // Instrument Serif (italic display)
    case sans       // Inter Tight / system fallback
    case mono       // JetBrains Mono / SF Mono fallback

    /// Maps to a SwiftUI font family. We use system fonts as fallbacks; custom font
    /// registration is out of scope for Plan 2 — bundled font assets land in Plan 3.
    public var systemFallback: Font.Design {
        switch self {
        case .display: return .serif
        case .sans:    return .default
        case .mono:    return .monospaced
        }
    }
}

public struct PulseFont: Hashable, Sendable {
    public let family: PulseFontFamily
    public let size: CGFloat
    public let weight: Font.Weight
    public let italic: Bool
    public let lineHeightMultiple: CGFloat
    public let trackingEm: Double

    public init(family: PulseFontFamily, size: CGFloat, weight: Font.Weight,
                italic: Bool = false, lineHeightMultiple: CGFloat = 1.2, trackingEm: Double = 0) {
        self.family = family
        self.size = size
        self.weight = weight
        self.italic = italic
        self.lineHeightMultiple = lineHeightMultiple
        self.trackingEm = trackingEm
    }

    public var swiftUIFont: Font {
        var f = Font.system(size: size, weight: weight, design: family.systemFallback)
        if italic { f = f.italic() }
        return f
    }
}

public extension PulseFont {
    static let eyebrow = PulseFont(family: .mono, size: 11, weight: .regular,
                                   lineHeightMultiple: 1.0, trackingEm: 0.14)
    static let display = PulseFont(family: .display, size: 36, weight: .regular,
                                   italic: true, lineHeightMultiple: 0.95, trackingEm: -0.02)
    static let h1 = PulseFont(family: .sans, size: 28, weight: .semibold,
                              lineHeightMultiple: 1.1, trackingEm: -0.02)
    static let h2 = PulseFont(family: .sans, size: 22, weight: .semibold,
                              lineHeightMultiple: 1.15, trackingEm: -0.02)
    static let h3 = PulseFont(family: .sans, size: 17, weight: .semibold,
                              lineHeightMultiple: 1.2, trackingEm: -0.01)
    static let body = PulseFont(family: .sans, size: 15, weight: .regular,
                                lineHeightMultiple: 1.45)
    static let small = PulseFont(family: .sans, size: 13, weight: .regular,
                                 lineHeightMultiple: 1.4)
    static let mono = PulseFont(family: .mono, size: 13, weight: .regular,
                                lineHeightMultiple: 1.4)
}

public extension View {
    func pulseFont(_ token: PulseFont) -> some View {
        self.font(token.swiftUIFont)
            .tracking(CGFloat(token.trackingEm) * token.size)
    }
}
