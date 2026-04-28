import Foundation

public struct AdaptationDiff: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var rationale: String
    public var changes: [Change]

    public enum Change: Codable, Hashable, Sendable {
        case swap(from: String, to: String, reason: String)
        case reps(exerciseID: String, from: Int, to: Int, reason: String)
        case load(exerciseID: String, from: String, to: String, reason: String)
        case remove(exerciseID: String, reason: String)
        case add(exerciseID: String, afterExerciseID: String?, reason: String)

        private enum CodingKeys: String, CodingKey {
            case op, from, to, exerciseID, afterExerciseID, reason
        }

        private enum Op: String, Codable { case swap, reps, load, remove, add }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let op = try c.decode(Op.self, forKey: .op)
            let reason = try c.decode(String.self, forKey: .reason)
            switch op {
            case .swap:
                self = .swap(from: try c.decode(String.self, forKey: .from),
                             to: try c.decode(String.self, forKey: .to),
                             reason: reason)
            case .reps:
                self = .reps(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                             from: try c.decode(Int.self, forKey: .from),
                             to: try c.decode(Int.self, forKey: .to),
                             reason: reason)
            case .load:
                self = .load(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                             from: try c.decode(String.self, forKey: .from),
                             to: try c.decode(String.self, forKey: .to),
                             reason: reason)
            case .remove:
                self = .remove(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                               reason: reason)
            case .add:
                self = .add(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                            afterExerciseID: try c.decodeIfPresent(String.self, forKey: .afterExerciseID),
                            reason: reason)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .swap(from, to, reason):
                try c.encode(Op.swap, forKey: .op)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .reps(exID, from, to, reason):
                try c.encode(Op.reps, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .load(exID, from, to, reason):
                try c.encode(Op.load, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .remove(exID, reason):
                try c.encode(Op.remove, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(reason, forKey: .reason)
            case let .add(exID, after, reason):
                try c.encode(Op.add, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encodeIfPresent(after, forKey: .afterExerciseID)
                try c.encode(reason, forKey: .reason)
            }
        }
    }

    public init(generatedAt: Date, rationale: String, changes: [Change]) {
        self.generatedAt = generatedAt
        self.rationale = rationale
        self.changes = changes
    }
}
