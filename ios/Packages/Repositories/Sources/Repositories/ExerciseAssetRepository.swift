import Foundation
import SwiftData
import Persistence

public typealias DataFetcher = @Sendable (URL) async throws -> Data

@MainActor
public final class ExerciseAssetRepository {
    public let modelContainer: ModelContainer
    public let manifestURL: URL
    private let fetcher: DataFetcher

    public init(modelContainer: ModelContainer, manifestURL: URL,
                fetcher: @escaping DataFetcher = ExerciseAssetRepository.urlSessionFetcher) {
        self.modelContainer = modelContainer
        self.manifestURL = manifestURL
        self.fetcher = fetcher
    }

    public static let urlSessionFetcher: DataFetcher = { url in
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    public func refreshFromManifest() async throws {
        let data = try await fetcher(manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        let context = modelContainer.mainContext
        for entry in manifest.exercises {
            let id = entry.id
            let descriptor = FetchDescriptor<ExerciseAssetEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.name = entry.name
                existing.focus = entry.focus
                existing.level = entry.level
                existing.kind = entry.kind
                existing.equipment = entry.equipmentList
                existing.videoURL = entry.videoURL
                existing.posterURL = entry.posterURL
                existing.instructionsJSON = (try? JSONEncoder().encode(entry.instructions)) ?? Data()
                existing.manifestVersion = manifest.version
            } else {
                let asset = ExerciseAssetEntity(
                    id: entry.id,
                    name: entry.name,
                    focus: entry.focus,
                    level: entry.level,
                    kind: entry.kind,
                    equipment: entry.equipmentList,
                    videoURL: entry.videoURL,
                    posterURL: entry.posterURL,
                    instructionsJSON: (try? JSONEncoder().encode(entry.instructions)) ?? Data(),
                    manifestVersion: manifest.version
                )
                context.insert(asset)
            }
        }
        try context.save()
    }

    public func allAssets() throws -> [ExerciseAssetEntity] {
        try modelContainer.mainContext.fetch(FetchDescriptor<ExerciseAssetEntity>())
    }

    public func lookup(id: String) -> ExerciseAssetEntity? {
        let descriptor = FetchDescriptor<ExerciseAssetEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContainer.mainContext.fetch(descriptor).first
    }

    // MARK: - Manifest decode types

    private struct Manifest: Decodable {
        let version: Int
        let exercises: [Entry]
    }

    /// Mirrors the shape published by `scripts/build-manifest.ts`.
    /// Real manifest fields: id, name, category, level, equipment (String?),
    /// primaryMuscles, secondaryMuscles, instructions, videoURL, posterURL.
    /// `focus` is stored as the category value; `kind` is derived from category
    /// (strength/stretching/cardio → strength/mobility/cardio).
    private struct Entry: Decodable {
        let id: String
        let name: String
        let category: String      // "strength" | "stretching" | "cardio" | …
        let level: String
        let equipment: String?    // single string in manifest, may be null
        let videoURL: URL
        let posterURL: URL
        let instructions: [String]

        var focus: String { category }

        /// Normalise category to the three kinds the rest of the app recognises.
        var kind: String {
            switch category.lowercased() {
            case "stretching": return "mobility"
            case "cardio":     return "cardio"
            default:           return "strength"
            }
        }

        /// Wrap the nullable single-string equipment value into an array.
        var equipmentList: [String] {
            guard let e = equipment, !e.isEmpty else { return [] }
            return [e]
        }
    }
}
