import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
        ProgressDashboardView()
          .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        LibraryView()
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
  @State private var showsSettings = false

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
            showsSettings = true
          } label: {
            Image(systemName: "gearshape")
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          .accessibilityLabel("Settings")
        }
      }
      .sheet(isPresented: $showsSettings) {
        SettingsSheet()
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

private struct SettingsSheet: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @AppStorage("settings.units") private var units = "kg"
  @AppStorage("settings.defaultRestSeconds") private var defaultRestSeconds = 120
  @AppStorage("settings.showRPE") private var showRPE = true
  @AppStorage("settings.barWeightKg") private var barWeightKg = 20.0
  @AppStorage("settings.availablePlatesKg") private var availablePlatesKg = "25,20,15,10,5,2.5,1.25"
  @AppStorage("settings.autoSaveHealth") private var autoSaveHealth = true
  @AppStorage("settings.theme") private var theme = "system"
  @State private var bodyweightText = ""
  @State private var bodyFatText = ""
  @State private var deleteConfirmation = ""
  @State private var isDeleting = false
  @State private var statusMessage: String?
  @State private var showsCSVImporter = false
  @State private var exportURL: URL?

  var body: some View {
    NavigationStack {
      List {
        Section("TRAINING") {
          Picker("Units", selection: $units) {
            Text("KG").tag("kg")
            Text("LB").tag("lb")
          }
          .pickerStyle(.segmented)

          Stepper("Default rest \(defaultRestSeconds / 60):\(String(format: "%02d", defaultRestSeconds % 60))", value: $defaultRestSeconds, in: 30...300, step: 30)
            .forgeNumeric()

          Toggle("Show RPE column", isOn: $showRPE)
          Toggle("Auto-save to Apple Health", isOn: $autoSaveHealth)
        }

        Section("PLATES") {
          DecimalDoubleField(title: "Bar weight kg", value: $barWeightKg)
          TextField("Available plates kg", text: $availablePlatesKg)
            .textInputAutocapitalization(.never)
        }

        Section("BODY") {
          TextField("Bodyweight kg", text: $bodyweightText)
            .keyboardType(.decimalPad)
            .forgeNumeric()
          TextField("Body fat %", text: $bodyFatText)
            .keyboardType(.decimalPad)
            .forgeNumeric()
          Button {
            saveBodyMetric()
          } label: {
            Label("Log body metric", systemImage: "plus")
          }
        }

        Section("CSV") {
          Button {
            exportCSV()
          } label: {
            Label("Export CSV", systemImage: "square.and.arrow.up")
          }

          if let exportURL {
            ShareLink(item: exportURL) {
              Label("Share exported CSV", systemImage: "doc")
            }
          }

          Button {
            showsCSVImporter = true
          } label: {
            Label("Import CSV", systemImage: "square.and.arrow.down")
          }
        }

        Section("APP") {
          Picker("Theme", selection: $theme) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
          }
          Text("iCloud private database sync")
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          Text("Health data remains in Apple Health; app data syncs through your private CloudKit database.")
            .forgeTextStyle(DesignTokens.Typography.secondary)
            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
        }

        Section("DELETE ALL DATA") {
          TextField("Type DELETE", text: $deleteConfirmation)
            .textInputAutocapitalization(.characters)
          Button(role: .destructive) {
            Task { await deleteAllData() }
          } label: {
            Label(isDeleting ? "Deleting" : "Delete all data", systemImage: "trash")
          }
          .disabled(deleteConfirmation != "DELETE" || isDeleting)
        }

        if let statusMessage {
          Section {
            Text(statusMessage)
              .forgeTextStyle(DesignTokens.Typography.secondary)
              .foregroundStyle(DesignTokens.ColorToken.signal)
          }
        }
      }
      .font(.system(.body, design: .monospaced))
      .scrollContentBackground(.hidden)
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("SETTINGS")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("DONE") { dismiss() }
        }
      }
      .fileImporter(isPresented: $showsCSVImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
        importCSV(result)
      }
    }
  }

  private func saveBodyMetric() {
    guard let bodyweight = Decimal(string: bodyweightText), bodyweight > 0 else {
      statusMessage = "Bodyweight is required"
      return
    }
    let bodyFat = Decimal(string: bodyFatText)
    modelContext.insert(BodyMetric(date: .now, bodyweightKg: bodyweight, bodyFatPct: bodyFat))
    try? modelContext.save()
    bodyweightText = ""
    bodyFatText = ""
    statusMessage = "Body metric logged"
  }

  private func exportCSV() {
    let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    let csv = CSVTransfer.exportString(from: sessions)
    let url = FileManager.default.temporaryDirectory.appending(path: "repsetforge-export.csv")
    do {
      try csv.write(to: url, atomically: true, encoding: .utf8)
      exportURL = url
      statusMessage = "CSV export ready"
    } catch {
      statusMessage = "CSV export failed"
    }
  }

  private func importCSV(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      let canAccess = url.startAccessingSecurityScopedResource()
      defer {
        if canAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let csv = try String(contentsOf: url, encoding: .utf8)
      let count = try CSVTransfer.importString(csv, in: modelContext)
      statusMessage = "Imported \(count) sets"
    } catch {
      statusMessage = "CSV import failed"
    }
  }

  @MainActor
  private func deleteAllData() async {
    isDeleting = true
    let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    for session in sessions where session.healthKitUUID != nil {
      _ = await HealthKitWorkoutExporter().delete(session: session)
    }

    deleteAll(WorkoutSession.self)
    deleteAll(Exercise.self)
    deleteAll(Routine.self)
    deleteAll(RoutineItem.self)
    deleteAll(ProgressionRule.self)
    deleteAll(PRRecord.self)
    deleteAll(BodyMetric.self)
    deleteAll(UserProfile.self)
    try? modelContext.save()

    deleteConfirmation = ""
    isDeleting = false
    statusMessage = "All app data deleted"
  }

  private func deleteAll<T: PersistentModel>(_ type: T.Type) {
    let models = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
    models.forEach(modelContext.delete)
  }
}

private struct DecimalDoubleField: View {
  let title: String
  @Binding var value: Double

  var body: some View {
    TextField(title, text: Binding(
      get: { value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value) },
      set: { value = Double($0) ?? value }
    ))
    .keyboardType(.decimalPad)
    .textFieldStyle(.roundedBorder)
    .forgeNumeric()
  }
}

private struct ProgressDashboardView: View {
  @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

  private var completedSessions: [WorkoutSession] {
    sessions.filter { $0.status == .completed }.sorted { $0.startedAt < $1.startedAt }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardGap) {
          ChartCard(
            title: "VOLUME",
            points: progressVolumePoints(completedSessions),
            unit: "KG",
            lockedMessage: "Log 4 workouts to unlock volume trend"
          )
          ChartCard(
            title: "E1RM",
            points: progressE1RMPoints(completedSessions),
            unit: "KG",
            lockedMessage: "Log 4 workouts with load and reps to unlock e1RM trend"
          )
          ChartCard(
            title: "PRS",
            points: progressPRPoints(completedSessions),
            unit: "PRS",
            lockedMessage: "Log 4 workouts to unlock PR trend"
          )
        }
        .padding(DesignTokens.Spacing.screenGutter)
      }
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("PROGRESS")
    }
  }
}

private struct ChartCard: View {
  let title: String
  let points: [ProgressChartPoint]
  let unit: String
  let lockedMessage: String

  private var isLocked: Bool {
    points.count < 4
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step3) {
      HStack {
        Text(title)
          .forgeTextStyle(DesignTokens.Typography.heading)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        Spacer()
        Text(isLocked ? "\(points.count)/4" : unit)
          .forgeTextStyle(DesignTokens.Typography.secondary)
          .forgeNumeric()
          .foregroundStyle(isLocked ? DesignTokens.ColorToken.textTertiary : DesignTokens.ColorToken.signal)
      }

      if isLocked {
        PlaceholderModuleText(lockedMessage)
      } else {
        ProgressLineChart(points: points)
          .frame(height: DesignTokens.Spacing.step6 * 4)
        Text(progressInsight(points: points, unit: unit))
          .forgeTextStyle(DesignTokens.Typography.body)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }
    }
    .padding(DesignTokens.Spacing.cardPadding)
    .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
  }
}

private struct ProgressLineChart: View {
  let points: [ProgressChartPoint]

  var body: some View {
    Canvas { context, size in
      guard points.count > 1 else { return }
      let values = points.map(\.value)
      let minValue = values.min() ?? 0
      let maxValue = values.max() ?? 1
      let span = max(CGFloat(truncating: (maxValue - minValue) as NSNumber), 1)
      let stepX = size.width / CGFloat(max(points.count - 1, 1))

      var area = Path()
      area.move(to: CGPoint(x: 0, y: size.height))
      var line = Path()

      for index in points.indices {
        let value = points[index].value
        let x = CGFloat(index) * stepX
        let y = size.height - CGFloat(truncating: (value - minValue) as NSNumber) / span * size.height
        if index == 0 {
          line.move(to: CGPoint(x: x, y: y))
        } else {
          line.addLine(to: CGPoint(x: x, y: y))
        }
        area.addLine(to: CGPoint(x: x, y: y))
      }

      area.addLine(to: CGPoint(x: size.width, y: size.height))
      area.closeSubpath()

      context.fill(area, with: .color(DesignTokens.ColorToken.signalDim))
      context.stroke(line, with: .color(DesignTokens.ColorToken.signal), lineWidth: 2)

      for index in points.indices {
        let value = points[index].value
        let x = CGFloat(index) * stepX
        let y = size.height - CGFloat(truncating: (value - minValue) as NSNumber) / span * size.height
        context.fill(Path(ellipseIn: CGRect(
          x: x - DesignTokens.Spacing.step1,
          y: y - DesignTokens.Spacing.step1,
          width: DesignTokens.Spacing.step2,
          height: DesignTokens.Spacing.step2
        )), with: .color(DesignTokens.ColorToken.signal))
      }
    }
  }
}

private struct ProgressChartPoint: Identifiable {
  let id = UUID()
  let date: Date
  let value: Decimal
}

private func progressVolumePoints(_ sessions: [WorkoutSession]) -> [ProgressChartPoint] {
  sessions.compactMap { session in
    let value = sessionVolume(session)
    guard value > 0 else { return nil }
    return ProgressChartPoint(date: session.startedAt, value: value)
  }
}

private func progressE1RMPoints(_ sessions: [WorkoutSession]) -> [ProgressChartPoint] {
  sessions.compactMap { session in
    let best = (session.exercises ?? [])
      .flatMap { $0.sets ?? [] }
      .compactMap(\.estimatedOneRepMaxKg)
      .max()
    guard let best else { return nil }
    return ProgressChartPoint(date: session.startedAt, value: best)
  }
}

private func progressPRPoints(_ sessions: [WorkoutSession]) -> [ProgressChartPoint] {
  sessions.map { session in
    ProgressChartPoint(date: session.startedAt, value: Decimal(sessionPRCount(session)))
  }
}

private func progressInsight(points: [ProgressChartPoint], unit: String) -> String {
  guard let first = points.first, let last = points.last else { return "Trend unavailable" }
  let delta = last.value - first.value
  let direction = delta >= 0 ? "UP" : "DOWN"
  return "\(direction) \(homeFormat(abs(delta))) \(unit) OVER \(points.count) WORKOUTS"
}

private struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Routine.name) private var routines: [Routine]
  @State private var showsBuilder = false
  @State private var editingRoutine: Routine?

  private var activeRoutines: [Routine] {
    routines.filter { $0.archivedAt == nil }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardGap) {
          if activeRoutines.isEmpty {
            PlaceholderModuleText("Build a routine to get session recommendations")
          } else {
            ForEach(activeRoutines) { routine in
              Button {
                editingRoutine = routine
              } label: {
                RoutineLibraryCard(routine: routine)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(DesignTokens.Spacing.screenGutter)
      }
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("LIBRARY")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showsBuilder = true
          } label: {
            Image(systemName: "plus")
              .foregroundStyle(DesignTokens.ColorToken.signal)
          }
          .accessibilityLabel("New routine")
        }
      }
      .sheet(isPresented: $showsBuilder) {
        RoutineBuilderView(routine: nil)
      }
      .sheet(item: $editingRoutine) { routine in
        RoutineBuilderView(routine: routine)
      }
    }
  }
}

private struct RoutineLibraryCard: View {
  let routine: Routine

  private var orderedItems: [RoutineItem] {
    (routine.orderedItems ?? []).sorted { $0.order < $1.order }
  }

  private var groupCount: Int {
    Set(orderedItems.compactMap(\.groupID)).count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
          Text(routine.name.uppercased())
            .forgeTextStyle(DesignTokens.Typography.heading)
            .foregroundStyle(DesignTokens.ColorToken.textPrimary)
          Text("\(orderedItems.count) EXERCISES · \(groupCount) GROUPS")
            .forgeTextStyle(DesignTokens.Typography.secondary)
            .forgeNumeric()
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      }

      ForEach(orderedItems.prefix(4)) { item in
        HStack(spacing: DesignTokens.Spacing.step2) {
          if item.groupID != nil {
            Rectangle()
              .fill(DesignTokens.ColorToken.signal)
              .frame(width: DesignTokens.Spacing.step1)
          }
          Text(item.exercise?.name ?? "Exercise")
            .forgeTextStyle(DesignTokens.Typography.secondary)
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          Spacer()
          Text("\(item.targetSets)×\(item.targetRepsLow)-\(item.targetRepsHigh)")
            .forgeTextStyle(DesignTokens.Typography.secondary)
            .forgeNumeric()
            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
        }
      }
    }
    .padding(DesignTokens.Spacing.cardPadding)
    .background(DesignTokens.ColorToken.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
  }
}

private struct RoutineBuilderView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Exercise.name) private var exercises: [Exercise]
  let routine: Routine?
  @State private var name = ""
  @State private var items: [RoutineItemDraft] = []
  @State private var validationMessage: String?

  var body: some View {
    NavigationStack {
      List {
        Section("ROUTINE") {
          TextField("Name", text: $name)
            .forgeTextStyle(DesignTokens.Typography.body)
        }

        Section("EXERCISES") {
          if items.isEmpty {
            Text("Add at least one exercise")
              .forgeTextStyle(DesignTokens.Typography.secondary)
              .foregroundStyle(DesignTokens.ColorToken.textTertiary)
          }

          ForEach($items) { $item in
            RoutineItemDraftRow(item: $item, exercises: exercises)
          }
          .onMove { source, destination in
            items.move(fromOffsets: source, toOffset: destination)
            normalizeOrders()
          }

          Button {
            items.append(RoutineItemDraft(order: items.count))
          } label: {
            Label("Add exercise", systemImage: "plus")
          }
        }

        if let validationMessage {
          Section {
            Text(validationMessage)
              .forgeTextStyle(DesignTokens.Typography.secondary)
              .foregroundStyle(DesignTokens.ColorToken.warning)
          }
        }
      }
      .font(.system(.body, design: .monospaced))
      .scrollContentBackground(.hidden)
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle(routine == nil ? "NEW ROUTINE" : "EDIT ROUTINE")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("CLOSE") { dismiss() }
        }
        ToolbarItem(placement: .topBarLeading) {
          EditButton()
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("SAVE") {
            save()
          }
        }
      }
      .onAppear(perform: load)
    }
  }

  private func load() {
    guard items.isEmpty, let routine else { return }
    name = routine.name
    items = (routine.orderedItems ?? [])
      .sorted { $0.order < $1.order }
      .enumerated()
      .map { offset, item in
        RoutineItemDraft(
          id: item.id,
          exercise: item.exercise,
          order: offset,
          groupID: item.groupID,
          targetSets: item.targetSets,
          targetRepsLow: item.targetRepsLow,
          targetRepsHigh: item.targetRepsHigh,
          targetRPE: item.targetRPE,
          restSeconds: item.restSeconds,
          note: item.note,
          rule: item.progressionRule.map { RoutineRuleDraft(rule: $0) } ?? RoutineRuleDraft()
        )
      }
  }

  private func normalizeOrders() {
    for index in items.indices {
      items[index].order = index
    }
  }

  private func save() {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      validationMessage = "Routine name is required"
      return
    }
    guard !items.isEmpty else {
      validationMessage = "Add at least one exercise"
      return
    }
    guard items.allSatisfy({ $0.exercise != nil }) else {
      validationMessage = "Every row needs an exercise"
      return
    }
    normalizeOrders()

    let target = routine ?? Routine(name: trimmedName)
    if routine == nil {
      modelContext.insert(target)
    }
    target.name = trimmedName

    for oldItem in target.orderedItems ?? [] {
      modelContext.delete(oldItem)
    }

    let savedItems = items.map { draft in
      let rule = ProgressionRule(
        repRangeLow: draft.rule.repRangeLow,
        repRangeHigh: draft.rule.repRangeHigh,
        maxQualifyingRPE: draft.rule.maxQualifyingRPE,
        qualifyingSetsRequired: draft.rule.qualifyingSetsRequired,
        incrementKg: draft.rule.incrementKg
      )
      let item = RoutineItem(
        routine: target,
        exercise: draft.exercise,
        order: draft.order,
        groupID: draft.groupID,
        targetSets: draft.targetSets,
        targetRepsLow: draft.targetRepsLow,
        targetRepsHigh: draft.targetRepsHigh,
        targetRPE: draft.targetRPE,
        restSeconds: draft.restSeconds,
        note: draft.note,
        progressionRule: rule
      )
      modelContext.insert(rule)
      modelContext.insert(item)
      return item
    }
    target.orderedItems = savedItems

    try? modelContext.save()
    dismiss()
  }
}

private struct RoutineItemDraftRow: View {
  @Binding var item: RoutineItemDraft
  let exercises: [Exercise]

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      Picker("Exercise", selection: Binding(
        get: { item.exercise?.id },
        set: { id in item.exercise = exercises.first { $0.id == id } }
      )) {
        Text("Select").tag(UUID?.none)
        ForEach(exercises) { exercise in
          Text(exercise.name).tag(Optional(exercise.id))
        }
      }

      Toggle("Superset group", isOn: Binding(
        get: { item.groupID != nil },
        set: { isGrouped in item.groupID = isGrouped ? (item.groupID ?? UUID()) : nil }
      ))
      .toggleStyle(.switch)

      HStack(spacing: DesignTokens.Spacing.step2) {
        Stepper("SETS \(item.targetSets)", value: $item.targetSets, in: 1...10)
        Stepper("REST \(item.restSeconds)s", value: $item.restSeconds, in: 30...300, step: 30)
      }
      .forgeTextStyle(DesignTokens.Typography.secondary)
      .forgeNumeric()

      HStack(spacing: DesignTokens.Spacing.step2) {
        IntValueField(title: "LOW", value: $item.targetRepsLow)
        IntValueField(title: "HIGH", value: $item.targetRepsHigh)
        DecimalField(title: "RPE", value: $item.targetRPE)
      }

      TextField("Note", text: Binding(
        get: { item.note ?? "" },
        set: { item.note = $0.isEmpty ? nil : $0 }
      ))
      .textFieldStyle(.roundedBorder)

      RoutineRuleDraftEditor(rule: $item.rule)
    }
    .padding(.vertical, DesignTokens.Spacing.step1)
    .overlay(alignment: .leading) {
      if item.groupID != nil {
        Rectangle()
          .fill(DesignTokens.ColorToken.signal)
          .frame(width: DesignTokens.Spacing.step1)
          .padding(.vertical, DesignTokens.Spacing.step1)
      }
    }
  }
}

private struct RoutineRuleDraftEditor: View {
  @Binding var rule: RoutineRuleDraft

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      Text("PROGRESSION RULE")
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      HStack(spacing: DesignTokens.Spacing.step2) {
        IntValueField(title: "MIN", value: $rule.repRangeLow)
        IntValueField(title: "MAX", value: $rule.repRangeHigh)
      }
      HStack(spacing: DesignTokens.Spacing.step2) {
        DecimalValueField(title: "MAX RPE", value: $rule.maxQualifyingRPE)
        IntValueField(title: "SETS", value: $rule.qualifyingSetsRequired)
        DecimalValueField(title: "KG", value: $rule.incrementKg)
      }
    }
  }
}

private struct RoutineItemDraft: Identifiable {
  var id = UUID()
  var exercise: Exercise?
  var order: Int
  var groupID: UUID?
  var targetSets = 3
  var targetRepsLow = 8
  var targetRepsHigh = 12
  var targetRPE: Decimal? = 8
  var restSeconds = 120
  var note: String?
  var rule = RoutineRuleDraft()
}

private struct RoutineRuleDraft {
  var repRangeLow = 8
  var repRangeHigh = 12
  var maxQualifyingRPE: Decimal = 9
  var qualifyingSetsRequired = 2
  var incrementKg: Decimal = 2.5

  init() {}

  init(rule: ProgressionRule) {
    repRangeLow = rule.repRangeLow
    repRangeHigh = rule.repRangeHigh
    maxQualifyingRPE = rule.maxQualifyingRPE
    qualifyingSetsRequired = rule.qualifyingSetsRequired
    incrementKg = rule.incrementKg
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

private struct DecimalValueField: View {
  let title: String
  @Binding var value: Decimal

  var body: some View {
    TextField(title, text: Binding(
      get: { homeFormat(value) },
      set: { value = Decimal(string: $0) ?? value }
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

private struct IntValueField: View {
  let title: String
  @Binding var value: Int

  var body: some View {
    TextField(title, text: Binding(
      get: { String(value) },
      set: { value = Int($0) ?? value }
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
