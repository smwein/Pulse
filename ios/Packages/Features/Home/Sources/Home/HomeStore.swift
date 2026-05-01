import Foundation
import Observation
import CoreModels
import Persistence
import Repositories

@MainActor
@Observable
public final class HomeStore {
    public private(set) var todaysWorkout: WorkoutEntity?
    public private(set) var profile: Profile?
    public private(set) var watchHKDeniedBannerVisible: Bool

    private let workoutRepo: WorkoutRepository
    private let profileRepo: ProfileRepository
    private let defaults: UserDefaults

    public init(workoutRepo: WorkoutRepository, profileRepo: ProfileRepository,
                defaults: UserDefaults = .standard) {
        self.workoutRepo = workoutRepo
        self.profileRepo = profileRepo
        self.defaults = defaults
        self.watchHKDeniedBannerVisible =
            defaults.bool(forKey: SharedDefaultsKeys.watchHKDeniedBanner)
            && !defaults.bool(forKey: SharedDefaultsKeys.watchHKDeniedBannerDismissed)
    }

    public func refresh() async {
        profile = profileRepo.currentProfile()
        todaysWorkout = try? workoutRepo.latestWorkout()
        // Re-read in case a background bridge wrote the flag while we were away.
        watchHKDeniedBannerVisible =
            defaults.bool(forKey: SharedDefaultsKeys.watchHKDeniedBanner)
            && !defaults.bool(forKey: SharedDefaultsKeys.watchHKDeniedBannerDismissed)
    }

    public func setWatchHKDenied() {
        defaults.set(true, forKey: SharedDefaultsKeys.watchHKDeniedBanner)
        watchHKDeniedBannerVisible =
            !defaults.bool(forKey: SharedDefaultsKeys.watchHKDeniedBannerDismissed)
    }

    public func dismissWatchHKBanner() {
        defaults.set(true, forKey: SharedDefaultsKeys.watchHKDeniedBannerDismissed)
        watchHKDeniedBannerVisible = false
    }
}
