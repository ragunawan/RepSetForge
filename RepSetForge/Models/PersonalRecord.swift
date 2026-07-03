import Foundation
import SwiftData

/// The best-ever value logged for a given exercise name and record type
/// (e.g. "Bench Press" max weight). One record per (exerciseName, recordType)
/// pair, kept up to date by PersonalRecordService rather than duplicated.
@Model
final class PersonalRecord {
    var id: UUID
    var exerciseName: String
    var recordTypeRaw: String
    var value: Double
    var achievedDate: Date
    /// Unit `value` is expressed in, for weight-based record types
    /// (maxWeight, bestVolume). Nil for reps/duration/pace records, which
    /// carry no weight unit.
    var weightUnitRaw: String?

    init(
        exerciseName: String,
        recordType: PersonalRecordType,
        value: Double,
        weightUnit: WeightUnit? = nil,
        achievedDate: Date = .now
    ) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.recordTypeRaw = recordType.rawValue
        self.value = value
        self.weightUnitRaw = weightUnit?.rawValue
        self.achievedDate = achievedDate
    }

    var recordType: PersonalRecordType {
        get { PersonalRecordType(rawValue: recordTypeRaw) ?? .maxWeight }
        set { recordTypeRaw = newValue.rawValue }
    }

    var weightUnit: WeightUnit? {
        get { weightUnitRaw.flatMap(WeightUnit.init(rawValue:)) }
        set { weightUnitRaw = newValue?.rawValue }
    }
}
