import Foundation
import SwiftData

/// Detects and stores new personal bests (max weight, max reps, best volume,
/// longest duration, fastest pace) as completed sets are logged, matched by
/// exercise name. Each exercise type only yields the record types that make
/// sense for it: strength → maxWeight/maxReps/bestVolume, bodyweight/assisted
/// → maxReps, duration → longestDuration, cardio → fastestPace (needs both
/// distance and duration, which only `.cardio` tracks).
enum PersonalRecordService {
    struct Update {
        let exerciseName: String
        let recordType: PersonalRecordType
        let oldValue: Double?
        let newValue: Double
    }

    private struct Key: Hashable {
        let name: String
        let type: PersonalRecordType
    }

    /// Evaluates the given exercises' completed sets against existing
    /// records, creating or updating a PersonalRecord for any new best.
    /// Returns just the records that were newly set or broken.
    @discardableResult
    static func evaluateRecords(for exercises: [Exercise], context: ModelContext, achievedDate: Date = .now) -> [Update] {
        var updates: [Update] = []
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        var byKey = Dictionary(
            uniqueKeysWithValues: existing.map { (Key(name: $0.exerciseName.lowercased(), type: $0.recordType), $0) }
        )

        func consider(name: String, type: PersonalRecordType, value: Double) {
            guard value > 0 else { return }
            let key = Key(name: name.lowercased(), type: type)
            if let record = byKey[key] {
                let improved = type.lowerIsBetter ? value < record.value : value > record.value
                guard improved else { return }
                let old = record.value
                record.value = value
                record.achievedDate = achievedDate
                updates.append(Update(exerciseName: name, recordType: type, oldValue: old, newValue: value))
            } else {
                let record = PersonalRecord(exerciseName: name, recordType: type, value: value, achievedDate: achievedDate)
                context.insert(record)
                byKey[key] = record
                updates.append(Update(exerciseName: name, recordType: type, oldValue: nil, newValue: value))
            }
        }

        for exercise in exercises {
            for set in exercise.completedSets {
                switch exercise.exerciseType {
                case .strength:
                    consider(name: exercise.name, type: .maxWeight, value: set.weight)
                    consider(name: exercise.name, type: .maxReps, value: Double(set.reps))
                    consider(name: exercise.name, type: .bestVolume, value: Double(set.reps) * set.weight)
                case .bodyweight, .assisted:
                    consider(name: exercise.name, type: .maxReps, value: Double(set.reps))
                case .duration:
                    consider(name: exercise.name, type: .longestDuration, value: Double(set.durationSeconds))
                case .distance:
                    break
                case .cardio:
                    guard set.distanceMiles > 0, set.durationSeconds > 0 else { continue }
                    let paceMinutesPerMile = (Double(set.durationSeconds) / 60) / set.distanceMiles
                    consider(name: exercise.name, type: .fastestPace, value: paceMinutesPerMile)
                }
            }
        }

        return updates
    }

    /// Recomputes every personal record from scratch by replaying all
    /// completed quests in chronological order, so undoing or editing a
    /// completed quest never leaves a stale or duplicated record behind.
    static func rebuildAll(context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] {
            context.delete(record)
        }

        let completedRaw = QuestStatus.completed.rawValue
        let predicate = #Predicate<Quest> { $0.statusRaw == completedRaw }
        let completedQuests = ((try? context.fetch(FetchDescriptor(predicate: predicate))) ?? [])
            .sorted { ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast) }

        for quest in completedQuests {
            evaluateRecords(for: quest.exercises, context: context, achievedDate: quest.completedDate ?? .now)
        }
    }
}
