import SwiftUI

/// "Finish button → confirmation sheet with mini-summary → commit" (dev spec §1).
struct FinishWorkoutConfirmationSheet: View {
    let session: WorkoutSession
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var completedSets: [SetEntry] {
        session.sessionExercises.flatMap(\.setEntries).filter { $0.completedAt != nil }
    }

    private var totalVolume: Decimal {
        completedSets.compactMap(\.volumeKg).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(session.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Text("\(completedSets.count) sets logged · \(Self.formatDecimal(totalVolume)) kg")
                        .font(RepSetForgeTheme.Typography.mono(13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("Finish workout")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RepSetForgeTheme.Colors.signal, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.black)
                    }

                    Button("Keep going") { dismiss() }
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Finish workout?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
