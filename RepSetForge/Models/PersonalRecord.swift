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

    init(exerciseName: String, recordType: PersonalRecordType, value: Double, achievedDate: Date = .now) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.recordTypeRaw = recordType.rawValue
        self.value = value
        self.achievedDate = achievedDate
    }

    var recordType: PersonalRecordType {
        get { PersonalRecordType(rawValue: recordTypeRaw) ?? .maxWeight }
        set { recordTypeRaw = newValue.rawValue }
    }
}
