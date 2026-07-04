import Foundation
import SwiftData

enum ProgressImportError: Error, LocalizedError {
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidData: return "That file doesn't look like a RepSetForge export."
        }
    }
}

struct ProgressImportResult {
    let importedQuestCount: Int
    let skippedDuplicateQuestCount: Int
}

/// Imports a previously-exported JSON file back into the current save.
/// Conflict handling: quests are matched by their original `Quest.id`
/// (stable across export/import), so re-importing the same file — or a
/// second export whose history overlaps an earlier one — skips whatever's
/// already present instead of duplicating it. Only new quests are inserted;
/// every derived stat (character/muscle XP and levels, gold, achievements,
/// personal records) is then recomputed from scratch by
/// `ProgressionRebuildService`, the same "rebuild from history" approach
/// the rest of the app already uses, rather than trying to merge scalar
/// counters or previously-computed records field by field.
enum ProgressImportService {
    static func importExport(from data: Data, context: ModelContext) throws -> ProgressImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export: ProgressExport
        do {
            export = try decoder.decode(ProgressExport.self, from: data)
        } catch {
            throw ProgressImportError.invalidData
        }

        let existingQuestIDs = Set((try? context.fetch(FetchDescriptor<Quest>()))?.map(\.id) ?? [])

        var importedCount = 0
        var skippedCount = 0

        for questExport in export.quests {
            guard !existingQuestIDs.contains(questExport.id) else {
                skippedCount += 1
                continue
            }
            context.insert(makeQuest(from: questExport))
            importedCount += 1
        }

        if importedCount > 0 {
            ProgressionRebuildService.rebuild(context: context)
        }

        return ProgressImportResult(importedQuestCount: importedCount, skippedDuplicateQuestCount: skippedCount)
    }

    private static func makeQuest(from export: ProgressExport.QuestExport) -> Quest {
        let status: QuestStatus = export.completedDate != nil
            ? .completed
            : QuestScheduler.status(for: export.date)
        let quest = Quest(name: export.name, date: export.date, status: status)
        quest.id = export.id
        quest.completedDate = export.completedDate
        quest.notes = export.notes
        quest.perceivedEffort = export.perceivedEffort
        quest.exercises = export.exercises.map(makeExercise(from:))
        return quest
    }

    private static func makeExercise(from export: ProgressExport.ExerciseExport) -> Exercise {
        let exercise = Exercise(
            name: export.name,
            primaryMuscle: MuscleGroup(rawValue: export.primaryMuscle) ?? .chest,
            secondaryMuscles: export.secondaryMuscles.compactMap(MuscleGroup.init(rawValue:)),
            exerciseType: ExerciseType(rawValue: export.exerciseType) ?? .strength
        )
        exercise.sets = export.sets.map(makeSet(from:))
        return exercise
    }

    private static func makeSet(from export: ProgressExport.SetExport) -> ExerciseSet {
        ExerciseSet(
            setNumber: export.setNumber,
            reps: export.reps,
            weight: export.weight,
            completed: export.completed,
            distanceMiles: export.distanceMiles,
            durationSeconds: export.durationSeconds,
            weightUnit: WeightUnit(rawValue: export.weightUnit) ?? .pounds
        )
    }
}
