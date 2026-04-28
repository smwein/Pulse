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

    private let workoutRepo: WorkoutRepository
    private let profileRepo: ProfileRepository

    public init(workoutRepo: WorkoutRepository, profileRepo: ProfileRepository) {
        self.workoutRepo = workoutRepo
        self.profileRepo = profileRepo
    }

    public func refresh() async {
        profile = profileRepo.currentProfile()
        todaysWorkout = try? workoutRepo.latestWorkout()
    }
}
