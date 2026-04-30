import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories

struct RateStepView: View {
    @Bindable var store: CompleteStore
    let coachName: String
    let firstFourExercises: [(id: String, name: String)]
    let onSubmit: () async -> Void

    @Environment(\.pulseTheme) private var theme

    private let availableTags = [
        "energized", "drained", "too_long", "too_short",
        "more_strength", "more_cardio", "boring", "fun"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                Text("How was it?")
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)

                ratingRow
                intensityRow
                moodRow

                if !firstFourExercises.isEmpty {
                    Text("Per move").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
                    VStack(spacing: PulseSpacing.sm) {
                        ForEach(firstFourExercises.prefix(4), id: \.id) { ex in
                            ExerciseThumbsRow(
                                exerciseID: ex.id,
                                exerciseName: ex.name,
                                rating: Binding(
                                    get: { store.feedbackDraft.exerciseRatings[ex.id] },
                                    set: { newValue in
                                        if let v = newValue {
                                            store.feedbackDraft.exerciseRatings[ex.id] = v
                                        } else {
                                            store.feedbackDraft.exerciseRatings.removeValue(forKey: ex.id)
                                        }
                                    }))
                        }
                    }
                }

                tagsRow
                noteRow

                PulseButton("Send to \(coachName) →", variant: .primary) {
                    Task { await onSubmit() }
                }
                .disabled(!store.feedbackDraft.canSubmit)
                .opacity(store.feedbackDraft.canSubmit ? 1 : 0.4)
            }
            .padding(PulseSpacing.lg)
        }
        .background(PulseColors.bg0.color.ignoresSafeArea())
    }

    private var ratingRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text("Rating").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            ForEach(1...5, id: \.self) { n in
                Button { store.feedbackDraft.rating = n } label: {
                    Image(systemName: n <= store.feedbackDraft.rating ? "star.fill" : "star")
                        .foregroundStyle(theme.accent.base.color)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var intensityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Intensity").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
                Spacer()
                Text(store.feedbackDraft.intensity == 0 ? "—" : "\(store.feedbackDraft.intensity)/5")
                    .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            }
            Slider(value: Binding(
                get: { Double(store.feedbackDraft.intensity) },
                set: { store.feedbackDraft.intensity = Int($0.rounded()) }
            ), in: 0...5, step: 1)
        }
    }

    private var moodRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text("Mood").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            ForEach(WorkoutFeedback.Mood.allCases, id: \.self) { m in
                Button {
                    store.feedbackDraft.mood = m
                } label: {
                    Text(m.rawValue.capitalized)
                        .pulseFont(.small)
                        .foregroundStyle(store.feedbackDraft.mood == m
                                         ? PulseColors.bg0.color : PulseColors.ink0.color)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, 4)
                        .background(store.feedbackDraft.mood == m
                                    ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            FlowLayout(spacing: 6) {
                ForEach(availableTags, id: \.self) { tag in
                    FeedbackTagPill(label: tag,
                                    isSelected: store.feedbackDraft.tags.contains(tag)) {
                        if store.feedbackDraft.tags.contains(tag) {
                            store.feedbackDraft.tags.remove(tag)
                        } else {
                            store.feedbackDraft.tags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Note (optional)").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            TextEditor(text: $store.feedbackDraft.note)
                .pulseFont(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(PulseColors.bg2.color)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth { x = 0; y += lineH + spacing; lineH = 0 }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += lineH + spacing; lineH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: sz.width, height: sz.height))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}

extension WorkoutFeedback.Mood: CaseIterable {
    public static let allCases: [WorkoutFeedback.Mood] = [.great, .good, .ok, .rough]
}
