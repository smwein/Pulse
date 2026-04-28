import SwiftUI

public enum PulseMotion {
    public static let fast: Double = 0.18
    public static let standard: Double = 0.32
    public static let slow: Double = 0.6

    public static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: standard)
    public static let easeIn  = Animation.timingCurve(0.64, 0, 0.78, 0, duration: standard)
    public static let easeSoft = Animation.timingCurve(0.4, 0, 0.2, 1, duration: standard)
}
