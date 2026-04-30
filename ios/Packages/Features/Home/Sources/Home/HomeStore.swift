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
    public private(set) var weeklyStats: WeeklyProgressStats?

    private let workoutRepo: WorkoutRepository
    private let profileRepo: ProfileRepository

    public init(workoutRepo: WorkoutRepository, profileRepo: ProfileRepository) {
        self.workoutRepo = workoutRepo
        self.profileRepo = profileRepo
    }

    public func refresh() async {
        profile = profileRepo.currentProfile()
        todaysWorkout = try? workoutRepo.latestWorkout()
        weeklyStats = try? workoutRepo.weeklyProgress()
    }

    public var workoutActionLabel: String {
        switch todaysWorkout?.status {
        case "in_progress": return "Resume workout"
        case "completed": return "Review workout"
        case .some: return "Start workout"
        case .none: return "Generate today's workout"
        }
    }
}
