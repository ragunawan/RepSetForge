import SwiftUI
import UIKit

/// One row in the set table (dev spec §3 "Set row = single SwiftUI view, no
/// modals for ordinary logging"). Ghost values render as the field's
/// placeholder text — untouched until the user types or taps complete,
/// which is what makes "commit ghost values as real" (item 3) trivial: we
/// just fall back to the ghost when the bound value is still nil.
///
/// Dynamic Type: switches to the AX2+ stacked layout (dev spec §7a) at
/// `.accessibility2` and above. The narrower Tier 2/AX1 refinement (Rest
/// folded into the badge, Prev shortened) isn't implemented — this jumps
/// straight from the compact row to the fully stacked one.
struct SetRowView: View {
    var set: SetEntry
    var displayIndex: Int
    /// For the VoiceOver label (dev spec §7): "Bench press, set 2 of 4, ...".
    var exerciseName: String
    var totalSetsInExercise: Int
    var ghostWeight: Decimal?
    var ghostReps: Int?
    var ghostRPE: Double?
    var onComplete: () -> Void

    @State private var isEditingRPE = false
    @AppStorage(AppSettingsKeys.showRPE) private var showRPE = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isCompleted: Bool { set.completedAt != nil }

    var body: some View {
        Group {
            if dynamicTypeSize >= .accessibility2 {
                stackedRow
            } else {
                compactRow
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAction(named: Text("Complete set")) {
            if !isCompleted { complete() }
        }
    }

    // MARK: - Compact row (default through xxxLarge)

    private var compactRow: some View {
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
                    prBadge
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
        // Visual size stays compact (matches the mockup's density); the tap
        // target is expanded to the 44×44 accessibility minimum via a larger
        // frame + contentShape rather than growing the glyph itself (dev
        // spec §7: "rows are visually 36pt but hit areas extend into the gutter").
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
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
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
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
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .disabled(isCompleted)
    }

    private var prBadge: some View {
        Text("PR")
            .font(RepSetForgeTheme.Typography.mono(9, weight: .heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RepSetForgeTheme.Colors.prDim, in: Capsule())
            .foregroundStyle(RepSetForgeTheme.Colors.pr)
    }

    // MARK: - AX2+ stacked row (dev spec §7a)

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SET \(displayIndex) · \(set.type.displayName.uppercased())")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                Spacer()
                if set.isPR {
                    prBadge
                }
                if !isCompleted {
                    Text(stackedPrevText)
                        .font(RepSetForgeTheme.Typography.mono(12))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }

            if isCompleted {
                Text("✓ \(Self.formatOptionalDecimal(set.weightKg)) kg × \(set.reps.map(String.init) ?? "—")")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            } else {
                HStack(spacing: 8) {
                    stackedField(label: "WEIGHT", text: weightBinding, ghost: ghostWeight.map(Self.formatDecimal), keyboard: .decimalPad)
                    stackedField(label: "REPS", text: repsBinding, ghost: ghostReps.map(String.init), keyboard: .numberPad)
                }

                if showRPE {
                    Button {
                        isEditingRPE.toggle()
                    } label: {
                        Text("RPE \(set.rpe.map(Self.formatRPE) ?? ghostRPE.map(Self.formatRPE) ?? "—")")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if isEditingRPE {
                        RPEChipRow(selected: set.rpe) { value in
                            set.rpe = value
                            isEditingRPE = false
                        }
                    }
                }

                Button {
                    complete()
                } label: {
                    Text("✓ Complete")
                        .font(.system(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RepSetForgeTheme.Colors.signal, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
        .opacity(isCompleted ? 0.55 : 1)
    }

    private func stackedField(label: String, text: Binding<String>, ghost: String?, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            TextField("", text: text, prompt: Text(ghost ?? "—").foregroundColor(RepSetForgeTheme.Colors.textTertiary))
                .keyboardType(keyboard)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .padding(10)
                .frame(minHeight: 48)
                .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stackedPrevText: String {
        guard let ghostWeight, let ghostReps else { return "" }
        return "PREV \(Self.formatDecimal(ghostWeight))×\(ghostReps)"
    }

    // MARK: - Actions

    private func complete() {
        if set.weightKg == nil { set.weightKg = ghostWeight }
        if set.reps == nil { set.reps = ghostReps }
        if set.rpe == nil { set.rpe = ghostRPE }
        set.completedAt = .now
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onComplete()
    }

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        var parts = ["\(exerciseName), set \(displayIndex) of \(totalSetsInExercise)"]
        if let ghostWeight, let ghostReps {
            parts.append("previous \(Self.formatDecimal(ghostWeight)) kilograms for \(ghostReps) reps")
        }
        if let weight = set.weightKg {
            parts.append("weight \(Self.formatDecimal(weight))")
        }
        if let reps = set.reps {
            parts.append("reps \(reps)")
        }
        parts.append(isCompleted ? "completed" : "not completed")
        return parts.joined(separator: ". ")
    }

    // MARK: - Bindings

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

    // MARK: - Formatting

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
