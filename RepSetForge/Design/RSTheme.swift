import SwiftUI
import UIKit

enum RSTheme {
    static let surface = adaptive(light: UIColor(red: 0.965, green: 0.973, blue: 0.984, alpha: 1),
                                  dark: UIColor(red: 0.051, green: 0.059, blue: 0.071, alpha: 1))
    static let surfaceRaised = adaptive(light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
                                        dark: UIColor(red: 0.110, green: 0.126, blue: 0.153, alpha: 1))
    static let surfaceInput = adaptive(light: UIColor(red: 0.922, green: 0.941, blue: 0.965, alpha: 1),
                                       dark: UIColor(red: 0.153, green: 0.173, blue: 0.204, alpha: 1))
    static let hairline = adaptive(light: UIColor(red: 0.800, green: 0.831, blue: 0.875, alpha: 1),
                                   dark: UIColor(red: 0.247, green: 0.278, blue: 0.325, alpha: 1))
    static let textPrimary = adaptive(light: UIColor(red: 0.071, green: 0.086, blue: 0.110, alpha: 1),
                                      dark: UIColor(red: 0.984, green: 0.988, blue: 0.996, alpha: 1))
    static let textSecondary = adaptive(light: UIColor(red: 0.286, green: 0.337, blue: 0.408, alpha: 1),
                                        dark: UIColor(red: 0.745, green: 0.776, blue: 0.824, alpha: 1))
    static let textTertiary = adaptive(light: UIColor(red: 0.420, green: 0.478, blue: 0.553, alpha: 1),
                                       dark: UIColor(red: 0.620, green: 0.659, blue: 0.722, alpha: 1))
    static let signal = adaptive(light: UIColor(red: 0.000, green: 0.486, blue: 0.298, alpha: 1),
                                 dark: UIColor(red: 0.267, green: 0.961, blue: 0.620, alpha: 1))
    static let pr = adaptive(light: UIColor(red: 0.690, green: 0.443, blue: 0.000, alpha: 1),
                             dark: UIColor(red: 0.961, green: 0.773, blue: 0.259, alpha: 1))
    static let warn = adaptive(light: UIColor(red: 0.780, green: 0.247, blue: 0.118, alpha: 1),
                               dark: UIColor(red: 1.000, green: 0.557, blue: 0.420, alpha: 1))
    static let destructive = adaptive(light: UIColor(red: 0.780, green: 0.121, blue: 0.153, alpha: 1),
                                      dark: UIColor(red: 1.000, green: 0.427, blue: 0.427, alpha: 1))
    static let textOnSignal = Color.black

    static let lightSignal = signal
    static let cardRadius: CGFloat = 10
    static let inputRadius: CGFloat = 8
    static let pillRadius: CGFloat = 22
    static let hairlineWidth: CGFloat = 1
    static let screenPadding: CGFloat = 12

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func adaptiveUIColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: adaptiveUIColor(light: light, dark: dark))
    }
}

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RSTheme.surface.ignoresSafeArea())
            .foregroundStyle(RSTheme.textPrimary)
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }

    func hairlineCard(radius: CGFloat = RSTheme.cardRadius) -> some View {
        padding(10)
            .background(RSTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(RSTheme.hairline))
    }
}

struct RSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, destructive }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RSTheme.mono(14, weight: .bold))
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(background.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var background: Color {
        switch kind {
        case .primary: RSTheme.signal
        case .secondary: RSTheme.surfaceInput
        case .quiet: .clear
        case .destructive: RSTheme.destructive.opacity(0.16)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: RSTheme.textOnSignal
        case .secondary, .quiet: RSTheme.textPrimary
        case .destructive: RSTheme.destructive
        }
    }

    private var border: Color {
        switch kind {
        case .primary: RSTheme.signal
        case .secondary, .quiet: RSTheme.hairline
        case .destructive: RSTheme.destructive
        }
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(RSTheme.mono(10, weight: .bold))
            .tracking(1)
            .foregroundStyle(RSTheme.textTertiary)
    }
}

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .default))
            .foregroundStyle(RSTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct RSChip: View {
    let text: String
    var selected: Bool = false
    var body: some View {
        Text(text)
            .font(RSTheme.mono(12, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(selected ? RSTheme.signal.opacity(0.14) : RSTheme.surfaceInput)
            .foregroundStyle(selected ? RSTheme.signal : RSTheme.textSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? RSTheme.signal : RSTheme.hairline))
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    var tint: Color = RSTheme.textPrimary
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(RSTheme.mono(18, weight: .semibold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(RSTheme.mono(14, weight: .bold))
            Text(message).font(RSTheme.mono(12)).foregroundStyle(RSTheme.textTertiary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(RSButtonStyle(kind: .quiet))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RSTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: RSTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: RSTheme.cardRadius).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundStyle(RSTheme.hairline))
    }
}

struct MiniBarChart: View {
    let values: [Double]
    var tint: Color = RSTheme.signal
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(value == values.max() ? tint : RSTheme.surfaceInput)
                    .frame(height: max(6, CGFloat(value) * 44))
            }
        }
        .frame(height: 48)
        .accessibilityLabel("Bar chart")
    }
}

struct LineTrendChart: View {
    let values: [Double]
    var tint: Color = RSTheme.signal
    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(size: proxy.size)
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .background {
                Rectangle().stroke(RSTheme.hairline)
            }
        }
        .frame(height: 96)
        .accessibilityLabel("Trend chart")
    }

    private func normalizedPoints(size: CGSize) -> [CGPoint] {
        guard values.count > 1, let min = values.min(), let max = values.max(), max > min else { return [] }
        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height - (size.height * CGFloat((value - min) / (max - min)))
            return CGPoint(x: x, y: y)
        }
    }
}
