import SwiftUI
import SwiftData

/// Month calendar showing which days had completed quests, with a tap-to-
/// browse list of that day's quests below the grid.
struct QuestCalendarView: View {
    let quests: [Quest]

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?

    @Environment(\.calendar) private var calendar

    private var questsByDay: [Date: [Quest]] {
        QuestCalendarService.groupedByDay(quests, calendar: calendar)
    }

    private var monthGrid: [Date] {
        QuestCalendarService.monthGrid(containing: displayedMonth, calendar: calendar)
    }

    private var selectedDayQuests: [Quest] {
        guard let selectedDay else { return [] }
        return questsByDay[calendar.startOfDay(for: selectedDay)] ?? []
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let weekdaySymbols: [String] = {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingMedium) {
            monthHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(RepSetForgeFont.body(11))
                        .foregroundStyle(Color.questNavy.opacity(0.5))
                }

                ForEach(monthGrid, id: \.self) { day in
                    dayCell(for: day)
                }
            }

            if let selectedDay {
                PixelDivider()

                Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                    .font(RepSetForgeFont.heading(15))
                    .foregroundStyle(Color.questNavy)

                if selectedDayQuests.isEmpty {
                    Text("No quests completed this day.")
                        .font(RepSetForgeFont.body(13))
                        .foregroundStyle(Color.questNavy.opacity(0.6))
                } else {
                    ForEach(selectedDayQuests) { quest in
                        NavigationLink(value: quest) {
                            HStack {
                                Text(quest.name)
                                    .font(RepSetForgeFont.body(13))
                                    .foregroundStyle(Color.questSilver)
                                Spacer()
                                Text("+\(quest.totalXP) XP")
                                    .font(RepSetForgeFont.stat(12))
                                    .foregroundStyle(Color.questGold)
                            }
                            .padding(RepSetForgeMetrics.paddingSmall)
                            .pixelPanel()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(RepSetForgeMetrics.paddingMedium)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(Self.monthFormatter.string(from: displayedMonth))
                .font(RepSetForgeFont.heading())
                .foregroundStyle(Color.questNavy)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Color.questNavy)
    }

    private func dayCell(for day: Date) -> some View {
        let isInDisplayedMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let dayStart = calendar.startOfDay(for: day)
        let questCount = questsByDay[dayStart]?.count ?? 0
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(RepSetForgeFont.body(13))
                    .foregroundStyle(isInDisplayedMonth ? Color.questNavy : Color.questNavy.opacity(0.3))
                Circle()
                    .fill(questCount > 0 ? Color.questGold : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(isSelected ? Color.questGold.opacity(0.25) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.questGold : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(questCount > 0 ? "\(questCount) quest\(questCount == 1 ? "" : "s") completed" : "No quests completed")
    }

    private func changeMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = newMonth
        selectedDay = nil
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            QuestCalendarView(quests: [])
        }
        .background(Color.questParchment.ignoresSafeArea())
    }
}
