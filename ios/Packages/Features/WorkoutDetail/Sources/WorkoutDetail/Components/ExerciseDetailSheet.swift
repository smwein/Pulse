import SwiftUI
import CoreModels
import Persistence
import DesignSystem

#if os(iOS)
import AVKit
#endif

public struct ExerciseDetailSheet: View {
    let exercise: PlannedExercise
    let asset: ExerciseAssetEntity?

    @Environment(\.dismiss) private var dismiss

    public init(exercise: PlannedExercise, asset: ExerciseAssetEntity?) {
        self.exercise = exercise
        self.asset = asset
    }

#if os(iOS)
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
#endif

    public var body: some View {
        NavigationStack {
            ZStack {
                PulseColors.bg0.color.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                        Text(exercise.name)
                            .pulseFont(.h1)
                            .foregroundStyle(PulseColors.ink0.color)
                        mediaSection
                        instructionsSection
                    }
                    .padding(PulseSpacing.lg)
                }
            }
            .preferredColorScheme(.dark)
#if os(iOS)
            .onAppear { setupPlayer() }
            .onDisappear { player?.pause() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PulseColors.ink0.color)
                }
            }
#endif
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
#if os(iOS)
        if let player {
            VideoPlayer(player: player)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
        } else if let posterURL = asset?.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: ExercisePlaceholder(label: exercise.name)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
        }
#else
        if let posterURL = asset?.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: ExercisePlaceholder(label: exercise.name)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
        }
#endif
    }

    @ViewBuilder
    private var instructionsSection: some View {
        if let json = asset?.instructionsJSON,
           let lines = try? JSONDecoder.pulse.decode([String].self, from: json) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                Text("How to do it")
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    HStack(alignment: .top, spacing: PulseSpacing.sm) {
                        Text("\(idx + 1).")
                            .pulseFont(.small)
                            .foregroundStyle(PulseColors.ink2.color)
                        Text(line)
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink1.color)
                    }
                }
            }
        }
    }

#if os(iOS)
    private func setupPlayer() {
        guard let url = asset?.videoURL else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: item)
        queue.play()
        player = queue
    }
#endif
}
