import Foundation
import WatchBridge

public struct PayloadFileStorage: Sendable {
    public let url: URL
    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("active-workout-payload.json")
    }
    public func write(_ payload: WorkoutPayloadDTO) throws {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: .atomic)
    }
    public func read() throws -> WorkoutPayloadDTO? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
    }
    public func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
