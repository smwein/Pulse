import Foundation
import SwiftData

@Model
public final class ProfileEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var displayName: String
    public var goals: [String]
    public var level: String
    public var equipment: [String]
    public var frequencyPerWeek: Int
    public var weeklyTargetMinutes: Int
    public var activeCoachID: String
    public var accentHue: Int
    public var createdAt: Date

    public init(id: UUID, userID: UUID? = nil, displayName: String, goals: [String],
                level: String, equipment: [String], frequencyPerWeek: Int,
                weeklyTargetMinutes: Int, activeCoachID: String, accentHue: Int,
                createdAt: Date) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.goals = goals
        self.level = level
        self.equipment = equipment
        self.frequencyPerWeek = frequencyPerWeek
        self.weeklyTargetMinutes = weeklyTargetMinutes
        self.activeCoachID = activeCoachID
        self.accentHue = accentHue
        self.createdAt = createdAt
    }
}
