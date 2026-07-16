import SwiftUI

/// §3.6 bottom pill: minimize · index · PROG · ‹ n/m › pager · share.
/// While a rest runs, the countdown replaces the pager (§4 semantics:
/// overtime flips to warning and counts up). All ticking is OS-driven.
struct BottomPill: View {
    @Bindable var vm: WorkoutViewModel
    var onMinimize: () -> Void
    var onIndex: () -> Void
    var onProg: () -> Void

    var body: some View {
        HStack(spacing: DT.Spacing.s8 + 2) {
            if vm.restTimer.isResting, let end = vm.restTimer.plannedEnd, let start = vm.restTimer.restStart {
                restContent(start: start, end: end)
            } else {
                pagerContent
            }
        }
        .padding(.horizontal, DT.Spacing.s12 + 2)
        .padding(.vertical, DT.Spacing.s8 + 2)
        .background(DT.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.pill))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.pill).strokeBorder(DT.Colors.hairline))
        .shadow(color: DT.Elevation.raisedShadowColor,
                radius: DT.Elevation.raisedShadowRadius, y: DT.Elevation.raisedShadowY)
    }

    @ViewBuilder
    private func restContent(start: Date, end: Date) -> some View {
        // Countdown; after `end` SwiftUI shows 0:00 — overtime badge below.
        Text(timerInterval: start...end, countsDown: true)
            .font(DT.Type.body.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(DT.Colors.signal)
            .frame(minWidth: 48)
        ProgressView(timerInterval: start...end, countsDown: false, label: {}, currentValueLabel: {})
            .progressViewStyle(.linear)
            .tint(DT.Colors.signal)
        Button("+30s") { vm.restTimer.extend() }
            .font(DT.Type.eyebrow)
            .foregroundStyle(DT.Colors.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(DT.Colors.surfaceInput)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(DT.Colors.hairline))
        Button("Skip") { vm.restTimer.skip() }
            .font(DT.Type.secondary.weight(.semibold))
            .foregroundStyle(DT.Colors.textTertiary)
    }

    @ViewBuilder
    private var pagerContent: some View {
        let count = vm.orderedExercises.count
        Button(action: onMinimize) {
            Image(systemName: "chevron.down")
                .foregroundStyle(DT.Colors.textTertiary)
                .frame(width: 30, height: 30)
        }
        Button(action: onIndex) {
            Image(systemName: "list.bullet")
                .foregroundStyle(DT.Colors.textTertiary)
                .frame(width: 30, height: 30)
        }
        Button("PROG", action: onProg)
            .font(DT.Type.eyebrow)
            .foregroundStyle(DT.Colors.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(DT.Colors.surfaceInput)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(DT.Colors.hairline))
        Spacer()
        HStack(spacing: DT.Spacing.s16) {
            Button("‹") { if vm.page > 0 { vm.page -= 1 } }
                .foregroundStyle(vm.page > 0 ? DT.Colors.textPrimary : DT.Colors.textTertiary)
            Button {
                onIndex()
            } label: {
                Text("\(vm.page + 1) / \(max(count, 1))")
                    .font(DT.Type.secondary.weight(.semibold))
                    .foregroundStyle(DT.Colors.textSecondary)
                    .monospacedDigit()
            }
            Button("›") { if vm.page < count - 1 { vm.page += 1 } }
                .foregroundStyle(vm.page < count - 1 ? DT.Colors.textPrimary : DT.Colors.textTertiary)
        }
        Spacer()
        Image(systemName: "square.and.arrow.up")
            .foregroundStyle(DT.Colors.textTertiary)
    }
}
