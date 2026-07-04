import Foundation

/// JSON/CSV export of the player's progress — a portable snapshot for backup
/// or external analysis. JSON is also the format `ProgressImportService`
/// reads back in, which is why `ExerciseExport`'s muscle/type fields and
/// `QuestExport.id` are stored as stable raw values rather than display
/// text — everything else (status, muscle/record-type summaries) is
/// informational-only, since derived progression is always recomputed by
/// `ProgressionRebuildService` rather than trusted from the file.
enum ProgressExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"

    var id: String { rawValue }
    var fileExtension: String { self == .json ? "json" : "csv" }
}

struct ProgressExport: Codable {
    struct CharacterSummary: Codable {
        let level: Int
        let totalXP: Int
        let title: String
        let completedQuestCount: Int
        let gold: Int
        let preferredWeightUnit: String
    }

    struct MuscleSummary: Codable {
        let muscleGroup: String
        let level: Int
        let totalXP: Int
    }

    struct SetExport: Codable {
        let setNumber: Int
        let reps: Int
        let weight: Double
        let weightUnit: String
        let distanceMiles: Double
        let durationSeconds: Int
        let completed: Bool
    }

    struct ExerciseExport: Codable {
        let name: String
        /// `MuscleGroup.rawValue` — reconstructed on import via `MuscleGroup(rawValue:)`.
        let primaryMuscle: String
        let secondaryMuscles: [String]
        /// `ExerciseType.rawValue` — reconstructed on import via `ExerciseType(rawValue:)`.
        let exerciseType: String
        let sets: [SetExport]
    }

    struct QuestExport: Codable {
        /// Matches the original `Quest.id` — lets a re-import of the same
        /// file (or a second export containing overlapping history) detect
        /// "already imported" instead of duplicating quests.
        let id: UUID
        let name: String
        let date: Date
        let status: String
        let completedDate: Date?
        let totalXP: Int
        let notes: String
        let perceivedEffort: Int?
        let exercises: [ExerciseExport]
    }

    struct PersonalRecordExport: Codable {
        let exerciseName: String
        let recordType: String
        let value: Double
        let weightUnit: String?
        let achievedDate: Date
    }

    struct AchievementExport: Codable {
        let name: String
        let unlocked: Bool
        let unlockedDate: Date?
    }

    let exportedDate: Date
    let character: CharacterSummary?
    let muscles: [MuscleSummary]
    let quests: [QuestExport]
    let personalRecords: [PersonalRecordExport]
    let achievements: [AchievementExport]
}

enum ProgressExportService {
    static func makeExport(
        character: PlayerCharacter?,
        muscles: [MuscleProgress],
        quests: [Quest],
        personalRecords: [PersonalRecord],
        achievements: [Achievement],
        now: Date = .now
    ) -> ProgressExport {
        let characterSummary: ProgressExport.CharacterSummary? = character.map { character in
            ProgressExport.CharacterSummary(
                level: character.level,
                totalXP: character.totalXP,
                title: character.title,
                completedQuestCount: character.completedQuestCount,
                gold: character.gold,
                preferredWeightUnit: character.preferredWeightUnit.rawValue
            )
        }

        let muscleSummaries: [ProgressExport.MuscleSummary] = muscles.map { muscle in
            ProgressExport.MuscleSummary(
                muscleGroup: muscle.muscleGroup.displayName,
                level: muscle.level,
                totalXP: muscle.totalXP
            )
        }

        let questExports: [ProgressExport.QuestExport] = quests.map(makeQuestExport(_:))

        let personalRecordExports: [ProgressExport.PersonalRecordExport] = personalRecords.map { record in
            ProgressExport.PersonalRecordExport(
                exerciseName: record.exerciseName,
                recordType: record.recordType.displayName,
                value: record.value,
                weightUnit: record.weightUnit?.rawValue,
                achievedDate: record.achievedDate
            )
        }

        let achievementExports: [ProgressExport.AchievementExport] = achievements.map { achievement in
            ProgressExport.AchievementExport(
                name: achievement.name,
                unlocked: achievement.unlocked,
                unlockedDate: achievement.unlockedDate
            )
        }

        return ProgressExport(
            exportedDate: now,
            character: characterSummary,
            muscles: muscleSummaries,
            quests: questExports,
            personalRecords: personalRecordExports,
            achievements: achievementExports
        )
    }

    private static func makeQuestExport(_ quest: Quest) -> ProgressExport.QuestExport {
        ProgressExport.QuestExport(
            id: quest.id,
            name: quest.name,
            date: quest.date,
            status: quest.status.displayName,
            completedDate: quest.completedDate,
            totalXP: quest.totalXP,
            notes: quest.notes,
            perceivedEffort: quest.perceivedEffort,
            exercises: quest.exercises.map(makeExerciseExport(_:))
        )
    }

    private static func makeExerciseExport(_ exercise: Exercise) -> ProgressExport.ExerciseExport {
        let sortedSets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        let setExports: [ProgressExport.SetExport] = sortedSets.map { set in
            ProgressExport.SetExport(
                setNumber: set.setNumber,
                reps: set.reps,
                weight: set.weight,
                weightUnit: set.weightUnit.rawValue,
                distanceMiles: set.distanceMiles,
                durationSeconds: set.durationSeconds,
                completed: set.completed
            )
        }
        return ProgressExport.ExerciseExport(
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle.rawValue,
            secondaryMuscles: exercise.secondaryMuscles.map(\.rawValue),
            exerciseType: exercise.exerciseType.rawValue,
            sets: setExports
        )
    }

    static func json(from export: ProgressExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// One row per logged set — the finest-grained unit that fits a flat
    /// table — with the parent quest/exercise columns repeated per row.
    static func csv(from export: ProgressExport) -> String {
        let dateFormatter = ISO8601DateFormatter()
        var rows: [[String]] = [[
            "Quest Name", "Quest Date", "Status", "Exercise Name", "Primary Muscle",
            "Set Number", "Reps", "Weight", "Weight Unit", "Distance Miles",
            "Duration Seconds", "Completed"
        ]]

        for quest in export.quests {
            for exercise in quest.exercises {
                for set in exercise.sets {
                    rows.append([
                        quest.name,
                        dateFormatter.string(from: quest.date),
                        quest.status,
                        exercise.name,
                        exercise.primaryMuscle,
                        String(set.setNumber),
                        String(set.reps),
                        String(set.weight),
                        set.weightUnit,
                        String(set.distanceMiles),
                        String(set.durationSeconds),
                        set.completed ? "true" : "false"
                    ])
                }
            }
        }

        return rows.map { row in row.map(csvField(_:)).joined(separator: ",") }.joined(separator: "\n")
    }

    /// RFC 4180-style field escaping: quote a field if it contains a comma,
    /// quote, or newline, doubling any internal quotes.
    private static func csvField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
