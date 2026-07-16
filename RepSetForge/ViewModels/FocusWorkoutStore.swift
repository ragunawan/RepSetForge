import Foundation
import Observation

struct FocusSet: Identifiable, Equatable {
  let id: UUID
  var index: Int
  var type: SetEntryType
  var weightKg: Decimal?
  var reps: Int?
  var rpe: Decimal?
  var restSeconds: Int
  var completedAt: Date?
  var isPR: Bool
  var touchedFields: Set<Field>

  enum Field: Hashable {
    case weight
    case reps
    case rpe
    case rest
  }

  var isCompleted: Bool { completedAt != nil }
}

struct FocusExercise: Identifiable, Equatable {
  let id: UUID
  var name: String
  var detail: String
  var targetWeightKg: Decimal
  var targetReps: Int
  var targetRPE: Decimal
  var previousBestWeightKg: Decimal
  var previousBestReps: Int
  var oneRepMaxKg: Decimal
  var plannedSets: Int
  var sets: [FocusSet]
  var trend: [Decimal]

  var completedSets: Int {
    sets.filter(\.isCompleted).count
  }

  var volumeKg: Decimal {
    sets.reduce(0) { partial, set in
      guard set.isCompleted, set.type != .warmup, let weight = set.weightKg, let reps = set.reps else {
        return partial
      }
      return partial + weight * Decimal(reps)
    }
  }

  var anyCompleted: Bool {
    sets.contains(where: \.isCompleted)
  }
}

struct RestLedgerEntry: Identifiable, Equatable {
  let id = UUID()
  var startedAt: Date
  var endedAt: Date

  var duration: TimeInterval {
    max(0, endedAt.timeIntervalSince(startedAt))
  }
}

@Observable
final class FocusWorkoutStore {
  var sessionName = "Upper Strength"
  var startedAt: Date
  var exercises: [FocusExercise]
  var selectedExerciseID: FocusExercise.ID
  var chartExpandedByExerciseID: [FocusExercise.ID: Bool] = [:]
  var activeRest: (startedAt: Date, endsAt: Date, total: TimeInterval)?
  var restLedger: [RestLedgerEntry] = []
  var lastCompletedSetID: FocusSet.ID?
  var draftSaveCount = 0

  init(startedAt: Date = .now, exercises: [FocusExercise] = FocusWorkoutStore.sampleExercises()) {
    self.startedAt = startedAt
    self.exercises = exercises
    self.selectedExerciseID = exercises.first?.id ?? UUID()
  }

  var selectedIndex: Int {
    get { exercises.firstIndex { $0.id == selectedExerciseID } ?? 0 }
    set {
      guard exercises.indices.contains(newValue) else { return }
      selectedExerciseID = exercises[newValue].id
    }
  }

  var completedSetCount: Int {
    exercises.reduce(0) { $0 + $1.completedSets }
  }

  var plannedSetCount: Int {
    exercises.reduce(0) { $0 + $1.plannedSets }
  }

  var percentComplete: Int {
    guard plannedSetCount > 0 else { return 0 }
    return Int((Double(completedSetCount) / Double(plannedSetCount) * 100).rounded())
  }

  var completedRestDuration: TimeInterval {
    restLedger.reduce(0) { $0 + $1.duration }
  }

  func workDuration(now: Date = .now) -> TimeInterval {
    max(0, now.timeIntervalSince(startedAt) - completedRestDuration)
  }

  func isChartExpanded(for exercise: FocusExercise) -> Bool {
    chartExpandedByExerciseID[exercise.id] ?? !exercise.anyCompleted
  }

  func setChartExpanded(_ expanded: Bool, for exercise: FocusExercise) {
    chartExpandedByExerciseID[exercise.id] = expanded
  }

  func inheritedWeight(for set: FocusSet, in exercise: FocusExercise) -> Decimal? {
    inheritedValue(for: set, in: exercise, field: \.weightKg, fallback: exercise.targetWeightKg)
  }

  func inheritedReps(for set: FocusSet, in exercise: FocusExercise) -> Int? {
    inheritedValue(for: set, in: exercise, field: \.reps, fallback: exercise.targetReps)
  }

  func inheritedRPE(for set: FocusSet, in exercise: FocusExercise) -> Decimal? {
    inheritedValue(for: set, in: exercise, field: \.rpe, fallback: exercise.targetRPE)
  }

  func inheritedRest(for set: FocusSet, in exercise: FocusExercise) -> Int {
    inheritedValue(for: set, in: exercise, field: \.restSeconds, fallback: set.restSeconds) ?? set.restSeconds
  }

  func displayWeight(for set: FocusSet, in exercise: FocusExercise) -> Decimal? {
    set.weightKg ?? inheritedWeight(for: set, in: exercise)
  }

  func displayReps(for set: FocusSet, in exercise: FocusExercise) -> Int? {
    set.reps ?? inheritedReps(for: set, in: exercise)
  }

  func displayRPE(for set: FocusSet, in exercise: FocusExercise) -> Decimal? {
    set.rpe ?? inheritedRPE(for: set, in: exercise)
  }

  func isGhost(_ field: FocusSet.Field, set: FocusSet) -> Bool {
    !set.isCompleted && !set.touchedFields.contains(field)
  }

  func step(_ field: FocusSet.Field, setID: FocusSet.ID, exerciseID: FocusExercise.ID, direction: Int) {
    mutateSet(setID: setID, exerciseID: exerciseID) { set, exercise in
      set.touchedFields.insert(field)
      switch field {
      case .weight:
        let current = set.weightKg ?? inheritedWeight(for: set, in: exercise) ?? 0
        set.weightKg = max(0, current + Decimal(direction) * 2.5)
      case .reps:
        let current = set.reps ?? inheritedReps(for: set, in: exercise) ?? 0
        set.reps = max(0, current + direction)
      case .rpe:
        let current = set.rpe ?? inheritedRPE(for: set, in: exercise) ?? 7.5
        set.rpe = min(10, max(5, current + Decimal(direction) * 0.5))
      case .rest:
        set.restSeconds = max(0, set.restSeconds + direction * 15)
      }
    }
    persistDraft()
  }

  func applyTarget(to exerciseID: FocusExercise.ID) {
    guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
    let targetWeight = exercises[exerciseIndex].targetWeightKg
    let targetReps = exercises[exerciseIndex].targetReps
    let targetRPE = exercises[exerciseIndex].targetRPE
    for index in exercises[exerciseIndex].sets.indices where !exercises[exerciseIndex].sets[index].isCompleted {
      exercises[exerciseIndex].sets[index].weightKg = targetWeight
      exercises[exerciseIndex].sets[index].reps = targetReps
      exercises[exerciseIndex].sets[index].rpe = targetRPE
      exercises[exerciseIndex].sets[index].touchedFields.formUnion([.weight, .reps, .rpe])
    }
    persistDraft()
  }

  func complete(setID: FocusSet.ID, exerciseID: FocusExercise.ID, now: Date = .now) {
    guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
          let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }

    if exercises[exerciseIndex].sets[setIndex].isCompleted {
      exercises[exerciseIndex].sets[setIndex].completedAt = nil
      exercises[exerciseIndex].sets[setIndex].isPR = false
      persistDraft()
      return
    }

    let wasFirstCompleted = !exercises[exerciseIndex].anyCompleted
    let inheritedWeight = inheritedWeight(for: exercises[exerciseIndex].sets[setIndex], in: exercises[exerciseIndex])
    let inheritedReps = inheritedReps(for: exercises[exerciseIndex].sets[setIndex], in: exercises[exerciseIndex])
    let inheritedRPE = inheritedRPE(for: exercises[exerciseIndex].sets[setIndex], in: exercises[exerciseIndex])

    exercises[exerciseIndex].sets[setIndex].weightKg = exercises[exerciseIndex].sets[setIndex].weightKg ?? inheritedWeight
    exercises[exerciseIndex].sets[setIndex].reps = exercises[exerciseIndex].sets[setIndex].reps ?? inheritedReps
    exercises[exerciseIndex].sets[setIndex].rpe = exercises[exerciseIndex].sets[setIndex].rpe ?? inheritedRPE
    exercises[exerciseIndex].sets[setIndex].touchedFields.formUnion([.weight, .reps, .rpe, .rest])
    exercises[exerciseIndex].sets[setIndex].completedAt = now
    exercises[exerciseIndex].sets[setIndex].isPR = isPersonalRecord(exercises[exerciseIndex].sets[setIndex], exercise: exercises[exerciseIndex])
    lastCompletedSetID = setID

    if wasFirstCompleted {
      chartExpandedByExerciseID[exerciseID] = false
    }
    startRest(duration: TimeInterval(exercises[exerciseIndex].sets[setIndex].restSeconds), now: now)
    appendNextSetIfNeeded(exerciseIndex: exerciseIndex, completedSetIndex: setIndex)
    persistDraft()
  }

  func skipRest(now: Date = .now) {
    guard let activeRest else { return }
    restLedger.append(RestLedgerEntry(startedAt: activeRest.startedAt, endedAt: min(now, activeRest.endsAt)))
    self.activeRest = nil
  }

  private func startRest(duration: TimeInterval, now: Date) {
    if let activeRest {
      restLedger.append(RestLedgerEntry(startedAt: activeRest.startedAt, endedAt: min(now, activeRest.endsAt)))
    }
    activeRest = (startedAt: now, endsAt: now.addingTimeInterval(duration), total: duration)
  }

  private func appendNextSetIfNeeded(exerciseIndex: Int, completedSetIndex: Int) {
    guard completedSetIndex == exercises[exerciseIndex].sets.indices.last else { return }
    let previous = exercises[exerciseIndex].sets[completedSetIndex]
    exercises[exerciseIndex].sets.append(FocusSet(
      id: UUID(),
      index: previous.index + 1,
      type: .working,
      weightKg: nil,
      reps: nil,
      rpe: nil,
      restSeconds: previous.restSeconds,
      completedAt: nil,
      isPR: false,
      touchedFields: []
    ))
    exercises[exerciseIndex].plannedSets = max(exercises[exerciseIndex].plannedSets, exercises[exerciseIndex].sets.count)
  }

  private func isPersonalRecord(_ set: FocusSet, exercise: FocusExercise) -> Bool {
    guard set.type != .warmup, let weight = set.weightKg, let reps = set.reps else { return false }
    return weight > exercise.previousBestWeightKg || (weight == exercise.previousBestWeightKg && reps > exercise.previousBestReps)
  }

  private func inheritedValue<Value>(
    for set: FocusSet,
    in exercise: FocusExercise,
    field: KeyPath<FocusSet, Value?>,
    fallback: Value
  ) -> Value? {
    guard let setIndex = exercise.sets.firstIndex(where: { $0.id == set.id }) else { return fallback }
    let previousSets = exercise.sets[..<setIndex].reversed()
    if let value = previousSets.compactMap({ $0[keyPath: field] }).first {
      return value
    }
    return fallback
  }

  private func inheritedValue<Value>(
    for set: FocusSet,
    in exercise: FocusExercise,
    field: KeyPath<FocusSet, Value>,
    fallback: Value
  ) -> Value? {
    guard let setIndex = exercise.sets.firstIndex(where: { $0.id == set.id }) else { return fallback }
    let previousSets = exercise.sets[..<setIndex].reversed()
    if let value = previousSets.map({ $0[keyPath: field] }).first {
      return value
    }
    return fallback
  }

  private func mutateSet(setID: FocusSet.ID, exerciseID: FocusExercise.ID, mutation: (inout FocusSet, FocusExercise) -> Void) {
    guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
          let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
    let exercise = exercises[exerciseIndex]
    mutation(&exercises[exerciseIndex].sets[setIndex], exercise)
  }

  private func persistDraft() {
    draftSaveCount += 1
  }

  static func sampleExercises() -> [FocusExercise] {
    [
      FocusExercise(
        id: UUID(),
        name: "Bench Press",
        detail: "Chest · Sternal head · Triceps",
        targetWeightKg: 105,
        targetReps: 8,
        targetRPE: 8,
        previousBestWeightKg: 102.5,
        previousBestReps: 8,
        oneRepMaxKg: 128,
        plannedSets: 4,
        sets: [
          FocusSet(id: UUID(), index: 1, type: .warmup, weightKg: 60, reps: 8, rpe: nil, restSeconds: 90, completedAt: nil, isPR: false, touchedFields: [.weight, .reps]),
          FocusSet(id: UUID(), index: 2, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 150, completedAt: nil, isPR: false, touchedFields: []),
          FocusSet(id: UUID(), index: 3, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 150, completedAt: nil, isPR: false, touchedFields: []),
          FocusSet(id: UUID(), index: 4, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 150, completedAt: nil, isPR: false, touchedFields: []),
        ],
        trend: [40, 34, 37, 30, 27, 24, 22, 18, 16]
      ),
      FocusExercise(
        id: UUID(),
        name: "Barbell Row",
        detail: "Back · Lats · Rear delts",
        targetWeightKg: 92.5,
        targetReps: 10,
        targetRPE: 8,
        previousBestWeightKg: 90,
        previousBestReps: 10,
        oneRepMaxKg: 123,
        plannedSets: 3,
        sets: [
          FocusSet(id: UUID(), index: 1, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 120, completedAt: nil, isPR: false, touchedFields: []),
          FocusSet(id: UUID(), index: 2, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 120, completedAt: nil, isPR: false, touchedFields: []),
          FocusSet(id: UUID(), index: 3, type: .working, weightKg: nil, reps: nil, rpe: nil, restSeconds: 120, completedAt: nil, isPR: false, touchedFields: []),
        ],
        trend: [36, 38, 32, 28, 30, 24, 21, 19, 17]
      ),
    ]
  }
}
