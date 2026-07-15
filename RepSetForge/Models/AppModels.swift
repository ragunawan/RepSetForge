import Foundation
import SwiftData
import SwiftUI

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }
    var label: String { self == .kilograms ? "kg" : "lb" }

    func displayWeight(fromKilograms kg: Double) -> Double {
        self == .kilograms ? kg : kg * 2.2046226218
    }

    func kilograms(fromDisplayed value: Double) -> Double {
        self == .kilograms ? value : value / 2.2046226218
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, cardio
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, cable, machine, bodyweight, kettlebell, band, cardioMachine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cardioMachine: "Cardio"
        default: rawValue.capitalized
        }
    }
}

enum SetKind: String, Codable, CaseIterable, Identifiable {
    case warmup, working, drop, failure, bodyweight
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var shortTitle: String {
        switch self {
        case .warmup: "W"
        case .working: "S"
        case .drop: "D"
        case .failure: "F"
        case .bodyweight: "BW"
        }
    }
}

enum WorkoutStatus: String, Codable, CaseIterable {
    case active, completed, discarded
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
}

enum ProgressionRuleType: String, Codable, CaseIterable, Identifiable {
    case ladder
    case fiveThreeOne
    case percentageWave
    case rirAutoregulation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ladder: "Double progression"
        case .fiveThreeOne: "5/3/1"
        case .percentageWave: "Percentage wave"
        case .rirAutoregulation: "RIR autoregulation"
        }
    }
}

enum RestoreDecision: Equatable {
    case none
    case silentResume
    case needsResolution(reason: String)
}

struct TrainingMath {
    static func canonicalNameKey(_ name: String) -> String {
        name.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func e1RM(weightKg: Double, reps: Int) -> Double? {
        guard reps > 0, reps <= 12, weightKg > 0 else { return nil }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    static func volumeKg(weightKg: Double, reps: Int, kind: SetKind, latestBodyweightKg: Double?) -> Double {
        guard reps > 0, kind != .warmup else { return 0 }
        let load = kind == .bodyweight ? (latestBodyweightKg ?? weightKg) : weightKg
        return max(0, load) * Double(reps)
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1]
            for (j, cb) in b.enumerated() {
                current.append(ca == cb ? previous[j] : min(previous[j], previous[j + 1], current[j]) + 1)
            }
            previous = current
        }
        return previous[b.count]
    }

    static func namesAreSimilar(_ lhs: String, _ rhs: String) -> Bool {
        let a = canonicalNameKey(lhs)
        let b = canonicalNameKey(rhs)
        guard !a.isEmpty, !b.isEmpty, a != b else { return a == b }
        let at = Set(a.split(separator: " ").map(String.init))
        let bt = Set(b.split(separator: " ").map(String.init))
        return levenshtein(a, b) <= 2 || at.isSubset(of: bt) || bt.isSubset(of: at)
    }
}

@Model final class AppSettings {
    var unitsRaw: String = UnitSystem.kilograms.rawValue
    var defaultRestSeconds: Int = 120
    var showRPE: Bool = true
    var plateStepKg: Double = 2.5
    var barWeightKg: Double = 20
    var themeRaw: String = ThemePreference.system.rawValue
    var autoSaveToHealth: Bool = true
    var updatedAt: Date = Date()

    init() {}

    var units: UnitSystem {
        get { UnitSystem(rawValue: unitsRaw) ?? .kilograms }
        set { unitsRaw = newValue.rawValue; updatedAt = Date() }
    }

    var theme: ThemePreference {
        get { ThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue; updatedAt = Date() }
    }
}

@Model final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    var secondaryMuscleRaws: [String] = []
    var equipmentRaw: String = Equipment.barbell.rawValue
    var isFavorite: Bool = false
    var isCustom: Bool = true
    var pinnedNotes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var canonicalNameKey: String = ""

    init(name: String, primary: MuscleGroup, secondary: [MuscleGroup] = [], equipment: Equipment = .barbell, isFavorite: Bool = false) {
        self.name = name
        self.primaryMuscleRaw = primary.rawValue
        self.secondaryMuscleRaws = secondary.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.isFavorite = isFavorite
        self.canonicalNameKey = TrainingMath.canonicalNameKey(name)
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue; updatedAt = Date() }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMuscleRaws.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMuscleRaws = newValue.map(\.rawValue); updatedAt = Date() }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .barbell }
        set { equipmentRaw = newValue.rawValue; updatedAt = Date() }
    }
}

@Model final class ProgressionRule {
    var id: UUID = UUID()
    var typeRaw: String = ProgressionRuleType.ladder.rawValue
    var repRangeLow: Int = 8
    var repRangeHigh: Int = 12
    var maxQualifyingRPE: Double = 9
    var qualifyingSetsRequired: Int = 2
    var incrementKg: Double = 2.5
    var trainingMaxKg: Double = 100
    var wavePercentages: [Double] = [0.7, 0.8, 0.9]
    var targetRIR: Double = 2
    var rirLoadAdjustmentKg: Double = 2.5
    var updatedAt: Date = Date()

    init(type: ProgressionRuleType = .ladder, repRangeLow: Int = 8, repRangeHigh: Int = 12, maxQualifyingRPE: Double = 9, qualifyingSetsRequired: Int = 2, incrementKg: Double = 2.5) {
        self.typeRaw = type.rawValue
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.maxQualifyingRPE = maxQualifyingRPE
        self.qualifyingSetsRequired = qualifyingSetsRequired
        self.incrementKg = incrementKg
    }

    var type: ProgressionRuleType {
        get { ProgressionRuleType(rawValue: typeRaw) ?? .ladder }
        set { typeRaw = newValue.rawValue; updatedAt = Date() }
    }
}

@Model final class RoutineItem {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var exerciseID: UUID?
    var order: Int = 0
    var groupID: UUID?
    var targetSets: Int = 3
    var targetRepsLow: Int = 8
    var targetRepsHigh: Int = 12
    var targetRPE: Double = 8
    var restSeconds: Int = 120
    var note: String = ""
    @Relationship(deleteRule: .cascade) var progressionRule: ProgressionRule?

    init(exercise: Exercise, order: Int, targetSets: Int = 3) {
        self.exerciseName = exercise.name
        self.exerciseID = exercise.id
        self.order = order
        self.targetSets = targetSets
        self.progressionRule = ProgressionRule()
    }
}

@Model final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var archivedAt: Date?
    var lastPerformedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade) var orderedItems: [RoutineItem]? = []

    init(name: String, items: [RoutineItem] = []) {
        self.name = name
        self.orderedItems = items
    }
}

@Model final class SetEntry {
    var id: UUID = UUID()
    var index: Int = 0
    var typeRaw: String = SetKind.working.rawValue
    var weightKg: Double?
    var reps: Int?
    var rpe: Double?
    var restSeconds: Int = 120
    var completedAt: Date?
    var isPR: Bool = false
    var touchedWeight: Bool = false
    var touchedReps: Bool = false

    init(index: Int, type: SetKind = .working, weightKg: Double? = nil, reps: Int? = nil, restSeconds: Int = 120) {
        self.index = index
        self.typeRaw = type.rawValue
        self.weightKg = weightKg
        self.reps = reps
        self.restSeconds = restSeconds
    }

    var type: SetKind {
        get { SetKind(rawValue: typeRaw) ?? .working }
        set { typeRaw = newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }
}

@Model final class SessionExercise {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var exerciseID: UUID?
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    var muscleDetail: String = ""
    var order: Int = 0
    var groupID: UUID?
    var note: String = ""
    var chartCollapsed: Bool = false
    @Relationship(deleteRule: .cascade) var sets: [SetEntry]? = []
    @Relationship(deleteRule: .cascade) var progressionRule: ProgressionRule?

    init(exercise: Exercise, order: Int, targetSets: Int = 3, restSeconds: Int = 120) {
        self.exerciseName = exercise.name
        self.exerciseID = exercise.id
        self.primaryMuscleRaw = exercise.primaryMuscle.rawValue
        self.muscleDetail = ([exercise.primaryMuscle.title] + exercise.secondaryMuscles.map(\.title)).joined(separator: " · ")
        self.order = order
        self.progressionRule = ProgressionRule()
        self.sets = (0..<targetSets).map { SetEntry(index: $0 + 1, weightKg: nil, reps: nil, restSeconds: restSeconds) }
    }

    var primaryMuscle: MuscleGroup { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
    var completedSets: Int { (sets ?? []).filter(\.isCompleted).count }
    var totalSets: Int { (sets ?? []).count }
}

@Model final class WorkoutSession {
    var id: UUID = UUID()
    var name: String = "Untitled Workout"
    var routineID: UUID?
    var startedAt: Date = Date()
    var endedAt: Date?
    var notes: String = ""
    var statusRaw: String = WorkoutStatus.active.rawValue
    var healthKitUUID: UUID?
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade) var exercises: [SessionExercise]? = []

    init(name: String, routineID: UUID? = nil, exercises: [SessionExercise] = []) {
        self.name = name
        self.routineID = routineID
        self.exercises = exercises
    }

    var status: WorkoutStatus {
        get { WorkoutStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    var completedSetCount: Int { (exercises ?? []).reduce(0) { $0 + $1.completedSets } }
    var plannedSetCount: Int { (exercises ?? []).reduce(0) { $0 + $1.totalSets } }
    var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
}

@Model final class PRRecord {
    var id: UUID = UUID()
    var exerciseNameKey: String = ""
    var exerciseName: String = ""
    var kind: String = ""
    var value: Double = 0
    var setID: UUID?
    var achievedAt: Date = Date()

    init(exerciseName: String, kind: String, value: Double, setID: UUID?, achievedAt: Date) {
        self.exerciseName = exerciseName
        self.exerciseNameKey = TrainingMath.canonicalNameKey(exerciseName)
        self.kind = kind
        self.value = value
        self.setID = setID
        self.achievedAt = achievedAt
    }
}

@Model final class BodyMetric {
    var id: UUID = UUID()
    var date: Date = Date()
    var bodyweightKg: Double = 80
    var bodyFatPct: Double?
    var updatedAt: Date = Date()

    init(date: Date = Date(), bodyweightKg: Double, bodyFatPct: Double? = nil) {
        self.date = date
        self.bodyweightKg = bodyweightKg
        self.bodyFatPct = bodyFatPct
    }
}
