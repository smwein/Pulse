import SwiftUI
import CoreModels
import DesignSystem

struct ExerciseThumbsRow: View {
    let exerciseID: String
    let exerciseName: String
    @Binding var rating: WorkoutFeedback.ExerciseRating?

    var body: some View {
        HStack {
            Text(exerciseName)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            Spacer()
            HStack(spacing: PulseSpacing.sm) {
                thumbButton(direction: .up)
                thumbButton(direction: .down)
            }
        }
    }

    @ViewBuilder
    private func thumbButton(direction: WorkoutFeedback.ExerciseRating) -> some View {
        let isSelected = rating == direction
        Button {
            rating = isSelected ? nil : direction
        } label: {
            Image(systemName: direction == .up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .foregroundStyle(isSelected ? PulseColors.ink0.color : PulseColors.ink2.color)
                .padding(8)
        }
        .buttonStyle(.plain)
    }
}
