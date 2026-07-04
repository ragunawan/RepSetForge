import Foundation

/// Lightweight analysis of the player's muscle-group XP distribution:
/// push/pull balance and which muscle group has fallen behind the rest.
/// Purely derived, read-only — no persisted state of its own.
enum TrainingInsightsService {
    struct Insight: Identifiable {
        let id = UUID()
        let iconName: String
        let title: String
        let detail: String
    }

    /// A push/pull training is flagged as imbalanced once one side holds at
    /// least this share of combined push+pull XP.
    static let imbalanceThreshold = 0.65
    /// A muscle group reads as "neglected" once its XP falls below this
    /// fraction of the average across all groups.
    static let neglectedThreshold = 0.3

    static func insights(for muscles: [MuscleProgress]) -> [Insight] {
        let totalXP = muscles.reduce(0) { $0 + $1.totalXP }
        guard totalXP > 0 else { return [] }

        var results: [Insight] = []
        if let balance = pushPullInsight(muscles: muscles) {
            results.append(balance)
        }
        if let neglected = neglectedInsight(muscles: muscles) {
            results.append(neglected)
        }
        return results
    }

    /// Arms contribute to both push (triceps) and pull (biceps) work, so its
    /// XP is split evenly between the two sides rather than picking one.
    private static func pushPullInsight(muscles: [MuscleProgress]) -> Insight? {
        func xp(_ group: MuscleGroup) -> Double {
            Double(muscles.first { $0.muscleGroup == group }?.totalXP ?? 0)
        }

        let armsXP = xp(.arms)
        let pushXP = xp(.chest) + xp(.shoulders) + armsXP * 0.5
        let pullXP = xp(.back) + armsXP * 0.5
        let total = pushXP + pullXP
        guard total > 0 else { return nil }

        let pushShare = pushXP / total
        let pullShare = pullXP / total
        let pushPercent = Int((pushShare * 100).rounded())
        let pullPercent = Int((pullShare * 100).rounded())

        if pushShare >= imbalanceThreshold {
            return Insight(
                iconName: "arrow.left.arrow.right",
                title: "Push/Pull Balance",
                detail: "Push-heavy: \(pushPercent)% push vs \(pullPercent)% pull. Add more back rows or pull-ups to balance out."
            )
        } else if pullShare >= imbalanceThreshold {
            return Insight(
                iconName: "arrow.left.arrow.right",
                title: "Push/Pull Balance",
                detail: "Pull-heavy: \(pullPercent)% pull vs \(pushPercent)% push. Add more presses or push-ups to balance out."
            )
        } else {
            return Insight(
                iconName: "arrow.left.arrow.right",
                title: "Push/Pull Balance",
                detail: "Well balanced: \(pushPercent)% push, \(pullPercent)% pull."
            )
        }
    }

    /// Only flags a group once training has actually started elsewhere, so a
    /// brand-new character isn't immediately told every group is "neglected."
    private static func neglectedInsight(muscles: [MuscleProgress]) -> Insight? {
        guard !muscles.isEmpty, let weakest = muscles.min(by: { $0.totalXP < $1.totalXP }) else { return nil }
        let totalXP = muscles.reduce(0) { $0 + $1.totalXP }
        let average = Double(totalXP) / Double(muscles.count)
        guard average > 0, Double(weakest.totalXP) < average * neglectedThreshold else { return nil }

        return Insight(
            iconName: "exclamationmark.triangle.fill",
            title: "Neglected Muscle Group",
            detail: "\(weakest.muscleGroup.displayName) has the least XP of any group — give it some attention."
        )
    }
}
