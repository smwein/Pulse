import SwiftUI
import CoreModels
import Persistence
import DesignSystem

struct ExerciseRowView: View {
    let exercise: PlannedExercise
    let asset: ExerciseAssetEntity?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PulseSpacing.md) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .pulseFont(.body)
                        .foregroundStyle(PulseColors.ink0.color)
                    Text(prescription)
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                }
                Spacer()
                if asset != nil {
                    IconButton(systemName: "info.circle", action: onTap)
                }
            }
            .padding(.vertical, PulseSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = asset?.posterURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ExercisePlaceholder(label: exercise.name)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
        } else {
            ExercisePlaceholder(label: exercise.name)
                .frame(width: 56, height: 56)
        }
    }

    private var prescription: String {
        guard !exercise.sets.isEmpty else { return "" }
        let setCount = exercise.sets.count
        let repsList = exercise.sets.map { "\($0.reps)" }.joined(separator: "/")
        let load = exercise.sets.first?.load ?? ""
        return "\(setCount) \u{00D7} \(repsList)\(load.isEmpty ? "" : " @ \(load)")"
    }
}
