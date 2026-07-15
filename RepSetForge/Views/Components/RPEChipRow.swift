import SwiftUI

/// Horizontal RPE selector — tap a chip to set the set's RPE (dev spec §3 item 5).
struct RPEChipRow: View {
    static let values: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    let selected: Double?
    let onSelect: (Double) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.values, id: \.self) { value in
                    Button {
                        onSelect(value)
                    } label: {
                        Text(Self.label(for: value))
                            .font(RepSetForgeTheme.Typography.mono(12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                value == selected ? RepSetForgeTheme.Colors.signalDim : RepSetForgeTheme.Colors.surfaceInput,
                                in: Capsule()
                            )
                            .foregroundStyle(value == selected ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static func label(for value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
