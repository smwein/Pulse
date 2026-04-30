import SwiftUI
import WatchBridge

public struct ActiveSetView: View {
    public let exerciseName: String
    public let setNum: Int
    public let totalSets: Int
    public let prescribedReps: Int
    public let prescribedLoad: String
    public let onConfirm: () -> Void

    public init(exerciseName: String, setNum: Int, totalSets: Int,
                prescribedReps: Int, prescribedLoad: String,
                onConfirm: @escaping () -> Void) {
        self.exerciseName = exerciseName; self.setNum = setNum
        self.totalSets = totalSets; self.prescribedReps = prescribedReps
        self.prescribedLoad = prescribedLoad; self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(exerciseName).font(.headline).lineLimit(1)
            Text("Set \(setNum) / \(totalSets)").font(.caption).foregroundStyle(.secondary)
            Text("\(prescribedReps) × \(prescribedLoad)").font(.title3).bold()
            Spacer(minLength: 4)
            Button("Set done", action: onConfirm).buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
    }
}
