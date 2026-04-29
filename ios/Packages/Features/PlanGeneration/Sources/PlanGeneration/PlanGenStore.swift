import Foundation
import Observation
import CoreModels
import Repositories

public protocol WorkoutHandle: Sendable {
    var id: UUID { get }
    var title: String { get }
}

public enum PlanGenMode: Sendable {
    case firstPlan
    case regenerate
}

@MainActor
@Observable
public final class PlanGenStore {
    public enum State {
        case streaming(checkpoints: [String], text: String, attempt: Int)
        case done(any WorkoutHandle)
        case failed(Error)
    }

    public private(set) var state: State = .streaming(checkpoints: [], text: "", attempt: 1)
    public let coach: Coach
    public let mode: PlanGenMode

    public typealias StreamProvider = (Profile) -> AsyncThrowingStream<PlanStreamUpdate, Error>
    public typealias OnPersistedWorkout = (WorkoutPlan, [UUID]) -> (any WorkoutHandle)?

    private let streamProvider: StreamProvider
    private let onPersistedWorkout: OnPersistedWorkout
    private static let maxVisibleLines = 6

    public init(coach: Coach,
                mode: PlanGenMode,
                streamProvider: @escaping StreamProvider,
                onPersistedWorkout: @escaping OnPersistedWorkout) {
        self.coach = coach
        self.mode = mode
        self.streamProvider = streamProvider
        self.onPersistedWorkout = onPersistedWorkout
    }

    public func run(profile: Profile) async {
        await runAttempt(profile: profile, attempt: 1)
    }

    public func retry(profile: Profile) async {
        state = .streaming(checkpoints: [], text: "", attempt: 1)
        await runAttempt(profile: profile, attempt: 1)
    }

    private func runAttempt(profile: Profile, attempt: Int) async {
        state = .streaming(checkpoints: [], text: "", attempt: attempt)
        do {
            let stream = streamProvider(profile)
            for try await update in stream {
                apply(update)
                if case .done = state { return }
            }
        } catch {
            if attempt == 1 {
                await runAttempt(profile: profile, attempt: 2)
            } else {
                state = .failed(error)
            }
        }
    }

    private func apply(_ update: PlanStreamUpdate) {
        guard case .streaming(var cps, var text, let attempt) = state else { return }
        switch update {
        case .checkpoint(let label):
            cps.append(label)
            state = .streaming(checkpoints: cps, text: text, attempt: attempt)
        case .textDelta(let chunk):
            text += chunk
            text = Self.trimToLastLines(text, count: Self.maxVisibleLines)
            state = .streaming(checkpoints: cps, text: text, attempt: attempt)
        case .done(let plan, let ids, _, _, _):
            if let handle = onPersistedWorkout(plan, ids) {
                state = .done(handle)
            } else {
                state = .failed(NoWorkoutHandleError())
            }
        }
    }

    private static func trimToLastLines(_ text: String, count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > count else { return text }
        return lines.suffix(count).joined(separator: "\n")
    }
}

private struct NoWorkoutHandleError: Error {}
