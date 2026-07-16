import SwiftUI

/// Phase 0 shell: empty screen rendered entirely with token colors and the
/// app-wide monospaced default. Tabs land in later phases.
struct RootView: View {
    var body: some View {
        ZStack {
            DT.Colors.surface.ignoresSafeArea()
            VStack(spacing: DT.Spacing.s8) {
                Text("REPSETFORGE")
                    .font(DT.Type.eyebrow)
                    .tracking(DT.Type.eyebrowTracking)
                    .foregroundStyle(DT.Colors.textTertiary)
                Text("v1.0")
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
            }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}
