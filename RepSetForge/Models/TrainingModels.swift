import Foundation
import SwiftData

enum SetEntryType: String, Codable, CaseIterable {
  case warmup
  case working
  case drop
  case failure
  case bodyweight
}

enum WorkoutSessionStatus: String, Codable, CaseIterable {
  case active
  case completed
}

enum ProgressionRuleType: String, Codable, CaseIterable {
  case ladder
}

enum PRKind: String, Codable, CaseIterable {
  case bestWeight
  case bestE1RM
  case bestVolume
  case repsAtWeight
}

@Model
final class Exercise {
  var id: UUID = UUID()
  var name: String = ""
  var muscleGroups: [String] = []
  var secondaryMuscles: [String] = []
  var equipment: String?
  var isFavorite: Bool = false
  var isCustom: Bool = true
  var pinnedNotes: String?
  var createdAt: Date = Date.now
  var canonicalNameKey: String = ""
  var routineItems: [RoutineItem]?
  var sessionExercises: [SessionExercise]?
  var prRecords: [PRRecord]?

  init(
    id: UUID = UUID(),
    name: String,
    muscleGroups: [String] = [],
    secondaryMuscles: [String] = [],
    equipment: String? = nil,
    isFavorite: Bool = false,
    isCustom: Bool = true,
    pinnedNotes: String? = nil,
    createdAt: Date = .now,
    canonicalNameKey: String? = nil
  ) {
    self.id = id
    self.name = name
    self.muscleGroups = muscleGroups
    self.secondaryMuscles = secondaryMuscles
    self.equipment = equipment
    self.isFavorite = isFavorite
    self.isCustom = isCustom
    self.pinnedNotes = pinnedNotes
    self.createdAt = createdAt
    self.canonicalNameKey = canonicalNameKey ?? ExerciseDeduplicator.canonicalNameKey(for: name)
  }
}

@Model
final class Routine {
  var id: UUID = UUID()
  var name: String = ""
  @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
  var orderedItems: [RoutineItem]?
  var archivedAt: Date?
  var lastPerformedAt: Date?
  var workoutSessions: [WorkoutSession]?

  init(id: UUID = UUID(), name: String, orderedItems: [RoutineItem] = [], archivedAt: Date? = nil, lastPerformedAt: Date? = nil) {
    self.id = id
    self.name = name
    self.orderedItems = orderedItems
    self.archivedAt = archivedAt
    self.lastPerformedAt = lastPerformedAt
  }
}

@Model
final class RoutineItem {
  var id: UUID = UUID()
  var routine: Routine?
  @Relationship(inverse: \Exercise.routineItems)
  var exercise: Exercise?
  var order: Int = 0
  var groupID: UUID?
  var targetSets: Int = 0
  var targetRepsLow: Int = 0
  var targetRepsHigh: Int = 0
  var targetRPE: Decimal?
  var restSeconds: Int = 120
  var note: String?
  @Relationship(deleteRule: .cascade, inverse: \ProgressionRule.routineItem)
  var progressionRule: ProgressionRule?

  init(
    id: UUID = UUID(),
    routine: Routine? = nil,
    exercise: Exercise? = nil,
    order: Int,
    groupID: UUID? = nil,
    targetSets: Int,
    targetRepsLow: Int,
    targetRepsHigh: Int,
    targetRPE: Decimal? = nil,
    restSeconds: Int = 120,
    note: String? = nil,
    progressionRule: ProgressionRule? = nil
  ) {
    self.id = id
    self.routine = routine
    self.exercise = exercise
    self.order = order
    self.groupID = groupID
    self.targetSets = targetSets
    self.targetRepsLow = targetRepsLow
    self.targetRepsHigh = targetRepsHigh
    self.targetRPE = targetRPE
    self.restSeconds = restSeconds
    self.note = note
    self.progressionRule = progressionRule
  }
}

@Model
final class ProgressionRule {
  var id: UUID = UUID()
  var typeRawValue: String = ProgressionRuleType.ladder.rawValue
  var repRangeLow: Int = 0
  var repRangeHigh: Int = 0
  var maxQualifyingRPE: Decimal = 0
  var qualifyingSetsRequired: Int = 0
  var incrementKg: Decimal = 0
  var routineItem: RoutineItem?

  var type: ProgressionRuleType {
    get { ProgressionRuleType(rawValue: typeRawValue) ?? .ladder }
    set { typeRawValue = newValue.rawValue }
  }

  init(
    id: UUID = UUID(),
    type: ProgressionRuleType = .ladder,
    repRangeLow: Int,
    repRangeHigh: Int,
    maxQualifyingRPE: Decimal,
    qualifyingSetsRequired: Int,
    incrementKg: Decimal
  ) {
    self.id = id
    self.typeRawValue = type.rawValue
    self.repRangeLow = repRangeLow
    self.repRangeHigh = repRangeHigh
    self.maxQualifyingRPE = maxQualifyingRPE
    self.qualifyingSetsRequired = qualifyingSetsRequired
    self.incrementKg = incrementKg
  }
}

@Model
final class WorkoutSession {
  var id: UUID = UUID()
  var name: String = ""
  @Relationship(inverse: \Routine.workoutSessions)
  var routine: Routine?
  var startedAt: Date = Date.now
  var endedAt: Date?
  var notes: String?
  var statusRawValue: String = WorkoutSessionStatus.active.rawValue
  var healthKitUUID: UUID?
  @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
  var exercises: [SessionExercise]?

  var status: WorkoutSessionStatus {
    get { WorkoutSessionStatus(rawValue: statusRawValue) ?? .active }
    set { statusRawValue = newValue.rawValue }
  }

  init(
    id: UUID = UUID(),
    name: String,
    routine: Routine? = nil,
    startedAt: Date = .now,
    endedAt: Date? = nil,
    notes: String? = nil,
    status: WorkoutSessionStatus = .active,
    healthKitUUID: UUID? = nil,
    exercises: [SessionExercise] = []
  ) {
    self.id = id
    self.name = name
    self.routine = routine
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.notes = notes
    self.statusRawValue = status.rawValue
    self.healthKitUUID = healthKitUUID
    self.exercises = exercises
  }
}

@Model
final class SessionExercise {
  var id: UUID = UUID()
  var session: WorkoutSession?
  @Relationship(inverse: \Exercise.sessionExercises)
  var exercise: Exercise?
  var order: Int = 0
  var groupID: UUID?
  var note: String?
  @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
  var sets: [SetEntry]?

  init(
    id: UUID = UUID(),
    session: WorkoutSession? = nil,
    exercise: Exercise? = nil,
    order: Int,
    groupID: UUID? = nil,
    note: String? = nil,
    sets: [SetEntry] = []
  ) {
    self.id = id
    self.session = session
    self.exercise = exercise
    self.order = order
    self.groupID = groupID
    self.note = note
    self.sets = sets
  }
}

@Model
final class SetEntry {
  var id: UUID = UUID()
  var sessionExercise: SessionExercise?
  var index: Int = 0
  var typeRawValue: String = SetEntryType.working.rawValue
  var weightKg: Decimal?
  var reps: Int?
  var rpe: Decimal?
  var completedAt: Date?
  var isPR: Bool = false
  var prRecords: [PRRecord]?

  var type: SetEntryType {
    get { SetEntryType(rawValue: typeRawValue) ?? .working }
    set { typeRawValue = newValue.rawValue }
  }

  var estimatedOneRepMaxKg: Decimal? {
    StrengthMath.estimatedOneRepMax(weightKg: weightKg, reps: reps)
  }

  var volumeKg: Decimal? {
    guard type != .warmup, let reps, reps > 0 else { return nil }
    let load = weightKg ?? 0
    return load * Decimal(reps)
  }

  init(
    id: UUID = UUID(),
    sessionExercise: SessionExercise? = nil,
    index: Int,
    type: SetEntryType = .working,
    weightKg: Decimal? = nil,
    reps: Int? = nil,
    rpe: Decimal? = nil,
    completedAt: Date? = nil,
    isPR: Bool = false
  ) {
    self.id = id
    self.sessionExercise = sessionExercise
    self.index = index
    self.typeRawValue = type.rawValue
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completedAt = completedAt
    self.isPR = isPR
  }
}

@Model
final class PRRecord {
  var id: UUID = UUID()
  @Relationship(inverse: \Exercise.prRecords)
  var exercise: Exercise?
  var kindRawValue: String = PRKind.bestWeight.rawValue
  var value: Decimal = 0
  @Relationship(inverse: \SetEntry.prRecords)
  var set: SetEntry?
  var achievedAt: Date = Date.now

  var kind: PRKind {
    get { PRKind(rawValue: kindRawValue) ?? .bestWeight }
    set { kindRawValue = newValue.rawValue }
  }

  init(id: UUID = UUID(), exercise: Exercise? = nil, kind: PRKind, value: Decimal, set: SetEntry? = nil, achievedAt: Date) {
    self.id = id
    self.exercise = exercise
    self.kindRawValue = kind.rawValue
    self.value = value
    self.set = set
    self.achievedAt = achievedAt
  }
}

@Model
final class BodyMetric {
  var id: UUID = UUID()
  var date: Date = Date.now
  var bodyweightKg: Decimal = 0
  var bodyFatPct: Decimal?

  init(id: UUID = UUID(), date: Date, bodyweightKg: Decimal, bodyFatPct: Decimal? = nil) {
    self.id = id
    self.date = date
    self.bodyweightKg = bodyweightKg
    self.bodyFatPct = bodyFatPct
  }
}

@Model
final class UserProfile {
  var id: UUID = UUID()
  var heightCm: Decimal?

  init(id: UUID = UUID(), heightCm: Decimal? = nil) {
    self.id = id
    self.heightCm = heightCm
  }
}
