import Foundation

public struct OnboardingDraft: Hashable, Sendable {
    public var displayName: String
    public var goals: [String]
    public var level: Profile.Level?
    public var equipment: [String]
    public var frequencyPerWeek: Int?
    public var weeklyTargetMinutes: Int?
    public var activeCoachID: String?

    public init() {
        self.displayName = ""
        self.goals = []
        self.level = nil
        self.equipment = []
        self.frequencyPerWeek = nil
        self.weeklyTargetMinutes = nil
        self.activeCoachID = nil
    }

    /// Returns a fully formed Profile if every required field is set, else nil.
    public func buildProfile(now: Date) -> Profile? {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty,
              !goals.isEmpty,
              let level,
              !equipment.isEmpty,
              let frequencyPerWeek,
              let weeklyTargetMinutes,
              let activeCoachID else { return nil }
        return Profile(
            id: UUID(),
            displayName: displayName,
            goals: goals,
            level: level,
            equipment: equipment,
            frequencyPerWeek: frequencyPerWeek,
            weeklyTargetMinutes: weeklyTargetMinutes,
            activeCoachID: activeCoachID,
            createdAt: now
        )
    }

    public enum Step: Int, CaseIterable, Sendable {
        case name = 1, goals, level, equipment, frequency, coach, health
    }

    /// Returns true if the user can advance past `step` with current draft state.
    public func canAdvance(from step: Step) -> Bool {
        switch step {
        case .name:      return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .goals:     return !goals.isEmpty
        case .level:     return level != nil
        case .equipment: return !equipment.isEmpty
        case .frequency: return frequencyPerWeek != nil && weeklyTargetMinutes != nil
        case .coach:     return activeCoachID != nil
        case .health:    return true   // Skip is allowed
        }
    }
}
