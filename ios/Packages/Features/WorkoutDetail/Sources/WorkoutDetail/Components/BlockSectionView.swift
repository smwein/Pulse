import SwiftUI
import CoreModels
import Persistence
import DesignSystem

struct BlockSectionView: View {
    let block: WorkoutBlock
    let assetFor: (String) -> ExerciseAssetEntity?
    let onSelectExercise: (PlannedExercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(block.label.uppercased())
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.xs) {
                ForEach(block.exercises) { ex in
                    ExerciseRowView(exercise: ex,
                                    asset: assetFor(ex.exerciseID)) {
                        onSelectExercise(ex)
                    }
                }
            }
        }
    }
}
