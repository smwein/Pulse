import Foundation

public struct WorkoutPayloadDTO: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let workoutID: UUID
    public let title: String
    /// Mirrors HKWorkoutActivityType raw string so Watch can derive the activity type.
    public let activityKind: String
    public let exercises: [Exercise]

    public struct Exercise: Codable, Equatable, Sendable {
        public let exerciseID: String
        public let name: String
        public let sets: [SetPrescription]
        public init(exerciseID: String, name: String, sets: [SetPrescription]) {
            self.exerciseID = exerciseID; self.name = name; self.sets = sets
        }
    }

    public struct SetPrescription: Codable, Equatable, Sendable {
        public let setNum: Int
        public let prescribedReps: Int
        public let prescribedLoad: String
        public init(setNum: Int, prescribedReps: Int, prescribedLoad: String) {
            self.setNum = setNum; self.prescribedReps = prescribedReps; self.prescribedLoad = prescribedLoad
        }
    }

    public init(sessionID: UUID, workoutID: UUID, title: String,
                activityKind: String, exercises: [Exercise]) {
        self.sessionID = sessionID; self.workoutID = workoutID
        self.title = title; self.activityKind = activityKind; self.exercises = exercises
    }
}
