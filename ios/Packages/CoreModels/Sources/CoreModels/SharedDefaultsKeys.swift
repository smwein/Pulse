import Foundation

/// UserDefaults keys shared across packages so Home and InWorkout don't need
/// to reference each other directly.
public enum SharedDefaultsKeys {
    /// Set true when the Watch reports `LifecycleEvent.failed(.healthKitDenied)`.
    /// Cleared by user dismissal.
    public static let watchHKDeniedBanner = "pulse.watch.hkDenied"
    /// Set true when the user taps the banner's dismiss control.
    public static let watchHKDeniedBannerDismissed = "pulse.watch.hkDeniedDismissed"
}
