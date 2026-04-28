import Foundation

public struct Profile: Codable, Hashable, Sendable, Identifiable {
    public enum Level: String, Codable, Hashable, Sendable {
        case new, regular, experienced, athlete
    }

    public var id: UUID
    public var displayName: String
    public var goals: [String]
    public var level: Level
    public var equipment: [String]
    public var frequencyPerWeek: Int
    public var weeklyTargetMinutes: Int
    public var activeCoachID: String
    public var createdAt: Date

    public init(id: UUID, displayName: String, goals: [String], level: Level,
                equipment: [String], frequencyPerWeek: Int, weeklyTargetMinutes: Int,
                activeCoachID: String, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.goals = goals
        self.level = level
        self.equipment = equipment
        self.frequencyPerWeek = frequencyPerWeek
        self.weeklyTargetMinutes = weeklyTargetMinutes
        self.activeCoachID = activeCoachID
        self.createdAt = createdAt
    }
}
