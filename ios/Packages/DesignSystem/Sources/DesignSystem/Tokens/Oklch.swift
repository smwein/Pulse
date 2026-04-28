import Foundation

/// oklch (L=0...1, C=0+, h=degrees 0...360) → linear sRGB → sRGB.
/// Formulas per https://bottosson.github.io/posts/oklab/ and CSS Color Module 4.
public struct Oklch: Hashable, Sendable {
    public var L: Double      // 0...1 (CSS uses 0%...100%)
    public var C: Double      // 0...~0.4 typical
    public var h: Double      // degrees 0...360

    public init(L: Double, C: Double, h: Double) {
        self.L = L
        self.C = C
        self.h = h
    }

    public func toLinearSrgb() -> LinearSrgb {
        let hRad = h * .pi / 180
        let a = C * cos(hRad)
        let b = C * sin(hRad)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return LinearSrgb(r: r, g: g, b: bb)
    }
}

public struct LinearSrgb: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public func toSrgb() -> Srgb {
        func encode(_ x: Double) -> Double {
            let clamped = max(0, min(1, x))
            return clamped <= 0.0031308
                ? 12.92 * clamped
                : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
        return Srgb(r: encode(r), g: encode(g), b: encode(b))
    }
}

public struct Srgb: Hashable, Sendable {
    public var r: Double      // 0...1
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}
