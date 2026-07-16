import SwiftUI

/// Finish confirmation + summary (§1 finish flow, prototype summary panel):
/// duration/sets/reps/volume, PR spotlight, Health save line.
struct SummaryView: View {
    var vm: WorkoutViewModel
    var healthSaved: Bool
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s12) {
            Text("Workout done")
                .font(DT.Type.title)
                .tracking(DT.Type.titleTracking)

            HStack {
                stat(durationText, "DURATION")
                Spacer()
                stat("\(vm.doneSets)", "SETS")
                Spacer()
                stat("\(totalReps)", "REPS")
                Spacer()
                stat(volumeText, "VOL KG")
            }

            if !prList.isEmpty {
                VStack(alignment: .leading, spacing: DT.Spacing.s8 - 2) {
                    Text("\(prList.count) PERSONAL RECORD\(prList.count > 1 ? "S" : "")")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.pr)
                    ForEach(Array(prList.enumerated()), id: \.offset) { _, pr in
                        HStack {
                            Text(pr.0)
                            Spacer()
                            Text(pr.1).foregroundStyle(DT.Colors.pr).monospacedDigit()
                        }
                        .font(DT.Type.secondary.weight(.semibold))
                    }
                }
                .padding(DT.Spacing.s12)
                .background(DT.Colors.prDim)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.pr))
            }

            if healthSaved {
                Text("✓ Saved to Apple Health · visible in Fitness")
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
                    .padding(.top, DT.Spacing.s8)
                    .overlay(alignment: .top) { DT.Colors.hairline.frame(height: 1) }
            }

            Button(action: onDone) {
                Text("Done")
                    .font(DT.Type.body.weight(.bold))
                    .foregroundStyle(DT.Colors.onSignal)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(DT.Colors.signal)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card + 2))
            }
        }
        .padding(DT.Spacing.s16 + 2)
        .background(DT.Colors.surface)
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
        .presentationDetents([.medium])
        .presentationCornerRadius(DT.Radius.phoneSheet)
    }

    private var durationText: String {
        guard let s = vm.session else { return "—" }
        let secs = Int((s.endedAt ?? .now).timeIntervalSince(s.startedAt))
        return String(format: "%02d:%02d", secs / 3600, (secs % 3600) / 60)
    }

    private var totalReps: Int {
        vm.orderedExercises.reduce(0) {
            $0 + ($1.sets ?? []).filter { $0.completedAt != nil }.reduce(0) { $0 + ($1.reps ?? 0) }
        }
    }

    private var volumeText: String {
        let v = NSDecimalNumber(decimal: vm.volumeKg).doubleValue / 1000
        return "\(v.formatted(.number.precision(.fractionLength(1))))k"
    }

    private var prList: [(String, String)] {
        vm.orderedExercises.flatMap { ex in
            (ex.sets ?? []).filter(\.isPR).compactMap { s -> (String, String)? in
                guard let w = s.weightKg, let r = s.reps else { return nil }
                let wt = NSDecimalNumber(decimal: w).doubleValue.formatted(.number.precision(.fractionLength(0...1)))
                return (ex.exercise?.name ?? "Exercise", "\(wt) × \(r)")
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(DT.Type.numericLarge)
            Text(label).font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
        }
    }
}
