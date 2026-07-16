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
        PlaceholderTab(title: "HISTORY", message: "Your first session will appear here")
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
      if bodyMetrics.count < 2 {
        PlaceholderModuleText("Log today's weight")
      } else {
        BodyTrendSketch(metrics: Array(bodyMetrics.prefix(14).reversed()))
          .frame(height: DesignTokens.Spacing.step6 * 4)
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

private struct BodyTrendSketch: View {
  let metrics: [BodyMetric]

  var body: some View {
    GeometryReader { proxy in
      Path { path in
        let weights = metrics.map(\.bodyweightKg)
        guard let minWeight = weights.min(), let maxWeight = weights.max(), !weights.isEmpty else { return }
        for (index, value) in weights.enumerated() {
          let x = proxy.size.width * CGFloat(index) / CGFloat(max(weights.count - 1, 1))
          let range = max(CGFloat(truncating: (maxWeight - minWeight) as NSNumber), 1)
          let y = proxy.size.height - CGFloat(truncating: (value - minWeight) as NSNumber) / range * proxy.size.height
          if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
      }
      .stroke(DesignTokens.ColorToken.signal, lineWidth: 2)

      Path { path in
        let fatPoints = metrics.enumerated().compactMap { index, metric -> (Int, Decimal)? in
          guard let bodyFatPct = metric.bodyFatPct else { return nil }
          return (index, bodyFatPct)
        }
        guard let minFat = fatPoints.map(\.1).min(), let maxFat = fatPoints.map(\.1).max(), !fatPoints.isEmpty else { return }
        for (offset, point) in fatPoints.enumerated() {
          let x = proxy.size.width * CGFloat(point.0) / CGFloat(max(metrics.count - 1, 1))
          let range = max(CGFloat(truncating: (maxFat - minFat) as NSNumber), 1)
          let y = proxy.size.height - CGFloat(truncating: (point.1 - minFat) as NSNumber) / range * proxy.size.height
          if offset == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
      }
      .stroke(DesignTokens.ColorToken.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [DesignTokens.Spacing.step2, DesignTokens.Spacing.step1]))
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

#Preview("Light") {
  RootView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .preferredColorScheme(.dark)
}
