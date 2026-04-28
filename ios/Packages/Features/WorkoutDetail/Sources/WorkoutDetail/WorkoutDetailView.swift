import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Repositories

public struct WorkoutDetailView: View {
    @State private var store: WorkoutDetailStore
    @State private var selectedExercise: PlannedExercise?

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                assetRepo: ExerciseAssetRepository) {
        _store = State(initialValue: WorkoutDetailStore(
            workoutID: workoutID,
            modelContainer: modelContainer,
            assetRepo: assetRepo
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                hero
                if let why = store.why {
                    PulseCard {
                        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                            Text("Why this workout")
                                .pulseFont(.small)
                                .foregroundStyle(PulseColors.ink2.color)
                            Text(why)
                                .pulseFont(.body)
                                .foregroundStyle(PulseColors.ink0.color)
                        }
                    }
                }
                ForEach(store.blocks) { block in
                    BlockSectionView(block: block,
                                     assetFor: { store.asset(for: $0) }) { ex in
                        selectedExercise = ex
                    }
                }
                startCTA
            }
            .padding(PulseSpacing.lg)
        }
        .task { await store.load() }
        .sheet(item: $selectedExercise) { ex in
            ExerciseDetailSheet(exercise: ex, asset: store.asset(for: ex.exerciseID))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(store.workoutTitle)
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text(store.workoutSubtitle)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            HStack(spacing: PulseSpacing.sm) {
                PulsePill("\(store.durationMin) min", variant: .default)
                PulsePill(store.workoutType, variant: .accent)
            }
        }
    }

    private var startCTA: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            PulseButton("Start workout", variant: .primary, action: {})
                .disabled(true)
                .opacity(0.5)
            Text("Coming in the next update")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
    }
}
