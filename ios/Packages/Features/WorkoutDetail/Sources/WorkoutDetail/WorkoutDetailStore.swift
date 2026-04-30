import Foundation
import Observation
import SwiftData
import CoreModels
import Persistence
import Repositories
import OSLog

@MainActor
@Observable
public final class WorkoutDetailStore {
    public private(set) var workoutTitle: String = ""
    public private(set) var workoutSubtitle: String = ""
    public private(set) var workoutType: String = ""
    public private(set) var durationMin: Int = 0
    public private(set) var why: String?
    public private(set) var blocks: [WorkoutBlock] = []

    public let workoutID: UUID
    private let modelContainer: ModelContainer
    private let assetRepo: ExerciseAssetRepository
    private var assetsByID: [String: ExerciseAssetEntity] = [:]
    private let log = Logger(subsystem: "co.simpleav.pulse", category: "WorkoutDetail")

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                assetRepo: ExerciseAssetRepository) {
        self.workoutID = workoutID
        self.modelContainer = modelContainer
        self.assetRepo = assetRepo
    }

    public func load() async {
        let ctx = modelContainer.mainContext
        let id = workoutID
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try? ctx.fetch(descriptor).first else { return }
        workoutTitle = entity.title
        workoutSubtitle = entity.subtitle
        workoutType = entity.workoutType
        durationMin = entity.durationMin
        why = entity.why
        blocks = (try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: entity.blocksJSON)) ?? []
        await resolveAssets()
    }

    public func asset(for exerciseID: String) -> ExerciseAssetEntity? {
        assetsByID[exerciseID]
    }

    private func resolveAssets() async {
        let ids = Set(blocks.flatMap { $0.exercises.map { $0.exerciseID } })
        for id in ids {
            if let a = assetRepo.lookup(id: id) {
                assetsByID[id] = a
            } else {
                log.warning("asset miss for exerciseID=\(id, privacy: .public)")
            }
        }
    }
}
