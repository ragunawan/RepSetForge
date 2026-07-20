import Foundation
import SwiftData

// Data model per spec §2. CloudKit constraints (risk register #1): every
// relationship optional, no @Attribute(.unique), every stored property has a
// default or is optional. Derived data (PRRecord, ladder state, rollups) is
// never authoritative — always rebuildable from SetEntry.

enum SetType: String, Codable, CaseIterable {
    case warmup, working, drop, failure, bodyweight
}

enum SessionStatus: String, Codable {
    case active, completed
}

enum PRKind: String, Codable, CaseIterable {
    case bestWeight, bestE1RM, bestVolume, repsAtWeight
}

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroups: [String] = []
    var secondaryMuscles: [String] = []
    var equipment: String = ""
    var isFavorite: Bool = false
    var isCustom: Bool = false
    var pinnedNotes: String = ""
    var createdAt: Date = Date.now
    /// Lowercased, punctuation-stripped name for dedup (§2).
    var canonicalNameKey: String = ""

    init(name: String, muscleGroups: [String] = [], secondaryMuscles: [String] = [],
         equipment: String = "", isCustom: Bool = false) {
        self.id = UUID()
        self.name = name
        self.muscleGroups = muscleGroups
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCustom = isCustom
        self.createdAt = .now
        self.canonicalNameKey = StrengthMath.canonicalNameKey(name)
    }
}

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var orderedItems: [RoutineItem]? = []
    var archivedAt: Date?
    var lastPerformedAt: Date?

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

@Model
final class RoutineItem {
    var routine: Routine?
    var exercise: Exercise?
    var order: Int = 0
    /// Non-nil groups adjacent items into a superset/circuit.
    var groupID: UUID?
    var targetSets: Int = 3
    var targetRepsLow: Int = 8
    var targetRepsHigh: Int = 12
    var targetRPE: Double?
    var restSeconds: Int = 120
    var note: String = ""
    @Relationship(deleteRule: .cascade, inverse: \ProgressionRule.routineItem)
    var progressionRule: ProgressionRule?

    init(exercise: Exercise? = nil, order: Int = 0) {
        self.exercise = exercise
        self.order = order
    }
}

@Model
final class ProgressionRule {
    var routineItem: RoutineItem?
    var typeRaw: String = "ladder"
    var repRangeLow: Int = 8
    var repRangeHigh: Int = 12
    var maxQualifyingRPE: Double = 8
    var qualifyingSetsRequired: Int = 3
    var incrementKg: Decimal = 2.5

    init() {}
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var name: String = ""
    var routine: Routine?
    var startedAt: Date = Date.now
    var endedAt: Date?
    var notes: String = ""
    var statusRaw: String = SessionStatus.active.rawValue
    /// §4b guard: the saved HKWorkout's uuid. Edits update, deletes propagate.
    var healthKitUUID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(name: String, routine: Routine? = nil, startedAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.routine = routine
        self.startedAt = startedAt
    }
}

@Model
final class SessionExercise {
    var session: WorkoutSession?
    var exercise: Exercise?
    var order: Int = 0
    var groupID: UUID?
    var note: String = ""
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry]? = []

    init(exercise: Exercise? = nil, order: Int = 0) {
        self.exercise = exercise
        self.order = order
    }
}

@Model
final class SetEntry {
    var id: UUID = UUID()
    var sessionExercise: SessionExercise?
    var index: Int = 0
    var typeRaw: String = SetType.working.rawValue
    var weightKg: Decimal?
    var reps: Int?
    var rpe: Double?
    var completedAt: Date?
    /// Denormalized; owned by PRRebuilder, never edited directly.
    var isPR: Bool = false

    var type: SetType {
        get { SetType(rawValue: typeRaw) ?? .working }
        set { typeRaw = newValue.rawValue }
    }

    /// Epley e1RM, valid for reps ≤ 12 (§2); nil otherwise.
    var e1RM: Decimal? {
        guard let w = weightKg, let r = reps else { return nil }
        return StrengthMath.epleyE1RM(weightKg: w, reps: r)
    }

    init(index: Int, type: SetType = .working) {
        self.id = UUID()
        self.index = index
        self.typeRaw = type.rawValue
    }
}

@Model
final class PRRecord {
    var exercise: Exercise?
    var kindRaw: String = PRKind.bestWeight.rawValue
    var value: Decimal = 0
    var setEntry: SetEntry?
    var achievedAt: Date = Date.now

    var kind: PRKind {
        get { PRKind(rawValue: kindRaw) ?? .bestWeight }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: PRKind, value: Decimal, achievedAt: Date) {
        self.kindRaw = kind.rawValue
        self.value = value
        self.achievedAt = achievedAt
    }
}

@Model
final class BodyMetric {
    var date: Date = Date.now
    var bodyweightKg: Decimal?
    /// §5 Home Body module; HealthKit bodyFatPercentage or manual fallback.
    var bodyFatPct: Double?

    init(date: Date, bodyweightKg: Decimal? = nil, bodyFatPct: Double? = nil) {
        self.date = date
        self.bodyweightKg = bodyweightKg
        self.bodyFatPct = bodyFatPct
    }
}

@Model
final class UserProfile {
    var heightCm: Double?
    var unitIsMetric: Bool = true
    var defaultRestSeconds: Int = 120
    var showRPE: Bool = true
    var barWeightKg: Decimal = 20
    /// Plate calculator inventory (per-side denominations, kg).
    var availablePlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    init() {}
}
