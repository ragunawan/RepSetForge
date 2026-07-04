import SwiftUI
import SwiftData
import Charts

/// Cross-quest history/trend for a single exercise name: all-time max
/// weight, all-time best volume, and a weight-over-time chart. Reachable
/// both from `ExerciseLoggingView`'s "History" toolbar action and from a
/// suggestion chip's info button in `AddExerciseSheet`.
struct ExerciseMetricsView: View {
    let exerciseName: String

    @Query(sort: \Quest.completedDate, order: .reverse) private var allQuests: [Quest]

    private var metrics: ExerciseMetrics? {
        ExerciseMetricsService.metrics(for: exerciseName, in: allQuests)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
                if let metrics {
                    HStack(spacing: RepSetForgeMetrics.paddingMedium) {
                        statPanel(title: "Max Weight", value: "\(Int(metrics.allTimeMaxWeight.rounded())) lb")
                        statPanel(title: "Best Volume", value: "\(Int(metrics.allTimeBestVolume.rounded())) lb")
                    }

                    Text("Weight Over Time")
                        .font(RepSetForgeFont.heading(15))
                        .foregroundStyle(Color.questNavy)

                    Chart(metrics.history) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Max Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color.questGold)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Max Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color.questGold)
                    }
                    .frame(height: 180)
                    .padding(RepSetForgeMetrics.paddingSmall)
                    .pixelPanel()

                    Text("\(metrics.history.count) session\(metrics.history.count == 1 ? "" : "s") logged")
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(Color.questNavy.opacity(0.6))
                } else {
                    Text("No completed sessions logged for this exercise yet.")
                        .font(RepSetForgeFont.body())
                        .foregroundStyle(Color.questNavy.opacity(0.6))
                }
            }
            .padding(RepSetForgeMetrics.paddingLarge)
        }
        .background(Color.questParchment.ignoresSafeArea())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statPanel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RepSetForgeFont.body(12))
                .foregroundStyle(Color.questSilver.opacity(0.7))
            Text(value)
                .font(RepSetForgeFont.stat(20))
                .foregroundStyle(Color.questGold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RepSetForgeMetrics.paddingSmall)
        .pixelPanel()
    }
}

#Preview {
    NavigationStack {
        ExerciseMetricsView(exerciseName: "Bench Press")
    }
    .modelContainer(PersistenceController.previewContainer)
}
