import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreModels
import DesignSystem
import HealthKitClient
import Persistence
import Repositories
import SwiftData
import WatchBridge
import WorkoutDetail

public struct InWorkoutView: View {
    @State private var store: SessionStore
    @State private var elapsedSec: Int = 0
    @State private var sessionStartTime: Date = Date()
    @State private var showDiscardAlert = false
    @State private var showExerciseSheet: Bool = false
    @State private var sheetExercise: PlannedExercise?
    @State private var sheetAsset: ExerciseAssetEntity?
    private let onComplete: (UUID) -> Void
    private let onDiscard: () -> Void
    private let assetRepo: ExerciseAssetRepository?
    private let transport: (any WatchSessionTransport)?
    private let mirroredObserver: (any MirroredSessionObserver)?

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                flat: [SessionStore.FlatEntry],
                assetRepo: ExerciseAssetRepository? = nil,
                transport: (any WatchSessionTransport)? = nil,
                mirroredObserver: (any MirroredSessionObserver)? = nil,
                healthKit: (any HealthKitAuthGate)? = nil,
                onComplete: @escaping (UUID) -> Void,
                onDiscard: @escaping () -> Void) {
        let repo = SessionRepository(modelContainer: modelContainer)
        _store = State(initialValue: SessionStore(workoutID: workoutID, flat: flat,
                                                  repo: repo, authGate: healthKit))
        self.assetRepo = assetRepo
        self.transport = transport
        self.mirroredObserver = mirroredObserver
        self.onComplete = onComplete
        self.onDiscard = onDiscard
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                topBar
                ProgressSegmentsView(total: store.flat.count, completed: store.idx)
                LiveHRCardView(model: store.hrCardModel)
                if let cur = store.current {
                    Button {
                        openExerciseSheet(for: cur)
                    } label: {
                        ExerciseCardView(blockLabel: cur.blockLabel,
                                         exerciseName: cur.exerciseName,
                                         setIndexLabel: setLabel(cur))
                    }
                    .buttonStyle(.plain)
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
        .task {
            if let transport {
                await store.bridgeIncoming(transport: transport)
            }
        }
        .task {
            if let mirroredObserver {
                await store.bridgeMirroredObserver(mirroredObserver)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
        .sheet(isPresented: $showExerciseSheet) {
            if let ex = sheetExercise {
                ExerciseDetailSheet(exercise: ex, asset: sheetAsset)
            }
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
        if let transport {
            await store.startWithWatch(transport: transport)
        } else {
            await store.start()
        }
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

    private func openExerciseSheet(for entry: SessionStore.FlatEntry) {
        let setsForExercise = store.flat
            .filter { $0.exerciseID == entry.exerciseID }
            .map { PlannedSet(setNum: $0.setNum, reps: $0.prescribedReps,
                              load: $0.prescribedLoad, restSec: $0.restSec) }
        sheetExercise = PlannedExercise(id: entry.exerciseID,
                                        exerciseID: entry.exerciseID,
                                        name: entry.exerciseName,
                                        sets: setsForExercise)
        if let assetRepo,
           let assets = try? assetRepo.allAssets() {
            sheetAsset = assets.first(where: { $0.id == entry.exerciseID })
        } else {
            sheetAsset = nil
        }
        showExerciseSheet = true
    }
}
