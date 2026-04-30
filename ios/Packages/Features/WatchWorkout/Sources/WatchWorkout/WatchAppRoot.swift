import SwiftUI

public struct WatchAppRoot: View {
    @Bindable public var store: WatchSessionStore
    public init(store: WatchSessionStore) { self.store = store }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .ready:
                IdleView(payload: store.payload) {
                    Task { try? await store.start() }
                }
            case .starting:
                ProgressView("Starting…")
            case .active:
                if let exID = store.currentExerciseID,
                   let setNum = store.currentSetNum,
                   let payload = store.payload,
                   let ex = payload.exercises.first(where: { $0.exerciseID == exID }),
                   let pres = ex.sets.first(where: { $0.setNum == setNum })
                {
                    ActiveSetView(exerciseName: ex.name, setNum: setNum,
                                  totalSets: ex.sets.count,
                                  prescribedReps: pres.prescribedReps,
                                  prescribedLoad: pres.prescribedLoad) {
                        Task { await store.confirmCurrentSet() }
                    }
                } else {
                    Text("Workout complete").font(.headline)
                }
            case .resting:
                RestView(secondsRemaining: 60) {  // simple fixed for Plan 5
                    Task { await store.advanceFromRest() }
                }
            case .ended:
                Text("Done").font(.headline)
            case .failed(let reason):
                Text("Couldn't start (\(reason.rawValue))")
                    .multilineTextAlignment(.center).font(.caption)
            }
        }
    }
}
