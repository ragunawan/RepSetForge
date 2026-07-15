import SwiftUI

/// Tap-to-edit rows for a `RoutineItem`'s `ProgressionRule` — the remaining
/// gap noted in `RoutineBuilderView`/`ProgressionLadderService` (dev spec §2,
/// §9 build order steps 2 & 6). Double progression (`.ladder`) only; don't
/// add fields for other `ProgressionRuleType` cases until they exist.
struct ProgressionRuleEditorSheet: View {
    let rule: ProgressionRule

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Rep range") {
                    Stepper(
                        "Low: \(rule.repRangeLow)",
                        value: Binding(get: { rule.repRangeLow }, set: { rule.repRangeLow = min($0, rule.repRangeHigh) }),
                        in: 1...30
                    )
                    Stepper(
                        "High: \(rule.repRangeHigh)",
                        value: Binding(get: { rule.repRangeHigh }, set: { rule.repRangeHigh = max($0, rule.repRangeLow) }),
                        in: 1...30
                    )
                }

                Section("Qualifying") {
                    Stepper(
                        "Max RPE: \(Self.formatRPE(rule.maxQualifyingRPE))",
                        value: Binding(get: { rule.maxQualifyingRPE }, set: { rule.maxQualifyingRPE = $0 }),
                        in: 5...10,
                        step: 0.5
                    )
                    Stepper(
                        "Sets required: \(rule.qualifyingSetsRequired)",
                        value: Binding(get: { rule.qualifyingSetsRequired }, set: { rule.qualifyingSetsRequired = $0 }),
                        in: 1...10
                    )
                }

                Section("Increment") {
                    Stepper(
                        "+\(Self.formatDecimal(rule.incrementKg)) kg per level",
                        value: incrementBinding,
                        in: 0.5...25,
                        step: 0.5
                    )
                }
            }
            .navigationTitle("Progression rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var incrementBinding: Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: rule.incrementKg).doubleValue },
            set: { rule.incrementKg = Decimal($0) }
        )
    }

    private static func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
