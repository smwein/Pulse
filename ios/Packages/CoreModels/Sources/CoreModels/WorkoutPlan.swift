import Foundation

public struct WorkoutPlan: Codable, Hashable, Sendable {
    public var weekStart: Date
    public var workouts: [PlannedWorkout]

    public init(weekStart: Date, workouts: [PlannedWorkout]) {
        self.weekStart = weekStart
        self.workouts = workouts
    }
}

public struct PlannedWorkout: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var scheduledFor: Date
    public var title: String
    public var subtitle: String
    public var workoutType: String   // "Strength" | "HIIT" | "Mobility" | ...
    public var durationMin: Int
    public var blocks: [WorkoutBlock]
    public var why: String?

    public init(id: String, scheduledFor: Date, title: String, subtitle: String,
                workoutType: String, durationMin: Int, blocks: [WorkoutBlock],
                why: String? = nil) {
        self.id = id
        self.scheduledFor = scheduledFor
        self.title = title
        self.subtitle = subtitle
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.blocks = blocks
        self.why = why
    }
}

public struct WorkoutBlock: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String          // "Warm-up" | "Main" | "Cooldown"
    public var exercises: [PlannedExercise]

    public init(id: String, label: String, exercises: [PlannedExercise]) {
        self.id = id
        self.label = label
        self.exercises = exercises
    }
}

public struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String             // unique within plan
    public var exerciseID: String     // matches catalog manifest id
    public var name: String
    public var sets: [PlannedSet]

    public init(id: String, exerciseID: String, name: String, sets: [PlannedSet]) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.sets = sets
    }
}

public struct PlannedSet: Codable, Hashable, Sendable {
    public var setNum: Int
    public var reps: Int
    public var load: String           // "BW" | "60 kg" | "0:30"
    public var restSec: Int

    public init(setNum: Int, reps: Int, load: String, restSec: Int) {
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.restSec = restSec
    }
}

public extension JSONEncoder {
    static let pulse: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}

public extension JSONDecoder {
    static let pulse: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: str) { return date }
            if let date = fallback.date(from: str) { return date }
            if let date = dateOnly.date(from: str) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unparseable date: \(str)")
            )
        }
        return d
    }()
}
