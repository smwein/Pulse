import SwiftUI
import DesignSystem

struct SetLogCardView: View {
    @Binding var reps: Int
    @Binding var load: String
    @Binding var rpe: Int
    let prescribedReps: Int
    let prescribedLoad: String

    @State private var loadFreeform = false
    @State private var freeformText = ""

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("SET LOG")
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)

                stepperRow(title: "Reps",
                           value: $reps,
                           step: 1,
                           prescribed: "\(prescribedReps)")

                if loadFreeform {
                    HStack {
                        Text("Load")
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink1.color)
                        Spacer()
                        TextField("BW / 0:30 / 60kg", text: $freeformText)
                            .pulseFont(.body)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                load = freeformText
                                loadFreeform = false
                            }
                    }
                } else {
                    loadStepperRow(prescribed: prescribedLoad)
                }

                rpeRow
            }
        }
    }

    private func stepperRow(title: String, value: Binding<Int>, step: Int, prescribed: String) -> some View {
        HStack {
            Text(title).pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            Text("(prescribed \(prescribed))")
                .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            Stepper("\(value.wrappedValue)", value: value, in: 0...50, step: step)
                .pulseFont(.body)
        }
    }

    private func loadStepperRow(prescribed: String) -> some View {
        HStack {
            Text("Load").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            Text("(prescribed \(prescribed))")
                .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            HStack(spacing: 4) {
                Button("−5") { adjustLoadKg(by: -5) }
                Text(load).pulseFont(.body).foregroundStyle(PulseColors.ink0.color)
                    .frame(minWidth: 70)
                Button("+5") { adjustLoadKg(by: 5) }
            }
            .onLongPressGesture {
                freeformText = load
                loadFreeform = true
            }
        }
    }

    private var rpeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RPE").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
                Spacer()
                Text(rpe == 0 ? "—" : "\(rpe)")
                    .pulseFont(.body).foregroundStyle(PulseColors.ink0.color)
            }
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { n in
                    Circle()
                        .fill(n <= rpe ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .frame(width: 18, height: 18)
                        .onTapGesture { rpe = n }
                }
            }
        }
    }

    private func adjustLoadKg(by delta: Int) {
        let trimmed = load.trimmingCharacters(in: .whitespaces)
        if let n = Self.parseKg(trimmed) {
            let newN = max(0, n + delta)
            load = "\(newN)kg"
        }
    }

    static func parseKg(_ s: String) -> Int? {
        let digits = s.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}
