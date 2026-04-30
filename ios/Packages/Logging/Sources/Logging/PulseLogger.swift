import Foundation
import os

/// Thin wrapper over `os.Logger` with pre-built category loggers.
/// Plan 7 will add a Sentry transport that observes `.error` and `.fault` levels.
public struct PulseLogger: Sendable {
    public let subsystem: String
    public let category: String
    private let backing: Logger

    public init(subsystem: String = "co.simpleav.pulse", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.backing = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) { backing.debug("\(message, privacy: .public)") }
    public func info(_ message: String)  { backing.info("\(message, privacy: .public)") }
    public func notice(_ message: String){ backing.notice("\(message, privacy: .public)") }
    public func warning(_ message: String){ backing.warning("\(message, privacy: .public)") }
    public func error(_ message: String, _ error: Error? = nil) {
        if let error {
            backing.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
        } else {
            backing.error("\(message, privacy: .public)")
        }
    }
    public func fault(_ message: String, _ error: Error? = nil) {
        if let error {
            backing.fault("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
        } else {
            backing.fault("\(message, privacy: .public)")
        }
    }

    public static let bridge    = PulseLogger(category: "bridge")
    public static let session   = PulseLogger(category: "session")
    public static let healthkit = PulseLogger(category: "healthkit")
    public static let repo      = PulseLogger(category: "repo")
}
