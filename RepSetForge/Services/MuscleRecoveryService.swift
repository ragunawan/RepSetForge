import Foundation

/// How ready a muscle group reads as being for its next session, based on
/// how recently it was last worked (primary or secondary) — a simple stand-in
/// for the common ~48-72 hour strength-training recovery window.
enum RecoveryStatus: String {
    case untrained = "Untrained"
    case fatigued = "Fatigued"
    case recovering = "Recovering"
    case fresh = "Fresh"
}

/// One muscle group's recent-load/recovery snapshot — purely derived from
/// completed-quest history, no persisted state of its own.
struct MuscleLoadStat: Identifiable {
    var id: MuscleGroup { muscleGroup }
    let muscleGroup: MuscleGroup
    /// XP-equivalent training load attributed to this muscle within the
    /// lookback window (primary exercises count fully, secondary at a reduced
    /// share — mirroring `ProgressionService.distributeXP`'s split).
    let recentLoad: Int
    /// Days since this muscle was last worked, across all history (not just
    /// the lookback window) — nil if it's never been trained at all.
    let daysSinceLastTrained: Int?
    let status: RecoveryStatus
}

enum MuscleRecoveryService {
    static let lookbackDays = 7
    /// Secondary-muscle share of an exercise's XP, matching `ProgressionService.distributeXP`.
    static let secondaryShare = 0.4
    /// Days since last trained at/below which a muscle still reads as fatigued from that session.
    static let fatiguedThresholdDays = 1
    /// Days since last trained at/below which a muscle reads as still recovering (not yet fatigued, not yet fully fresh).
    static let recoveringThresholdDays = 3

    static func loadStats(from quests: [Quest], calendar: Calendar = .current, now: Date = .now) -> [MuscleLoadStat] {
        let completed = quests.filter { $0.status == .completed && $0.completedDate != nil }
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now)

        var recentLoad: [MuscleGroup: Double] = [:]
        var lastTrained: [MuscleGroup: Date] = [:]

        for quest in completed {
            guard let date = quest.completedDate else { continue }
            for exercise in quest.exercises {
                let xp = ProgressionService.exerciseXP(exercise)
                guard xp > 0 else { continue }

                func touch(_ group: MuscleGroup, share: Double) {
                    if let cutoff, date >= cutoff {
                        recentLoad[group, default: 0] += Double(xp) * share
                    }
                    if lastTrained[group].map({ date > $0 }) ?? true {
                        lastTrained[group] = date
                    }
                }

                touch(exercise.primaryMuscle, share: 1.0)
                for secondary in exercise.secondaryMuscles {
                    touch(secondary, share: secondaryShare)
                }
            }
        }

        return MuscleGroup.allCases.map { group in
            let daysSince = lastTrained[group].map { lastDate in
                calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: now)).day ?? 0
            }
            return MuscleLoadStat(
                muscleGroup: group,
                recentLoad: Int(recentLoad[group]?.rounded() ?? 0),
                daysSinceLastTrained: daysSince,
                status: status(forDaysSinceLastTrained: daysSince)
            )
        }
    }

    static func status(forDaysSinceLastTrained days: Int?) -> RecoveryStatus {
        guard let days else { return .untrained }
        if days <= fatiguedThresholdDays { return .fatigued }
        if days <= recoveringThresholdDays { return .recovering }
        return .fresh
    }
}
