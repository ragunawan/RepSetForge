import SwiftUI
import SwiftData

/// dev spec §5, mockup frame 7. The mockup's calendar also marks "planned"
/// (dashed) future sessions — there's no scheduling feature yet (TODO.md),
/// so the calendar here only ever marks days with a completed session.
/// Filters (by routine/muscle) aren't built either.
struct HistoryView: View {
    @Query private var allSessions: [WorkoutSession]

    private enum Segment: String, CaseIterable, Hashable {
        case list = "List"
        case calendar = "Calendar"
    }

    @State private var segment: Segment = .list
    @State private var selectedMonth: Date = .now

    private var completedSessions: [WorkoutSession] {
        allSessions.filter { $0.status == .completed }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(12)

                switch segment {
                case .list: listView
                case .calendar: calendarView
                }
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("History")
        }
    }

    // MARK: - List

    private var listView: some View {
        Group {
            if completedSessions.isEmpty {
                Text("Your first session will appear here")
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(completedSessions) { session in
                    sessionRow(session)
                        .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let sets = session.sessionExercises.flatMap(\.setEntries)
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
        let volume = sets.compactMap(\.volumeKg).reduce(Decimal(0), +)
        let minutes = session.endedAt.map { max(0, Int($0.timeIntervalSince(session.startedAt) / 60)) }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                Text(rowSubtitle(session: session, minutes: minutes, volume: volume))
                    .font(RepSetForgeTheme.Typography.mono(12))
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func rowSubtitle(session: WorkoutSession, minutes: Int?, volume: Decimal) -> String {
        var parts = [Self.relativeDate(session.startedAt)]
        if let minutes { parts.append("\(minutes) min") }
        parts.append("\(Self.formatDecimal(volume)) kg")
        return parts.joined(separator: " · ")
    }

    // MARK: - Calendar

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(Self.monthTitle(selectedMonth))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                Spacer()
                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            .padding(.horizontal, 14)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Text("■ Completed")
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.top, 8)
    }

    private func dayCell(_ day: Date?) -> some View {
        Group {
            if let day {
                let hasSession = completedSessions.contains { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
                let isToday = Calendar.current.isDateInToday(day)
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(RepSetForgeTheme.Typography.mono(12, weight: hasSession ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(hasSession ? RepSetForgeTheme.Colors.signalDim : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(hasSession ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.textSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? RepSetForgeTheme.Colors.signal : Color.clear, lineWidth: 1)
                    )
            } else {
                Color.clear.frame(minHeight: 28)
            }
        }
    }

    /// Monday-first grid of the selected month, `nil` for the leading blanks
    /// before day 1 (dev spec's mockup calendar starts weeks on Monday).
    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) // 1 = Sunday...7 = Saturday
        let leadingEmptyDays = (firstWeekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }

    private static let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
