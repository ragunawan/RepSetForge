import SwiftUI
import SwiftData

/// Minimal bodyweight/body-fat entry form feeding the Home screen's Body
/// module (dev spec §5). Weight-unit settings (kg/lb) don't exist yet
/// (TODO.md build-order step 8) — this is kg-only for now.
struct LogBodyMetricSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var date = Date.now

    private var weight: Decimal? { Decimal(string: weightText) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Weight (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                TextField("Body fat % (optional)", text: $bodyFatText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Log weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(weight == nil)
                }
            }
        }
    }

    private func save() {
        guard let weight else { return }
        let metric = BodyMetric(date: date, bodyweightKg: weight, bodyFatPct: Decimal(string: bodyFatText))
        modelContext.insert(metric)
        dismiss()
    }
}
