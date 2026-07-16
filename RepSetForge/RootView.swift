import SwiftUI

struct RootView: View {
  var body: some View {
    ZStack {
      DesignTokens.ColorToken.surface
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardGap) {
        Text("RepSetForge")
          .forgeTextStyle(DesignTokens.Typography.largeTitle)
          .foregroundStyle(DesignTokens.ColorToken.textPrimary)

        Text("Phase 0")
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
          .foregroundStyle(DesignTokens.ColorToken.textSecondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(DesignTokens.Spacing.screenGutter)
    }
    .environment(\.font, .system(.body, design: .monospaced))
  }
}

#Preview("Light") {
  RootView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .preferredColorScheme(.dark)
}
