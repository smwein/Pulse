import Foundation
import SwiftData

@Model
public final class ExerciseAssetEntity {
    @Attribute(.unique) public var id: String   // matches catalog manifest ID
    public var name: String
    public var focus: String
    public var level: String
    public var kind: String
    public var equipment: [String]
    public var videoURL: URL
    public var posterURL: URL
    @Attribute(.externalStorage) public var instructionsJSON: Data
    public var manifestVersion: Int

    public init(id: String, name: String, focus: String, level: String, kind: String,
                equipment: [String], videoURL: URL, posterURL: URL,
                instructionsJSON: Data, manifestVersion: Int) {
        self.id = id
        self.name = name
        self.focus = focus
        self.level = level
        self.kind = kind
        self.equipment = equipment
        self.videoURL = videoURL
        self.posterURL = posterURL
        self.instructionsJSON = instructionsJSON
        self.manifestVersion = manifestVersion
    }
}
