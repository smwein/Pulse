import Foundation

/// Live updates from the adaptation SSE stream. UI subscribes to render the
/// thinking-state checkpoints, then the four-event result phase.
public enum AdaptationStreamEvent: Sendable {
    case checkpoint(String)
    case textDelta(String)              // raw passthrough during reasoning
    case adjustment(Adjustment)         // emit one per adjustment card
    case workout(PlannedWorkout)        // single Workout JSON for next scheduled date
    case rationale(String)              // coach voice 1-sentence summary
    case done(AdaptationPayload, modelUsed: String, promptTokens: Int, completionTokens: Int)
}
