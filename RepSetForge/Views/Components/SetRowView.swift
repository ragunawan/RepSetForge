import SwiftUI

/// One row in the set table (dev spec §3 "Set row = single SwiftUI view, no
/// modals for ordinary logging"). Ghost values render as the field's
/// placeholder text — untouched until the user types or taps complete,
/// which is what makes "commit ghost values as real" (item 3) trivial: we
/// just fall back to the ghost when the bound value is still nil.
struct SetRowView: View {
    var set: SetEntry
    var displayIndex: Int
    var ghostWeight: Decimal?
    var ghostReps: Int?
    var ghostRPE: Double?
    var onComplete: () -> Void

    @State private var isEditingRPE = false
    @AppStorage(AppSettingsKeys.showRPE) private var showRPE = true

    private var isCompleted: Bool { set.completedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                badge

                if isCompleted {
                    completedValues
                } else {
                    weightField
                    repsField
                    if showRPE {
                        rpeField
                    }
                }

                Spacer(minLength: 0)

                if set.isPR {
                    Text("PR")
                        .font(RepSetForgeTheme.Typography.mono(9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RepSetForgeTheme.Colors.prDim, in: Capsule())
                        .foregroundStyle(RepSetForgeTheme.Colors.pr)
                }

                completeButton
            }

            if isEditingRPE {
                RPEChipRow(selected: set.rpe) { value in
                    set.rpe = value
                    isEditingRPE = false
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isCompleted ? 0.55 : 1)
    }

    private var badge: some View {
        Menu {
            ForEach(SetType.allCases) { type in
                Button(type.displayName) { set.type = type }
            }
        } label: {
            Text(badgeText)
                .font(RepSetForgeTheme.Typography.mono(11, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                .frame(width: 26)
        }
        .disabled(isCompleted)
    }

    private var badgeText: String {
        guard let letter = set.type.badgeLetter else { return String(displayIndex) }
        return letter + Self.subscriptDigits(displayIndex)
    }

    private var completedValues: some View {
        HStack(spacing: 8) {
            Text(Self.formatOptionalDecimal(set.weightKg))
                .frame(width: 58, alignment: .leading)
            Text(set.reps.map(String.init) ?? "—")
                .frame(width: 40, alignment: .leading)
            if showRPE {
                Text(set.rpe.map(Self.formatRPE) ?? "—")
                    .frame(width: 38, alignment: .leading)
            }
        }
        .font(RepSetForgeTheme.Typography.mono(13))
        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
    }

    private var weightField: some View {
        TextField(
            "",
            text: weightBinding,
            prompt: Text(ghostWeight.map(Self.formatDecimal) ?? "—")
                .foregroundColor(RepSetForgeTheme.Colors.textTertiary)
        )
        .keyboardType(.decimalPad)
        .font(RepSetForgeTheme.Typography.mono(13))
        .frame(width: 58)
        .padding(6)
        .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
    }

    private var repsField: some View {
        TextField(
            "",
            text: repsBinding,
            prompt: Text(ghostReps.map(String.init) ?? "—")
                .foregroundColor(RepSetForgeTheme.Colors.textTertiary)
        )
        .keyboardType(.numberPad)
        .font(RepSetForgeTheme.Typography.mono(13))
        .frame(width: 40)
        .padding(6)
        .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
    }

    private var rpeField: some View {
        Button {
            isEditingRPE.toggle()
        } label: {
            Text(set.rpe.map(Self.formatRPE) ?? ghostRPE.map(Self.formatRPE) ?? "—")
                .font(RepSetForgeTheme.Typography.mono(13))
                .foregroundStyle(set.rpe == nil ? RepSetForgeTheme.Colors.textTertiary : RepSetForgeTheme.Colors.textPrimary)
                .frame(width: 38)
                .padding(6)
                .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
        }
        .buttonStyle(.plain)
    }

    private var completeButton: some View {
        Button {
            complete()
        } label: {
            Image(systemName: isCompleted ? "checkmark" : "circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isCompleted ? Color.black : RepSetForgeTheme.Colors.textTertiary)
                .frame(width: 26, height: 26)
                .background(isCompleted ? RepSetForgeTheme.Colors.signal : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RepSetForgeTheme.Colors.hairline, lineWidth: isCompleted ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }

    private func complete() {
        if set.weightKg == nil { set.weightKg = ghostWeight }
        if set.reps == nil { set.reps = ghostReps }
        if set.rpe == nil { set.rpe = ghostRPE }
        set.completedAt = .now
        onComplete()
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { set.weightKg.map(Self.formatDecimal) ?? "" },
            set: { set.weightKg = Decimal(string: $0.replacingOccurrences(of: ",", with: ".")) }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps.map(String.init) ?? "" },
            set: { set.reps = Int($0) }
        )
    }

    private static func formatOptionalDecimal(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return formatDecimal(value)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private static func subscriptDigits(_ n: Int) -> String {
        let subscripts: [Character] = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
        return String(n).compactMap { $0.wholeNumberValue.map { subscripts[$0] } }.map(String.init).joined()
    }
}
