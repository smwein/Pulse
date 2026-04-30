import Foundation

public final class SetLogOutbox: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "co.simpleav.pulse.watchbridge.outbox")

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("pending-set-logs.json")
    }

    public func enqueue(_ log: SetLogDTO) throws {
        try queue.sync {
            var current = try loadLocked()
            current.removeAll { $0.naturalKey == log.naturalKey }
            current.append(log)
            try saveLocked(current)
        }
    }

    public func pending() throws -> [SetLogDTO] {
        try queue.sync { try loadLocked() }
    }

    public func drain(naturalKey: String) throws {
        try queue.sync {
            var current = try loadLocked()
            current.removeAll { $0.naturalKey == naturalKey }
            try saveLocked(current)
        }
    }

    private func loadLocked() throws -> [SetLogDTO] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SetLogDTO].self, from: data)
    }
    private func saveLocked(_ logs: [SetLogDTO]) throws {
        let data = try JSONEncoder().encode(logs)
        try data.write(to: fileURL, options: .atomic)
    }
}
