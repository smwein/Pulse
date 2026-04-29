import Foundation
import SwiftData

@Model
public final class WorkoutEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var planID: UUID
    public var scheduledFor: Date
    public var title: String
    public var subtitle: String
    public var workoutType: String
    public var durationMin: Int
    public var status: String       // "scheduled" | "in_progress" | "completed" | "superseded"
    @Attribute(.externalStorage) public var blocksJSON: Data
    @Attribute(.externalStorage) public var exercisesJSON: Data
    @Attribute(.externalStorage) public var whispersJSON: Data?
    public var why: String?

    public init(id: UUID, userID: UUID? = nil, planID: UUID, scheduledFor: Date,
                title: String, subtitle: String, workoutType: String, durationMin: Int,
                status: String, blocksJSON: Data, exercisesJSON: Data,
                whispersJSON: Data? = nil, why: String? = nil) {
        self.id = id
        self.userID = userID
        self.planID = planID
        self.scheduledFor = scheduledFor
        self.title = title
        self.subtitle = subtitle
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.status = status
        self.blocksJSON = blocksJSON
        self.exercisesJSON = exercisesJSON
        self.whispersJSON = whispersJSON
        self.why = why
    }
}
