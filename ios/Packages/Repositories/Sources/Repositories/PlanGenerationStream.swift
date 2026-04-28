import Foundation
import CoreModels

/// Live updates from a plan-generation request. UI subscribes to this stream
/// and renders thinking-state checkpoints + the final parsed plan.
public enum PlanStreamUpdate: Sendable {
    case checkpoint(String)
    case textDelta(String)              // user-visible passthrough text
    case done(WorkoutPlan, modelUsed: String, promptTokens: Int, completionTokens: Int)
}
