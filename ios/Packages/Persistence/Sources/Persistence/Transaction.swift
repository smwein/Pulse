import Foundation
import SwiftData

public extension ModelContext {
    /// Perform multiple writes atomically on the main actor.
    ///
    /// - Suspends autosave for the duration of `body` so that a mid-body throw
    ///   can be rolled back cleanly.
    /// - On success: calls `save()` and restores the previous autosave state.
    /// - On throw: calls `rollback()` to discard all pending changes, then rethrows.
    ///
    /// Named `atomicWrite` rather than `transaction` to avoid shadowing
    /// `ModelContext.transaction(block:)` from the SwiftData SDK (which does
    /// not roll back on throw).
    @MainActor
    func atomicWrite(_ body: @MainActor () throws -> Void) throws {
        let wasAutosaving = autosaveEnabled
        autosaveEnabled = false
        defer { autosaveEnabled = wasAutosaving }
        do {
            try body()
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}
