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
  var id: UUID
  var name: String
  var muscleGroups: [String]
  var secondaryMuscles: [String]
  var equipment: String?
  var isFavorite: Bool
  var isCustom: Bool
  var pinnedNotes: String?
  var createdAt: Date
  var canonicalNameKey: String

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
  var id: UUID
  var name: String
  @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
  var orderedItems: [RoutineItem]?
  var archivedAt: Date?
  var lastPerformedAt: Date?

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
  var id: UUID
  var routine: Routine?
  var exercise: Exercise?
  var order: Int
  var groupID: UUID?
  var targetSets: Int
  var targetRepsLow: Int
  var targetRepsHigh: Int
  var targetRPE: Decimal?
  var restSeconds: Int
  var note: String?
  @Relationship(deleteRule: .cascade)
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
  var id: UUID
  var typeRawValue: String
  var repRangeLow: Int
  var repRangeHigh: Int
  var maxQualifyingRPE: Decimal
  var qualifyingSetsRequired: Int
  var incrementKg: Decimal

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
  var id: UUID
  var name: String
  var routine: Routine?
  var startedAt: Date
  var endedAt: Date?
  var notes: String?
  var statusRawValue: String
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
  var id: UUID
  var session: WorkoutSession?
  var exercise: Exercise?
  var order: Int
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
  var id: UUID
  var sessionExercise: SessionExercise?
  var index: Int
  var typeRawValue: String
  var weightKg: Decimal?
  var reps: Int?
  var rpe: Decimal?
  var completedAt: Date?
  var isPR: Bool

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
  var id: UUID
  var exercise: Exercise?
  var kindRawValue: String
  var value: Decimal
  var set: SetEntry?
  var achievedAt: Date

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
  var id: UUID
  var date: Date
  var bodyweightKg: Decimal
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
  var id: UUID
  var heightCm: Decimal?

  init(id: UUID = UUID(), heightCm: Decimal? = nil) {
    self.id = id
    self.heightCm = heightCm
  }
}
