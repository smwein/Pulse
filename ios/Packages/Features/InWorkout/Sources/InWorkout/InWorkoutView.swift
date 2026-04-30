import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreModels
import DesignSystem
import Persistence
import Repositories
import SwiftData

public struct InWorkoutView: View {
    @State private var store: SessionStore
    @State private var elapsedSec: Int = 0
    @State private var sessionStartTime: Date = Date()
    @State private var showDiscardAlert = false
    private let onComplete: (UUID) -> Void
    private let onDiscard: () -> Void

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                flat: [SessionStore.FlatEntry],
                onComplete: @escaping (UUID) -> Void,
                onDiscard: @escaping () -> Void) {
        let repo = SessionRepository(modelContainer: modelContainer)
        _store = State(initialValue: SessionStore(workoutID: workoutID, flat: flat, repo: repo))
        self.onComplete = onComplete
        self.onDiscard = onDiscard
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                topBar
                ProgressSegmentsView(total: store.flat.count, completed: store.idx)
                if let cur = store.current {
                    ExerciseCardView(blockLabel: cur.blockLabel,
                                     exerciseName: cur.exerciseName,
                                     setIndexLabel: setLabel(cur))
                }
                LiveMetricsGridView(
                    elapsed: format(elapsedSec),
                    restRemaining: store.phase == .rest ? formatRest() : "—",
                    avgHR: "—")

                if store.phase == .rest, let cur = store.current {
                    RestPhaseView(restRemaining: max(0, cur.restSec - store.secs),
                                  nextLabel: cur.exerciseName)
                } else if store.current != nil {
                    SetLogCardView(reps: $store.draft.reps,
                                   load: $store.draft.load,
                                   rpe: $store.draft.rpe,
                                   prescribedReps: store.current?.prescribedReps ?? 0,
                                   prescribedLoad: store.current?.prescribedLoad ?? "")
                }
                Spacer()
                BottomControlsView(
                    primaryLabel: store.phase == .rest ? "Skip rest" : "Log set \(store.current?.setNum ?? 0)",
                    onPrimary: { Task { await onPrimaryTap() } },
                    onSkipRest: store.phase == .rest ? { skipRest() } : nil)
            }
            .padding(PulseSpacing.lg)
        }
        .preferredColorScheme(.dark)
        .task { await onAppear() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
        .alert("Discard workout?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                Task {
                    await store.discard()
                    onDiscard()
                }
            }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("Your sets so far won't be saved.")
        }
        .onAppear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { showDiscardAlert = true }) {
                Image(systemName: "xmark")
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            Spacer()
            Text("LIVE")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
    }

    private func setLabel(_ cur: SessionStore.FlatEntry) -> String {
        let sameEx = store.flat.filter { $0.exerciseID == cur.exerciseID }
        return "SET \(cur.setNum) OF \(sameEx.count)"
    }

    private func format(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func formatRest() -> String {
        guard let cur = store.current else { return "—" }
        return format(max(0, cur.restSec - store.secs))
    }

    private func onAppear() async {
        sessionStartTime = Date()
        await store.start()
        store.onLifecycle = { [self] event in
            switch event {
            case .completed(let session):
                onComplete(session.id)
            case .discarded:
                break
            }
        }
    }

    private func tick() {
        elapsedSec = Int(Date().timeIntervalSince(sessionStartTime))
        store.tick(by: 1)
    }

    private func skipRest() {
        guard store.phase == .rest else { return }
        if let cur = store.current {
            store.tick(by: cur.restSec)
        }
    }

    private func onPrimaryTap() async {
        if store.phase == .rest {
            skipRest()
        } else {
            await store.logCurrentSet()
        }
    }
}
