import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @State private var store = FocusWorkoutStore(exercises: [], activityController: .shared)
  @State private var showsActiveWorkout = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      TabView {
        HomeView(store: store, showsActiveWorkout: $showsActiveWorkout)
          .tabItem { Label("Home", systemImage: "house") }
        HistoryView()
          .tabItem { Label("History", systemImage: "calendar") }
        PlaceholderTab(title: "PROGRESS", message: "Charts unlock as your training history grows")
          .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        PlaceholderTab(title: "LIBRARY", message: "Build a routine to get session recommendations")
          .tabItem { Label("Library", systemImage: "list.bullet.rectangle") }
      }

      Button {
        showsActiveWorkout = true
      } label: {
        Image(systemName: store.exercises.isEmpty ? "plus" : "figure.strengthtraining.traditional")
          .font(.system(size: DesignTokens.Typography.title.size, weight: .heavy, design: .monospaced))
          .foregroundStyle(DesignTokens.ColorToken.onSignal)
          .frame(width: DesignTokens.Spacing.step6 * 2, height: DesignTokens.Spacing.step6 * 2)
          .background(DesignTokens.ColorToken.signal, in: Circle())
          .shadow(radius: DesignTokens.Spacing.step2)
      }
      .padding(.trailing, DesignTokens.Spacing.screenGutter + DesignTokens.Spacing.step2)
      .padding(.bottom, DesignTokens.Spacing.step6 * 2)
      .accessibilityLabel(store.exercises.isEmpty ? "Create exercise" : "Resume workout")
    }
    .background(DesignTokens.ColorToken.surface.ignoresSafeArea())
    .fullScreenCover(isPresented: $showsActiveWorkout) {
      FocusWorkoutView(store: store)
    }
    .task {
      store.bindModelContext(modelContext)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        store.reassertLiveActivity()
      }
    }
    .environment(\.font, .system(.body, design: .monospaced))
  }
}

private struct HomeView: View {
  @Bindable var store: FocusWorkoutStore
  @Binding var showsActiveWorkout: Bool
  @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
  @Query(sort: \Routine.lastPerformedAt) private var routines: [Routine]
  @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
  @State private var bodyRange: BodyPeriodRange = .week
  @State private var bodyOffset = 0
  @State private var bodyDragStartX: CGFloat?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardGap) {
          if store.plannedSetCount > 0 {
            resumeBanner
          }
          weekModule
          recommendationModule
          bodyModule
        }
        .padding(.horizontal, DesignTokens.Spacing.screenGutter)
        .padding(.vertical, DesignTokens.Spacing.step4)
      }
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("HOME")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
          } label: {
            Image(systemName: "gearshape")
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          .accessibilityLabel("Settings")
        }
      }
    }
  }

  private var resumeBanner: some View {
    Button {
      showsActiveWorkout = true
    } label: {
      HStack(spacing: DesignTokens.Spacing.step3) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
          Text(store.sessionName.uppercased())
            .forgeTextStyle(DesignTokens.Typography.eyebrow)
            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
          Text("\(store.completedSetCount)/\(store.plannedSetCount) SETS")
            .forgeTextStyle(DesignTokens.Typography.numericRow)
            .forgeNumeric()
            .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        }
        Spacer()
        Text("RESUME")
          .forgeTextStyle(DesignTokens.Typography.heading)
          .foregroundStyle(DesignTokens.ColorToken.signal)
      }
      .padding(DesignTokens.Spacing.cardPadding)
      .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    }
    .buttonStyle(.plain)
  }

  private var weekModule: some View {
    let completed = sessions.filter { $0.status == .completed && Calendar.current.isDate($0.startedAt, equalTo: .now, toGranularity: .weekOfYear) }
    let volume = completed.flatMap { $0.exercises ?? [] }.flatMap { $0.sets ?? [] }.reduce(Decimal(0)) { $0 + ($1.volumeKg ?? 0) }
    return HomeModule(title: "WEEK") {
      if completed.isEmpty {
        PlaceholderModuleText("Your weekly summary appears after your first workout")
      } else {
        HStack {
          HomeMetricBlock(label: "SESSIONS", value: "\(completed.count)")
          Spacer()
          HomeMetricBlock(label: "VOLUME", value: "\(homeFormat(volume)) KG")
          Spacer()
          HomeMetricBlock(label: "PRS", value: "\(completed.flatMap { $0.exercises ?? [] }.flatMap { $0.sets ?? [] }.filter(\.isPR).count)")
        }
      }
    }
  }

  private var recommendationModule: some View {
    HomeModule(title: "NEXT") {
      if let routine = routines.filter({ $0.archivedAt == nil }).first {
        HStack {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
            Text(routine.name)
              .forgeTextStyle(DesignTokens.Typography.heading)
              .foregroundStyle(DesignTokens.ColorToken.textPrimary)
            Text("Least recently performed")
              .forgeTextStyle(DesignTokens.Typography.secondary)
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          Spacer()
          Text("START")
            .forgeTextStyle(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.ColorToken.signal)
        }
      } else {
        PlaceholderModuleText("Build a routine to get session recommendations")
      }
    }
  }

  private var bodyModule: some View {
    HomeModule(title: "BODY") {
      let series = BodyPeriodSeries.make(metrics: bodyMetrics, range: bodyRange, offset: bodyOffset)
      if series.weightPoints.count < 2 {
        PlaceholderModuleText(bodyMetrics.isEmpty ? "Log today's weight" : "Log another bodyweight to start tracking")
      } else {
        BodyTrendModule(
          range: $bodyRange,
          offset: $bodyOffset,
          dragStartX: $bodyDragStartX,
          series: series
        )
      }
    }
  }
}

private struct HomeModule<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step3) {
      Text(title)
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      content
    }
    .padding(DesignTokens.Spacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
  }
}

private struct HomeMetricBlock: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
      Text(label)
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      Text(value)
        .forgeTextStyle(DesignTokens.Typography.numericRow)
        .forgeNumeric()
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
    }
  }
}

private func homeFormat(_ value: Decimal) -> String {
  let number = NSDecimalNumber(decimal: value).doubleValue
  return number.rounded() == number ? String(format: "%.0f", number) : String(format: "%.1f", number)
}

private struct PlaceholderModuleText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .forgeTextStyle(DesignTokens.Typography.body)
      .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.input)
          .stroke(DesignTokens.ColorToken.hairline, style: StrokeStyle(lineWidth: 1, dash: [DesignTokens.Spacing.step2, DesignTokens.Spacing.step1]))
      }
      .padding(.vertical, DesignTokens.Spacing.step2)
  }
}

private enum BodyPeriodRange: String, CaseIterable, Identifiable {
  case week = "W"
  case month = "M"
  case year = "Y"

  var id: String { rawValue }

  var component: Calendar.Component {
    switch self {
    case .week: return .day
    case .month: return .day
    case .year: return .month
    }
  }

  var value: Int {
    switch self {
    case .week: return 7
    case .month: return 1
    case .year: return 1
    }
  }

  var points: Int {
    switch self {
    case .week: return 7
    case .month: return 10
    case .year: return 12
    }
  }
}

private struct BodyPeriodSeries {
  struct Point: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Decimal?
    let bodyFatPct: Decimal?
  }

  let label: String
  let previousLabel: String
  let nextLabel: String?
  let weightPoints: [Point]
  let fatPoints: [Point]
  let currentWeightKg: Decimal
  let weightDeltaKg: Decimal
  let currentBodyFatPct: Decimal?
  let bodyFatDeltaPct: Decimal?

  static func make(metrics: [BodyMetric], range: BodyPeriodRange, offset: Int, calendar: Calendar = .current, now: Date = .now) -> BodyPeriodSeries {
    let bounds = periodBounds(range: range, offset: offset, calendar: calendar, now: now)
    let anchors = pointDates(range: range, start: bounds.start, end: bounds.end, calendar: calendar)
    let sorted = metrics.sorted { $0.date < $1.date }
    let points = anchors.map { anchor in
      Point(
        date: anchor,
        weightKg: aggregateWeight(metrics: sorted, range: range, anchor: anchor, calendar: calendar),
        bodyFatPct: interpolatedBodyFat(metrics: sorted, at: anchor, calendar: calendar)
      )
    }
    let weights = points.compactMap(\.weightKg)
    let fats = points.compactMap(\.bodyFatPct)
    return BodyPeriodSeries(
      label: label(for: bounds, range: range),
      previousLabel: label(for: periodBounds(range: range, offset: offset + 1, calendar: calendar, now: now), range: range),
      nextLabel: offset == 0 ? nil : label(for: periodBounds(range: range, offset: offset - 1, calendar: calendar, now: now), range: range),
      weightPoints: points.filter { $0.weightKg != nil },
      fatPoints: points.filter { $0.bodyFatPct != nil },
      currentWeightKg: weights.last ?? 0,
      weightDeltaKg: (weights.last ?? 0) - (weights.first ?? 0),
      currentBodyFatPct: fats.last,
      bodyFatDeltaPct: fats.last.flatMap { last in fats.first.map { last - $0 } }
    )
  }

  private static func periodBounds(range: BodyPeriodRange, offset: Int, calendar: Calendar, now: Date) -> (start: Date, end: Date) {
    let endOfToday = calendar.startOfDay(for: now)
    switch range {
    case .week:
      let end = calendar.date(byAdding: .day, value: -(offset * 7), to: endOfToday) ?? endOfToday
      let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
      return (start, end)
    case .month:
      let shifted = calendar.date(byAdding: .month, value: -offset, to: endOfToday) ?? endOfToday
      let interval = calendar.dateInterval(of: .month, for: shifted)
      let start = interval?.start ?? shifted
      let end = min(endOfToday, calendar.date(byAdding: .day, value: -1, to: interval?.end ?? shifted) ?? shifted)
      return (start, end)
    case .year:
      let shifted = calendar.date(byAdding: .year, value: -offset, to: endOfToday) ?? endOfToday
      let interval = calendar.dateInterval(of: .year, for: shifted)
      let start = interval?.start ?? shifted
      let end = min(endOfToday, calendar.date(byAdding: .day, value: -1, to: interval?.end ?? shifted) ?? shifted)
      return (start, end)
    }
  }

  private static func pointDates(range: BodyPeriodRange, start: Date, end: Date, calendar: Calendar) -> [Date] {
    guard range == .year else {
      let days = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
      let step = max(1, Int((Double(days) / Double(max(range.points - 1, 1))).rounded()))
      return (0..<range.points).compactMap { calendar.date(byAdding: .day, value: min(days, $0 * step), to: start) }
    }
    return (0..<range.points).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
  }

  private static func aggregateWeight(metrics: [BodyMetric], range: BodyPeriodRange, anchor: Date, calendar: Calendar) -> Decimal? {
    switch range {
    case .week:
      return metrics.last { calendar.isDate($0.date, inSameDayAs: anchor) }?.bodyweightKg
    case .month:
      let sameWeek = metrics.filter { calendar.isDate($0.date, equalTo: anchor, toGranularity: .weekOfYear) }.map(\.bodyweightKg)
      return mean(sameWeek)
    case .year:
      let sameMonth = metrics.filter { calendar.isDate($0.date, equalTo: anchor, toGranularity: .month) }.map(\.bodyweightKg)
      return mean(sameMonth)
    }
  }

  private static func interpolatedBodyFat(metrics: [BodyMetric], at date: Date, calendar: Calendar) -> Decimal? {
    let fatMetrics = metrics.compactMap { metric -> (Date, Decimal)? in
      guard let bodyFatPct = metric.bodyFatPct else { return nil }
      return (metric.date, bodyFatPct)
    }
    guard !fatMetrics.isEmpty else { return nil }
    if let exact = fatMetrics.last(where: { calendar.isDate($0.0, inSameDayAs: date) }) {
      return exact.1
    }
    let previous = fatMetrics.last { $0.0 < date }
    let next = fatMetrics.first { $0.0 > date }
    guard let previous, let next else { return nil }
    let gap = next.0.timeIntervalSince(previous.0)
    guard gap > 0, gap <= 14 * 24 * 60 * 60 else { return nil }
    let fraction = Decimal(date.timeIntervalSince(previous.0) / gap)
    return previous.1 + (next.1 - previous.1) * fraction
  }

  private static func mean(_ values: [Decimal]) -> Decimal? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Decimal(values.count)
  }

  private static func label(for bounds: (start: Date, end: Date), range: BodyPeriodRange) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = range == .year ? "yyyy" : "MMM d"
    if range == .year {
      return formatter.string(from: bounds.start).uppercased()
    }
    return "\(formatter.string(from: bounds.start).uppercased())-\(formatter.string(from: bounds.end).uppercased())"
  }
}

private struct BodyTrendModule: View {
  @Binding var range: BodyPeriodRange
  @Binding var offset: Int
  @Binding var dragStartX: CGFloat?
  let series: BodyPeriodSeries

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      Picker("Body range", selection: $range) {
        ForEach(BodyPeriodRange.allCases) { range in
          Text(range.rawValue).tag(range)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: range) { _, _ in offset = 0 }

      HStack {
        Button {
          offset += 1
        } label: {
          Text("< \(series.previousLabel)")
        }

        Spacer()

        Text(series.label)
          .forgeTextStyle(DesignTokens.Typography.secondary)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)

        Spacer()

        Button {
          offset = max(0, offset - 1)
        } label: {
          Text(series.nextLabel.map { "\($0) >" } ?? "NOW >")
        }
        .disabled(offset == 0)
      }
      .forgeTextStyle(DesignTokens.Typography.eyebrow)
      .foregroundStyle(DesignTokens.ColorToken.textSecondary)

      BodyTrendChart(series: series)
        .frame(height: DesignTokens.Spacing.step6 * 3)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: DesignTokens.Spacing.step4)
            .onChanged { value in
              if dragStartX == nil {
                dragStartX = value.startLocation.x
              }
            }
            .onEnded { value in
              let delta = value.location.x - (dragStartX ?? value.startLocation.x)
              dragStartX = nil
              if delta > DesignTokens.Spacing.step6 {
                offset += 1
              } else if delta < -DesignTokens.Spacing.step6 {
                offset = max(0, offset - 1)
              }
            }
        )

      HStack(spacing: DesignTokens.Spacing.step3) {
        Text("WEIGHT \(homeFormat(series.currentWeightKg)) KG (\(signed(series.weightDeltaKg)))")
          .foregroundStyle(DesignTokens.ColorToken.signal)
        if let bodyFat = series.currentBodyFatPct, let delta = series.bodyFatDeltaPct {
          Text("BODY FAT \(homeFormat(bodyFat))% (\(signed(delta)))")
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        } else {
          Text("NO BODY-FAT DATA")
            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
        }
      }
      .forgeTextStyle(DesignTokens.Typography.secondary)
      .forgeNumeric()

      HStack(spacing: DesignTokens.Spacing.step3) {
        Text("- WEIGHT LEFT")
          .foregroundStyle(DesignTokens.ColorToken.signal)
        Text("-- BODY FAT RIGHT")
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }
      .forgeTextStyle(DesignTokens.Typography.eyebrow)
    }
  }

  private func signed(_ value: Decimal) -> String {
    let prefix = value > 0 ? "+" : ""
    return "\(prefix)\(homeFormat(value))"
  }
}

private struct BodyTrendChart: View {
  let series: BodyPeriodSeries

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.input)
          .stroke(DesignTokens.ColorToken.hairline, lineWidth: 1)
        chartPath(points: series.weightPoints, value: \.weightKg, size: proxy.size)
          .stroke(DesignTokens.ColorToken.signal, lineWidth: 2)
        chartPath(points: series.fatPoints, value: \.bodyFatPct, size: proxy.size)
          .stroke(DesignTokens.ColorToken.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [DesignTokens.Spacing.step2, DesignTokens.Spacing.step1]))
      }
    }
  }

  private func chartPath(points: [BodyPeriodSeries.Point], value: KeyPath<BodyPeriodSeries.Point, Decimal?>, size: CGSize) -> Path {
    Path { path in
      let values = points.compactMap { $0[keyPath: value] }
      guard let minValue = values.min(), let maxValue = values.max(), !values.isEmpty else { return }
      let span = max(CGFloat(truncating: (maxValue - minValue) as NSNumber), 1)
      for (index, point) in points.enumerated() {
        guard let decimal = point[keyPath: value] else { continue }
        let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
        let y = size.height - CGFloat(truncating: (decimal - minValue) as NSNumber) / span * size.height
        if index == 0 {
          path.move(to: CGPoint(x: x, y: y))
        } else {
          path.addLine(to: CGPoint(x: x, y: y))
        }
      }
    }
  }
}

private struct PlaceholderTab: View {
  let title: String
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step3) {
      Text(title)
        .forgeTextStyle(DesignTokens.Typography.largeTitle)
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
      PlaceholderModuleText(message)
    }
    .padding(DesignTokens.Spacing.screenGutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(DesignTokens.ColorToken.surface)
  }
}

private struct HistoryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
  @State private var monthOffset = 0
  @State private var query = ""
  @State private var prOnly = false
  @State private var selectedSession: WorkoutSession?

  private var completedSessions: [WorkoutSession] {
    sessions.filter { $0.status == .completed }
  }

  private var visibleSessions: [WorkoutSession] {
    completedSessions.filter { session in
      let matchesText = query.isEmpty || session.name.localizedCaseInsensitiveContains(query)
      let matchesPR = !prOnly || sessionPRCount(session) > 0
      return matchesText && matchesPR
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardGap) {
          monthControls
          historyGrid
          filterBar
          sessionList
        }
        .padding(DesignTokens.Spacing.screenGutter)
      }
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("HISTORY")
      .sheet(item: $selectedSession) { session in
        HistoricalSessionEditor(session: session)
      }
    }
  }

  private var monthControls: some View {
    HStack {
      Button { monthOffset += 1 } label: {
        Image(systemName: "chevron.left")
      }
      .accessibilityLabel("Previous month")

      Spacer()
      Text(historyMonthLabel(offset: monthOffset))
        .forgeTextStyle(DesignTokens.Typography.heading)
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
      Spacer()

      Button { monthOffset = max(0, monthOffset - 1) } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(monthOffset == 0)
      .accessibilityLabel("Next month")
    }
    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
  }

  private var historyGrid: some View {
    let days = historyMonthDays(offset: monthOffset)
    return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.step1), count: 7), spacing: DesignTokens.Spacing.step1) {
      ForEach(days, id: \.self) { date in
        let daySessions = visibleSessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
        Button {
          selectedSession = daySessions.first
        } label: {
          VStack(spacing: DesignTokens.Spacing.step1) {
            Text("\(Calendar.current.component(.day, from: date))")
              .forgeTextStyle(DesignTokens.Typography.secondary)
              .forgeNumeric()
            Circle()
              .fill(daySessions.isEmpty ? DesignTokens.ColorToken.hairline : DesignTokens.ColorToken.signal)
              .frame(width: DesignTokens.Spacing.step2, height: DesignTokens.Spacing.step2)
          }
          .frame(maxWidth: .infinity, minHeight: DesignTokens.Spacing.step6)
          .foregroundStyle(daySessions.isEmpty ? DesignTokens.ColorToken.textTertiary : DesignTokens.ColorToken.textPrimary)
          .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.input))
          .overlay {
            if daySessions.isEmpty && completedSessions.isEmpty {
              RoundedRectangle(cornerRadius: DesignTokens.Radius.input)
                .stroke(DesignTokens.ColorToken.hairline, style: StrokeStyle(lineWidth: 1, dash: [DesignTokens.Spacing.step2, DesignTokens.Spacing.step1]))
            }
          }
        }
        .disabled(daySessions.isEmpty)
        .buttonStyle(.plain)
      }
    }
  }

  private var filterBar: some View {
    HStack(spacing: DesignTokens.Spacing.step2) {
      TextField("FILTER", text: $query)
        .textFieldStyle(.roundedBorder)
      Toggle("PRS", isOn: $prOnly)
        .toggleStyle(.button)
        .forgeTextStyle(DesignTokens.Typography.secondary)
    }
  }

  private var sessionList: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      if completedSessions.isEmpty {
        PlaceholderModuleText("Your first session will appear here")
      } else if visibleSessions.isEmpty {
        PlaceholderModuleText("No sessions match these filters")
      } else {
        ForEach(visibleSessions) { session in
          Button {
            selectedSession = session
          } label: {
            HistorySessionRow(session: session)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct HistorySessionRow: View {
  let session: WorkoutSession

  var body: some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.step3) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
        Text(session.name)
          .forgeTextStyle(DesignTokens.Typography.heading)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        Text(historyDateTime(session.startedAt))
          .forgeTextStyle(DesignTokens.Typography.secondary)
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: DesignTokens.Spacing.step1) {
        Text("\(sessionSetCount(session)) SETS")
        Text("\(homeFormat(sessionVolume(session))) KG")
        if sessionPRCount(session) > 0 {
          Text("\(sessionPRCount(session)) PR")
            .foregroundStyle(DesignTokens.ColorToken.signal)
        }
      }
      .forgeTextStyle(DesignTokens.Typography.secondary)
      .forgeNumeric()
      .foregroundStyle(DesignTokens.ColorToken.textSecondary)
    }
    .padding(DesignTokens.Spacing.cardPadding)
    .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
  }
}

private struct HistoricalSessionEditor: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Bindable var session: WorkoutSession
  @State private var isRecalculating = false

  var body: some View {
    NavigationStack {
      List {
        Section("SESSION") {
          TextField("Name", text: $session.name)
          DatePicker("Started", selection: $session.startedAt)
          DatePicker("Ended", selection: Binding(
            get: { session.endedAt ?? session.startedAt },
            set: { session.endedAt = $0 }
          ))
          TextField("Notes", text: Binding(
            get: { session.notes ?? "" },
            set: { session.notes = $0.isEmpty ? nil : $0 }
          ), axis: .vertical)
        }

        ForEach((session.exercises ?? []).sorted { $0.order < $1.order }) { exercise in
          Section(exercise.exercise?.name ?? "Exercise") {
            ForEach((exercise.sets ?? []).sorted { $0.index < $1.index }) { set in
              HistoricalSetRow(set: set)
            }
          }
        }

        Section {
          Button(role: .destructive) {
            Task {
              isRecalculating = true
              await HistoricalSessionInvalidator.delete(session: session, in: modelContext)
              isRecalculating = false
              dismiss()
            }
          } label: {
            Label("Delete session", systemImage: "trash")
          }
        }
      }
      .font(.system(.body, design: .monospaced))
      .navigationTitle("EDIT SESSION")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("CLOSE") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isRecalculating ? "SAVING" : "SAVE") {
            Task {
              isRecalculating = true
              await HistoricalSessionInvalidator.recalculate(session: session, in: modelContext)
              isRecalculating = false
              dismiss()
            }
          }
          .disabled(isRecalculating)
        }
      }
      .overlay(alignment: .bottom) {
        if isRecalculating {
          Text("RECALCULATING RECORDS...")
            .forgeTextStyle(DesignTokens.Typography.secondary)
            .foregroundStyle(DesignTokens.ColorToken.onSignal)
            .padding(DesignTokens.Spacing.step2)
            .background(DesignTokens.ColorToken.signal, in: Capsule())
            .padding(.bottom, DesignTokens.Spacing.step4)
        }
      }
    }
  }
}

private struct HistoricalSetRow: View {
  @Bindable var set: SetEntry

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.step2) {
      Text("\(set.index)")
        .forgeTextStyle(DesignTokens.Typography.secondary)
        .forgeNumeric()
        .frame(width: DesignTokens.Spacing.step5)
      DecimalField(title: "KG", value: $set.weightKg)
      IntField(title: "REPS", value: $set.reps)
      DecimalField(title: "RPE", value: $set.rpe)
      if set.isPR {
        Image(systemName: "star.fill")
          .foregroundStyle(DesignTokens.ColorToken.signal)
      }
    }
  }
}

private struct DecimalField: View {
  let title: String
  @Binding var value: Decimal?

  var body: some View {
    TextField(title, text: Binding(
      get: { value.map(homeFormat) ?? "" },
      set: { value = Decimal(string: $0) }
    ))
    .keyboardType(.decimalPad)
    .textFieldStyle(.roundedBorder)
    .forgeNumeric()
  }
}

private struct IntField: View {
  let title: String
  @Binding var value: Int?

  var body: some View {
    TextField(title, text: Binding(
      get: { value.map(String.init) ?? "" },
      set: { value = Int($0) }
    ))
    .keyboardType(.numberPad)
    .textFieldStyle(.roundedBorder)
    .forgeNumeric()
  }
}

private func historyMonthDays(offset: Int, calendar: Calendar = .current, now: Date = .now) -> [Date] {
  let shifted = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
  guard let interval = calendar.dateInterval(of: .month, for: shifted) else { return [] }
  let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
  return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
}

private func historyMonthLabel(offset: Int) -> String {
  let shifted = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "MMMM yyyy"
  return formatter.string(from: shifted).uppercased()
}

private func historyDateTime(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "MMM d, h:mm a"
  return formatter.string(from: date).uppercased()
}

private func sessionSetCount(_ session: WorkoutSession) -> Int {
  (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter { $0.completedAt != nil }.count
}

private func sessionVolume(_ session: WorkoutSession) -> Decimal {
  (session.exercises ?? []).flatMap { $0.sets ?? [] }.reduce(0) { $0 + ($1.volumeKg ?? 0) }
}

private func sessionPRCount(_ session: WorkoutSession) -> Int {
  (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isPR).count
}

#Preview("Light") {
  RootView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .preferredColorScheme(.dark)
}
