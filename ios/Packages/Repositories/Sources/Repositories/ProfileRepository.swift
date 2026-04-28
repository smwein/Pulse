import Foundation
import SwiftData
import CoreModels
import Persistence

@MainActor
public final class ProfileRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Returns the single Profile if onboarding has been completed.
    public func currentProfile() -> Profile? {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<ProfileEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let entity = try? ctx.fetch(descriptor).first else { return nil }
        guard let level = Profile.Level(rawValue: entity.level) else { return nil }
        return Profile(
            id: entity.id,
            displayName: entity.displayName,
            goals: entity.goals,
            level: level,
            equipment: entity.equipment,
            frequencyPerWeek: entity.frequencyPerWeek,
            weeklyTargetMinutes: entity.weeklyTargetMinutes,
            activeCoachID: entity.activeCoachID,
            createdAt: entity.createdAt
        )
    }

    /// Saves or updates the Profile, denormalizing `accentHue` from the Coach.
    public func save(_ profile: Profile) throws {
        let ctx = modelContainer.mainContext
        let id = profile.id
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let hue = Coach.byID(profile.activeCoachID)?.accentHue ?? 45
        if let existing = try ctx.fetch(descriptor).first {
            existing.displayName = profile.displayName
            existing.goals = profile.goals
            existing.level = profile.level.rawValue
            existing.equipment = profile.equipment
            existing.frequencyPerWeek = profile.frequencyPerWeek
            existing.weeklyTargetMinutes = profile.weeklyTargetMinutes
            existing.activeCoachID = profile.activeCoachID
            existing.accentHue = hue
        } else {
            ctx.insert(ProfileEntity(
                id: profile.id,
                displayName: profile.displayName,
                goals: profile.goals,
                level: profile.level.rawValue,
                equipment: profile.equipment,
                frequencyPerWeek: profile.frequencyPerWeek,
                weeklyTargetMinutes: profile.weeklyTargetMinutes,
                activeCoachID: profile.activeCoachID,
                accentHue: hue,
                createdAt: profile.createdAt
            ))
        }
        try ctx.save()
    }
}
