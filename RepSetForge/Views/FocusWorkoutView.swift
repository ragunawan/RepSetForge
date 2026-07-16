import SwiftUI

struct FocusWorkoutView: View {
  @Bindable var store: FocusWorkoutStore
  @State private var showsIndex = false
  @State private var showsProgression = false

  var body: some View {
    ZStack(alignment: .bottom) {
      DesignTokens.ColorToken.surface
        .ignoresSafeArea()

      TabView(selection: $store.selectedExerciseID) {
        ForEach(store.exercises) { exercise in
          ExerciseFocusPage(store: store, exercise: exercise)
            .tag(exercise.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      BottomFocusPill(store: store, showsIndex: $showsIndex, showsProgression: $showsProgression)
    }
    .sheet(isPresented: $showsIndex) {
      ExerciseIndexSheet(store: store)
        .presentationDetents([.medium])
    }
    .sheet(isPresented: $showsProgression) {
      ProgressionSheet(exercise: store.exercises[store.selectedIndex])
        .presentationDetents([.medium, .large])
    }
    .environment(\.font, .system(.body, design: .monospaced))
  }
}

private struct ExerciseFocusPage: View {
  @Bindable var store: FocusWorkoutStore
  let exercise: FocusExercise

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        TelemetryHeader(store: store)
        Divider().overlay(DesignTokens.ColorToken.hairline)
        ExerciseIdentityRow(exercise: exercise)
        Divider().overlay(DesignTokens.ColorToken.hairline)
        ExerciseChart(store: store, exercise: exercise)
        Divider().overlay(DesignTokens.ColorToken.hairline)
        CoachingPrompt(store: store, exercise: exercise)
        SetTable(store: store, exercise: exercise)
        FinishWorkoutButton()
      }
      .padding(.bottom, DesignTokens.Spacing.step6 * 3)
    }
  }
}

private struct TelemetryHeader: View {
  @Bindable var store: FocusWorkoutStore

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.step2) {
      HStack {
        MetricBlock(label: "SESSION", value: timerText)
        Spacer(minLength: DesignTokens.Spacing.step4)
        MetricBlock(label: "SET", value: "\(store.completedSetCount)/\(store.plannedSetCount)")
      }

      HStack {
        MetricBlock(label: "WORK", value: duration(store.workDuration()))
        Spacer(minLength: DesignTokens.Spacing.step4)
        MetricBlock(label: "REST", value: duration(store.completedRestDuration))
        Spacer(minLength: DesignTokens.Spacing.step4)
        MetricBlock(label: "DONE", value: "\(store.percentComplete)%")
      }

      ProgressView(value: Double(store.completedSetCount), total: Double(max(store.plannedSetCount, 1)))
        .tint(DesignTokens.ColorToken.signal)
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .padding(.vertical, DesignTokens.Spacing.step3)
  }

  private var timerText: String {
    duration(Date().timeIntervalSince(store.startedAt))
  }

  private func duration(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded()))
    return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
  }
}

private struct MetricBlock: View {
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

private struct ExerciseIdentityRow: View {
  let exercise: FocusExercise

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.step3) {
      RoundedRectangle(cornerRadius: DesignTokens.Radius.input)
        .fill(DesignTokens.ColorToken.surfaceInput)
        .frame(width: DesignTokens.Spacing.step6, height: DesignTokens.Spacing.step6)
        .overlay(
          Text("●")
            .forgeTextStyle(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.ColorToken.signal)
        )

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
        Text(exercise.name)
          .forgeTextStyle(DesignTokens.Typography.title)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        Text(exercise.detail)
          .forgeTextStyle(DesignTokens.Typography.secondary)
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }

      Spacer()
      Text("•••")
        .forgeTextStyle(DesignTokens.Typography.heading)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .padding(.vertical, DesignTokens.Spacing.step3)
  }
}

private struct ExerciseChart: View {
  @Bindable var store: FocusWorkoutStore
  let exercise: FocusExercise

  var body: some View {
    Group {
      if store.isChartExpanded(for: exercise) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
          HStack {
            Chip(text: "WEIGHT × REPS", isActive: true)
            Spacer()
            Chip(text: "3M", isActive: false)
            Chip(text: "%1RM", isActive: false)
          }

          ChartSketch(exercise: exercise)
            .frame(height: DesignTokens.Spacing.step6 * 4)

          HStack {
            Chip(text: "1RM \(format(exercise.oneRepMaxKg)) KG", isActive: false)
            Chip(text: "PR \(format(exercise.previousBestWeightKg))×\(exercise.previousBestReps)", isActive: false, isPR: true)
          }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenGutter)
        .padding(.vertical, DesignTokens.Spacing.step3)
        .transition(.opacity.combined(with: .move(edge: .top)))
      } else {
        Button {
          withAnimation(.easeInOut(duration: DesignTokens.Motion.stateChangeDuration)) {
            store.setChartExpanded(true, for: exercise)
          }
        } label: {
          HStack {
            Text("CHART")
              .forgeTextStyle(DesignTokens.Typography.eyebrow)
              .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            Spacer()
            Text("1RM \(format(exercise.oneRepMaxKg)) · PR \(format(exercise.previousBestWeightKg))×\(exercise.previousBestReps)")
              .forgeTextStyle(DesignTokens.Typography.numericRow)
              .forgeNumeric()
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          .padding(.horizontal, DesignTokens.Spacing.screenGutter)
          .padding(.vertical, DesignTokens.Spacing.step3)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct ChartSketch: View {
  let exercise: FocusExercise

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let count = max(exercise.trend.count, 1)
      let step = width / CGFloat(count)

      ZStack(alignment: .topLeading) {
        Path { path in
          path.move(to: CGPoint(x: 0, y: height * 0.25))
          path.addLine(to: CGPoint(x: width, y: height * 0.25))
        }
        .stroke(DesignTokens.ColorToken.warning, style: StrokeStyle(lineWidth: 1, dash: [DesignTokens.Spacing.step1, DesignTokens.Spacing.step1]))

        ForEach(Array(exercise.trend.enumerated()), id: \.offset) { index, value in
          let barHeight = max(DesignTokens.Spacing.step3, height - CGFloat(truncating: value as NSNumber))
          RoundedRectangle(cornerRadius: DesignTokens.Radius.checkbox)
            .fill(DesignTokens.ColorToken.surfaceInput)
            .frame(width: max(DesignTokens.Spacing.step2, step * 0.55), height: barHeight)
            .position(x: CGFloat(index) * step + step * 0.5, y: height - barHeight * 0.5)
        }

        Path { path in
          for (index, value) in exercise.trend.enumerated() {
            let point = CGPoint(x: CGFloat(index) * step + step * 0.5, y: CGFloat(truncating: value as NSNumber))
            if index == 0 {
              path.move(to: point)
            } else {
              path.addLine(to: point)
            }
          }
        }
        .stroke(DesignTokens.ColorToken.signal, lineWidth: 2)

        Text("75% · \(format(exercise.oneRepMaxKg * 0.75)) KG")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .foregroundStyle(DesignTokens.ColorToken.warning)
          .padding(.top, DesignTokens.Spacing.step2)
      }
    }
  }
}

private struct Chip: View {
  let text: String
  let isActive: Bool
  var isPR = false

  var body: some View {
    Text(text)
      .forgeTextStyle(DesignTokens.Typography.eyebrow)
      .forgeNumeric()
      .foregroundStyle(isPR ? DesignTokens.ColorToken.pr : DesignTokens.ColorToken.textSecondary)
      .padding(.horizontal, DesignTokens.Spacing.step2)
      .padding(.vertical, DesignTokens.Spacing.step1)
      .background(isActive ? DesignTokens.ColorToken.signalDim : DesignTokens.ColorToken.surfaceInput)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.segment))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.segment)
          .stroke(isPR ? DesignTokens.ColorToken.pr : DesignTokens.ColorToken.hairline)
      )
  }
}

private struct CoachingPrompt: View {
  @Bindable var store: FocusWorkoutStore
  let exercise: FocusExercise

  var body: some View {
    Button {
      store.applyTarget(to: exercise.id)
    } label: {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
        Text("SAME AS LAST SESSION · TAP TO APPLY")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        Text("TARGET ≥ \(format(exercise.coachingTarget.weightKg)) KG × \(exercise.coachingTarget.reps) @ ≤\(format(exercise.progressionRule.maxQualifyingRPE)) RPE")
          .forgeTextStyle(DesignTokens.Typography.numericRow)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.signal)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, DesignTokens.Spacing.screenGutter)
      .padding(.vertical, DesignTokens.Spacing.step3)
      .background(DesignTokens.ColorToken.signalDim)
    }
    .buttonStyle(.plain)
  }
}

private struct SetTable: View {
  @Bindable var store: FocusWorkoutStore
  let exercise: FocusExercise
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(spacing: 0) {
      if dynamicTypeSize < .accessibility1 {
        header
      }

      ForEach(exercise.sets) { set in
        SetRow(store: store, exercise: exercise, set: set)
        if set.isPR {
          PRBadgeRow()
        }
        Divider().overlay(DesignTokens.ColorToken.hairline)
      }
    }
  }

  private var header: some View {
    Grid(horizontalSpacing: DesignTokens.Spacing.step2, verticalSpacing: 0) {
      GridRow {
        tableHeader("#")
        tableHeader("WEIGHT")
        tableHeader("REPS")
        tableHeader("RPE")
        tableHeader("REST")
        tableHeader("✓")
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .padding(.top, DesignTokens.Spacing.step3)
    .padding(.bottom, DesignTokens.Spacing.step1)
  }

  private func tableHeader(_ text: String) -> some View {
    Text(text)
      .forgeTextStyle(DesignTokens.Typography.eyebrow)
      .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      .frame(maxWidth: .infinity)
  }
}

private struct SetRow: View {
  @Bindable var store: FocusWorkoutStore
  let exercise: FocusExercise
  let set: FocusSet
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showsRPEChips = false
  @State private var showsPlateCalculator = false

  var body: some View {
    VStack(spacing: 0) {
      Group {
        if dynamicTypeSize >= .accessibility2 {
          stackedRow
        } else {
          gridRow
        }
      }
      if showsRPEChips && !set.isCompleted {
        RPEChipRow(selected: store.displayRPE(for: set, in: exercise)) { value in
          store.updateRPE(value, setID: set.id, exerciseID: exercise.id)
          showsRPEChips = false
        }
      }
    }
    .opacity(set.isCompleted ? 0.55 : 1)
    .background(set.isPR ? DesignTokens.ColorToken.prDim : Color.clear)
    .animation(.easeInOut(duration: DesignTokens.Motion.stateChangeDuration), value: set.isCompleted)
  }

  private var gridRow: some View {
    Grid(horizontalSpacing: DesignTokens.Spacing.step2, verticalSpacing: 0) {
      GridRow {
        typeBadge
        FieldStepper(
          text: weightText,
          isGhost: store.isGhost(.weight, set: set),
          keyboard: .decimalPad,
          onTextChange: { store.updateWeight(decimal(from: $0), setID: set.id, exerciseID: exercise.id) },
          decrement: { store.step(.weight, setID: set.id, exerciseID: exercise.id, direction: -1) },
          increment: { store.step(.weight, setID: set.id, exerciseID: exercise.id, direction: 1) },
          onLongPress: { showsPlateCalculator = true }
        )
        .popover(isPresented: $showsPlateCalculator) {
          PlateCalculatorView(weightKg: store.displayWeight(for: set, in: exercise) ?? 0)
            .presentationCompactAdaptation(.popover)
        }
        FieldStepper(
          text: repsText,
          isGhost: store.isGhost(.reps, set: set),
          keyboard: .numberPad,
          onTextChange: { store.updateReps(Int($0), setID: set.id, exerciseID: exercise.id) },
          decrement: { store.step(.reps, setID: set.id, exerciseID: exercise.id, direction: -1) },
          increment: { store.step(.reps, setID: set.id, exerciseID: exercise.id, direction: 1) }
        )
        FieldStepper(
          text: rpeText,
          isGhost: store.isGhost(.rpe, set: set),
          keyboard: .decimalPad,
          onTextChange: { store.updateRPE(decimal(from: $0), setID: set.id, exerciseID: exercise.id) },
          decrement: { store.step(.rpe, setID: set.id, exerciseID: exercise.id, direction: -1) },
          increment: { store.step(.rpe, setID: set.id, exerciseID: exercise.id, direction: 1) },
          onTap: { showsRPEChips.toggle() }
        )
        if dynamicTypeSize < .accessibility1 {
          FieldStepper(
            text: restText,
            isGhost: store.isGhost(.rest, set: set),
            keyboard: .numberPad,
            onTextChange: { store.updateRest(Int($0).map { $0 * 60 } ?? store.inheritedRest(for: set, in: exercise), setID: set.id, exerciseID: exercise.id) },
            decrement: { store.step(.rest, setID: set.id, exerciseID: exercise.id, direction: -1) },
            increment: { store.step(.rest, setID: set.id, exerciseID: exercise.id, direction: 1) }
          )
        } else {
          Text(restText)
            .forgeTextStyle(DesignTokens.Typography.eyebrow)
            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
        }
        CompleteButton(isCompleted: set.isCompleted) {
          complete()
        }
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .frame(minHeight: DesignTokens.Spacing.setRowHitTarget)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAction(named: "Complete set", complete)
  }

  private var stackedRow: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      HStack {
        Text("SET \(set.index) · \(set.type.label.uppercased())")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        Spacer()
        Text("PREV \(format(exercise.previousBestWeightKg))×\(exercise.previousBestReps)")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      }

      HStack(spacing: DesignTokens.Spacing.step2) {
        FieldStepper(text: weightText, isGhost: store.isGhost(.weight, set: set), keyboard: .decimalPad, onTextChange: { store.updateWeight(decimal(from: $0), setID: set.id, exerciseID: exercise.id) }, decrement: { store.step(.weight, setID: set.id, exerciseID: exercise.id, direction: -1) }, increment: { store.step(.weight, setID: set.id, exerciseID: exercise.id, direction: 1) }, onLongPress: { showsPlateCalculator = true })
          .popover(isPresented: $showsPlateCalculator) {
            PlateCalculatorView(weightKg: store.displayWeight(for: set, in: exercise) ?? 0)
              .presentationCompactAdaptation(.popover)
          }
        FieldStepper(text: repsText, isGhost: store.isGhost(.reps, set: set), keyboard: .numberPad, onTextChange: { store.updateReps(Int($0), setID: set.id, exerciseID: exercise.id) }, decrement: { store.step(.reps, setID: set.id, exerciseID: exercise.id, direction: -1) }, increment: { store.step(.reps, setID: set.id, exerciseID: exercise.id, direction: 1) })
        CompleteButton(isCompleted: set.isCompleted) { complete() }
      }

      HStack(spacing: DesignTokens.Spacing.step2) {
        Chip(text: "RPE \(rpeText)", isActive: false)
        Chip(text: "REST \(restText)", isActive: false)
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .padding(.vertical, DesignTokens.Spacing.step3)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAction(named: "Complete set", complete)
  }

  private var typeBadge: some View {
    Text(set.type.shortLabel)
      .forgeTextStyle(DesignTokens.Typography.numericRow)
      .forgeNumeric()
      .foregroundStyle(set.type == .warmup ? DesignTokens.ColorToken.pr : DesignTokens.ColorToken.textSecondary)
      .frame(maxWidth: .infinity)
  }

  private var weightText: String {
    store.displayWeight(for: set, in: exercise).map { format($0) } ?? "–"
  }

  private var repsText: String {
    store.displayReps(for: set, in: exercise).map(String.init) ?? "–"
  }

  private var rpeText: String {
    store.displayRPE(for: set, in: exercise).map { format($0) } ?? "–"
  }

  private var restText: String {
    let seconds = store.inheritedRest(for: set, in: exercise)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private var accessibilityLabel: String {
    "\(exercise.name), set \(set.index) of \(exercise.plannedSets), previous \(format(exercise.previousBestWeightKg)) kilograms for \(exercise.previousBestReps) reps. Weight, \(weightText). Reps, \(repsText). \(set.isCompleted ? "Completed." : "Not completed.")"
  }

  private func complete() {
    showsRPEChips = false
    if reduceMotion {
      store.complete(setID: set.id, exerciseID: exercise.id)
    } else {
      withAnimation(.spring(response: DesignTokens.Motion.setCompleteDuration, dampingFraction: 0.7)) {
        store.complete(setID: set.id, exerciseID: exercise.id)
      }
    }
  }

  private func decimal(from text: String) -> Decimal? {
    Decimal(string: text.replacingOccurrences(of: ",", with: "."))
  }
}

private struct FieldStepper: View {
  let text: String
  let isGhost: Bool
  var keyboard: UIKeyboardType = .decimalPad
  var onTextChange: ((String) -> Void)?
  let decrement: () -> Void
  let increment: () -> Void
  var onTap: (() -> Void)?
  var onLongPress: (() -> Void)?
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.step1) {
      Button(action: decrement) {
        Text("−")
          .forgeTextStyle(DesignTokens.Typography.numericRow)
      }
      TextField("", text: Binding(
        get: { text == "–" ? "" : text },
        set: { onTextChange?($0) }
      ))
      .keyboardType(keyboard)
      .multilineTextAlignment(.center)
      .focused($isFocused)
      .placeholder(when: text == "–") {
        Text(text)
          .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      }
      .forgeTextStyle(DesignTokens.Typography.numericRow)
      .forgeNumeric()
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .foregroundStyle(isGhost ? DesignTokens.ColorToken.textTertiary : DesignTokens.ColorToken.textPrimary)
      .frame(maxWidth: .infinity)
      .onTapGesture {
        onTap?()
      }
      .onLongPressGesture {
        onLongPress?()
      }
      Button(action: increment) {
        Text("+")
          .forgeTextStyle(DesignTokens.Typography.numericRow)
      }
    }
    .buttonStyle(.plain)
    .padding(.horizontal, DesignTokens.Spacing.step1)
    .frame(minHeight: DesignTokens.Spacing.setRowHeightVisual)
    .background(DesignTokens.ColorToken.surfaceInput)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.input))
  }
}

private struct RPEChipRow: View {
  let selected: Decimal?
  let select: (Decimal) -> Void
  private let values: [Decimal] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DesignTokens.Spacing.step2) {
        ForEach(values, id: \.self) { value in
          Button {
            select(value)
          } label: {
            Text(format(value))
              .forgeTextStyle(DesignTokens.Typography.numericRow)
              .forgeNumeric()
              .foregroundStyle(value == selected ? DesignTokens.ColorToken.onSignal : DesignTokens.ColorToken.textPrimary)
              .padding(.horizontal, DesignTokens.Spacing.step3)
              .padding(.vertical, DesignTokens.Spacing.step2)
              .background(value == selected ? DesignTokens.ColorToken.signal : DesignTokens.ColorToken.surfaceInput)
              .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.segment))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.screenGutter)
      .padding(.vertical, DesignTokens.Spacing.step2)
    }
  }
}

private struct PlateCalculatorView: View {
  let weightKg: Decimal
  private let barKg: Decimal = 20
  private let plates: [Decimal] = [25, 20, 15, 10, 5, 2.5, 1.25]

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step3) {
      Text("PLATES")
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      Text("\(format(weightKg)) KG")
        .forgeTextStyle(DesignTokens.Typography.heading)
        .forgeNumeric()
      ForEach(plateBreakdown, id: \.plate) { item in
        HStack {
          Text("\(format(item.plate)) KG")
          Spacer()
          Text("× \(item.count)")
            .forgeNumeric()
        }
        .forgeTextStyle(DesignTokens.Typography.numericRow)
      }
    }
    .padding(DesignTokens.Spacing.step4)
    .frame(minWidth: DesignTokens.Spacing.step6 * 5)
    .background(DesignTokens.ColorToken.surfaceRaised)
  }

  private var plateBreakdown: [(plate: Decimal, count: Int)] {
    var side = max(0, (weightKg - barKg) / 2)
    return plates.compactMap { plate in
      let count = NSDecimalNumber(decimal: (side / plate).roundedDown).intValue
      guard count > 0 else { return nil }
      side -= plate * Decimal(count)
      return (plate, count)
    }
  }
}

private extension Decimal {
  var roundedDown: Decimal {
    var value = self
    var result = Decimal()
    NSDecimalRound(&result, &value, 0, .down)
    return result
  }
}

private extension View {
  func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .center, @ViewBuilder placeholder: () -> Content) -> some View {
    ZStack(alignment: alignment) {
      placeholder().opacity(shouldShow ? 1 : 0)
      self
    }
  }
}

private struct CompleteButton: View {
  let isCompleted: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(isCompleted ? "✓" : "○")
        .forgeTextStyle(DesignTokens.Typography.heading)
        .foregroundStyle(isCompleted ? DesignTokens.ColorToken.onSignal : DesignTokens.ColorToken.textTertiary)
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.Spacing.setRowHitTarget)
        .background(isCompleted ? DesignTokens.ColorToken.signal : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.checkbox))
        .overlay(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.checkbox)
            .stroke(isCompleted ? DesignTokens.ColorToken.signal : DesignTokens.ColorToken.hairline)
        )
    }
    .buttonStyle(.plain)
  }
}

private struct PRBadgeRow: View {
  var body: some View {
    HStack {
      Spacer()
      Text("PR")
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.pr)
        .padding(.horizontal, DesignTokens.Spacing.step2)
        .padding(.vertical, DesignTokens.Spacing.step1)
        .background(DesignTokens.ColorToken.prDim)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.segment))
    }
    .padding(.horizontal, DesignTokens.Spacing.screenGutter)
    .padding(.vertical, DesignTokens.Spacing.step1)
  }
}

private struct FinishWorkoutButton: View {
  var body: some View {
    Button {} label: {
      Text("FINISH WORKOUT")
        .forgeTextStyle(DesignTokens.Typography.heading)
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.step3)
        .background(DesignTokens.ColorToken.surfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.input))
    }
    .buttonStyle(.plain)
    .padding(DesignTokens.Spacing.screenGutter)
  }
}

private struct BottomFocusPill: View {
  @Bindable var store: FocusWorkoutStore
  @Binding var showsIndex: Bool
  @Binding var showsProgression: Bool

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.step4) {
      Text("×")
      Button {
        showsProgression = true
      } label: {
        Text("PROG")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
      }
      .buttonStyle(.plain)
      if let rest = store.activeRest {
        Button("+30") {
          store.extendRest()
        }
        .buttonStyle(.plain)
        Text(timerInterval: Date()...rest.endsAt, countsDown: true)
          .forgeTextStyle(DesignTokens.Typography.numericRow)
          .forgeNumeric()
        Button("SKIP") {
          store.skipRest()
        }
        .buttonStyle(.plain)
      } else {
        Button {
          showsIndex = true
        } label: {
          Text("‹ \(store.selectedIndex + 1)/\(store.exercises.count) ›")
            .forgeTextStyle(DesignTokens.Typography.numericRow)
            .forgeNumeric()
        }
        .buttonStyle(.plain)
      }
      Text("↗")
    }
    .forgeTextStyle(DesignTokens.Typography.numericRow)
    .foregroundStyle(DesignTokens.ColorToken.textPrimary)
    .padding(.horizontal, DesignTokens.Spacing.step4)
    .padding(.vertical, DesignTokens.Spacing.step3)
    .background(DesignTokens.ColorToken.surfaceRaised)
    .clipShape(Capsule())
    .overlay(Capsule().stroke(DesignTokens.ColorToken.hairline))
    .shadow(color: DesignTokens.ColorToken.surface.opacity(0.25), radius: DesignTokens.Spacing.step2)
    .padding(.bottom, DesignTokens.Spacing.step5)
  }
}

private struct ProgressionSheet: View {
  let exercise: FocusExercise

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.step4) {
          ruleRows
          ladderRows
        }
        .padding(DesignTokens.Spacing.screenGutter)
      }
      .background(DesignTokens.ColorToken.surface)
      .navigationTitle("Progression")
    }
    .environment(\.font, .system(.body, design: .monospaced))
  }

  private var ruleRows: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      Text("RULE")
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      ProgressionRuleRow(label: "REP RANGE", value: "\(exercise.progressionRule.repRangeLow)–\(exercise.progressionRule.repRangeHigh)")
      ProgressionRuleRow(label: "RPE", value: "≤ \(format(exercise.progressionRule.maxQualifyingRPE))")
      ProgressionRuleRow(label: "SETS / SESSION", value: "≥ \(exercise.progressionRule.qualifyingSetsRequired)")
      ProgressionRuleRow(label: "INCREMENT", value: "+\(format(exercise.progressionRule.incrementKg)) KG")
    }
  }

  private var ladderRows: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step2) {
      Text("LADDER")
        .forgeTextStyle(DesignTokens.Typography.eyebrow)
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
      ForEach(exercise.ladderState.levels) { level in
        LadderLevelRow(level: level, currentLevel: exercise.ladderState.currentLevel)
      }
    }
  }
}

private struct ProgressionRuleRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .forgeTextStyle(DesignTokens.Typography.secondary)
        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      Spacer()
      Text(value)
        .forgeTextStyle(DesignTokens.Typography.numericRow)
        .forgeNumeric()
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
    }
    .padding(.vertical, DesignTokens.Spacing.step2)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(DesignTokens.ColorToken.hairline)
        .frame(height: 1)
    }
  }
}

private struct LadderLevelRow: View {
  let level: LadderLevel
  let currentLevel: LadderLevel

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.step3) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
        Text("\(format(level.weightKg)) KG × \(level.reps)")
          .forgeTextStyle(DesignTokens.Typography.numericRow)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        Text("E1RM \(format(level.estimatedOneRepMaxKg)) KG")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }
      Spacer()
      Text(checkmarks)
        .forgeTextStyle(DesignTokens.Typography.numericRow)
        .foregroundStyle(level.isCompleted ? DesignTokens.ColorToken.signal : DesignTokens.ColorToken.textTertiary)
    }
    .padding(DesignTokens.Spacing.step3)
    .background(level.id == currentLevel.id ? DesignTokens.ColorToken.signalDim : DesignTokens.ColorToken.surfaceRaised)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    .opacity(level.isCompleted ? 0.55 : 1)
  }

  private var checkmarks: String {
    if level.isCompleted {
      return String(repeating: "✓", count: level.requiredSets)
    }
    return String(repeating: "○", count: level.requiredSets)
  }
}

private struct ExerciseIndexSheet: View {
  @Bindable var store: FocusWorkoutStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(store.exercises) { exercise in
        Button {
          store.selectedExerciseID = exercise.id
          dismiss()
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
              Text(exercise.name)
                .forgeTextStyle(DesignTokens.Typography.body)
              Text("\(exercise.completedSets)/\(exercise.plannedSets) SETS · \(format(exercise.volumeKg)) KG")
                .forgeTextStyle(DesignTokens.Typography.eyebrow)
                .forgeNumeric()
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            if exercise.sets.contains(where: \.isPR) {
              Text("PR")
                .forgeTextStyle(DesignTokens.Typography.eyebrow)
                .foregroundStyle(DesignTokens.ColorToken.pr)
            }
          }
        }
      }
      .navigationTitle("Index")
    }
  }
}

private extension SetEntryType {
  var label: String {
    switch self {
    case .warmup: "Warmup"
    case .working: "Working"
    case .drop: "Drop"
    case .failure: "Failure"
    case .bodyweight: "Bodyweight"
    }
  }

  var shortLabel: String {
    switch self {
    case .warmup: "W"
    case .working: "\(rawValue.prefix(1).uppercased())"
    case .drop: "D"
    case .failure: "F"
    case .bodyweight: "BW"
    }
  }
}

private func format(_ value: Decimal) -> String {
  let number = NSDecimalNumber(decimal: value)
  let formatter = NumberFormatter()
  formatter.minimumFractionDigits = 0
  formatter.maximumFractionDigits = 1
  return formatter.string(from: number) ?? number.stringValue
}

#Preview {
  FocusWorkoutView(store: FocusWorkoutStore())
}
