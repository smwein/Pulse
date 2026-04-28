import Foundation
import SwiftData

public enum PulseModelContainer {
    /// Aggregates every @Model used by the app. Entities are appended here as they're added.
    public static var schema: Schema {
        Schema([
            ProfileEntity.self,
            PlanEntity.self,
            WorkoutEntity.self,
            SessionEntity.self,
            SetLogEntity.self,
            FeedbackEntity.self,
            AdaptationEntity.self,
            ExerciseAssetEntity.self,
        ])
    }

    public static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func onDisk(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(url: url)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
