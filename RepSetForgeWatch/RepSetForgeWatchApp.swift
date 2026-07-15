import SwiftUI

@main
struct RepSetForgeWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            WatchNowView()
                .tag(0)
            WatchRestView()
                .tag(1)
            WatchVitalsView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .containerBackground(.black, for: .navigation)
    }
}

struct WatchNowView: View {
    @State private var completed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WatchLabel("NOW")
            Text("BENCH PRESS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .lineLimit(1)
            Text("SET 1/3")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("135KG × 8")
                .font(.system(size: 27, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
            Text("@8 RPE · PREV 100×8")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
                completed = true
            } label: {
                Label(completed ? "Completed" : "Complete", systemImage: "checkmark")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(completed)
        }
        .padding(.horizontal, 6)
    }
}

struct WatchRestView: View {
    @State private var remainingSeconds = 94

    var body: some View {
        VStack(spacing: 8) {
            WatchLabel("REST")
            Text(restText)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.green)
            Text("OF 2:30 · NEXT SET 2/3")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            ProgressView(value: 0.38)
                .tint(.green)
            HStack {
                Button("+30") { remainingSeconds += 30 }
                Button("Skip") { remainingSeconds = 0 }
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 6)
    }

    private var restText: String {
        "\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))"
    }
}

struct WatchVitalsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WatchLabel("VITALS")
            WatchMetricRow(label: "HEART", value: "118 BPM")
            WatchMetricRow(label: "ENERGY", value: "328 KCAL")
            WatchMetricRow(label: "ELAPSED", value: "00:52")
            WatchMetricRow(label: "SETS", value: "6/14")
            WatchMetricRow(label: "VOLUME", value: "3280 KG")
        }
        .padding(.horizontal, 6)
    }
}

struct WatchLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

struct WatchMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
    }
}
