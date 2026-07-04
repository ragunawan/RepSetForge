import SwiftUI
import Charts

private enum ChartPeriodOption: String, CaseIterable {
    case week = "Week"
    case month = "Month"

    var period: ChartPeriod {
        switch self {
        case .week: return .week
        case .month: return .month
        }
    }

    var periodsCount: Int {
        switch self {
        case .week: return 8
        case .month: return 6
        }
    }

    var dateFormat: String {
        switch self {
        case .week: return "MMM d"
        case .month: return "MMM yy"
        }
    }
}

/// Weekly/monthly XP, volume, and consistency charts for the History tab —
/// purely a rendering of `TrainingChartsService`'s aggregated stats.
struct TrainingChartsView: View {
    let quests: [Quest]

    @State private var periodOption: ChartPeriodOption = .week

    private var stats: [TrainingPeriodStat] {
        TrainingChartsService.periodStats(from: quests, period: periodOption.period, periodsCount: periodOption.periodsCount)
    }

    private func label(for stat: TrainingPeriodStat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = periodOption.dateFormat
        return formatter.string(from: stat.periodStart)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
            Picker("Period", selection: $periodOption) {
                ForEach(ChartPeriodOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            chartSection(title: "XP Earned") {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Period", label(for: stat)),
                        y: .value("XP", stat.totalXP)
                    )
                    .foregroundStyle(Color.questGold)
                }
            }

            chartSection(title: "Training Volume (lb)") {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Period", label(for: stat)),
                        y: .value("Volume", stat.totalVolume)
                    )
                    .foregroundStyle(Color.questNavy)
                }
            }

            chartSection(title: "Days Trained") {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Period", label(for: stat)),
                        y: .value("Days", stat.daysTrained)
                    )
                    .foregroundStyle(Color.questSilver)
                }
            }
        }
        .padding(RepSetForgeMetrics.paddingMedium)
    }

    @ViewBuilder
    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
            Text(title)
                .font(RepSetForgeFont.heading(15))
                .foregroundStyle(Color.questNavy)
            content()
                .frame(height: 140)
        }
        .padding(RepSetForgeMetrics.paddingSmall)
        .pixelPanel()
    }
}

#Preview {
    ScrollView {
        TrainingChartsView(quests: [])
    }
    .background(Color.questParchment.ignoresSafeArea())
}
