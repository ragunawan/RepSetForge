import SwiftUI

/// Minimal stand-in for the `RootView` architecture in dev spec §1 — the
/// TabView shell exists, but Home/History/Progress/Library and the FAB's
/// StartWorkoutSheet are all still TODO.md build-order work.
struct ContentView: View {
    private enum Tab: Hashable {
        case home, history, progress, library
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomePlaceholderView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                HistoryPlaceholderView()
                    .tabItem { Label("History", systemImage: "list.bullet") }
                    .tag(Tab.history)

                ProgressPlaceholderView()
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(Tab.progress)

                LibraryPlaceholderView()
                    .tabItem { Label("Library", systemImage: "square.stack.3d.up.fill") }
                    .tag(Tab.library)
            }

            StartWorkoutFAB()
                .padding(.bottom, 50)
        }
    }
}

private struct StartWorkoutFAB: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "play.fill")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(RepSetForgeTheme.Colors.signal, in: Circle())
        }
        .disabled(true)
        .opacity(0.4)
        .accessibilityLabel("Start workout — coming soon")
    }
}

private struct HomePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Home",
                systemImage: "house",
                description: Text("The Home screen (dev spec §5, mockup frame 1) hasn't been built yet.")
            )
            .navigationTitle("Home")
        }
    }
}

private struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "History",
                systemImage: "list.bullet",
                description: Text("The History screen (dev spec §5, mockup frame 7) hasn't been built yet.")
            )
            .navigationTitle("History")
        }
    }
}

private struct ProgressPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("The Progress screen (dev spec §5, mockup frame 8) hasn't been built yet.")
            )
            .navigationTitle("Progress")
        }
    }
}

private struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Library",
                systemImage: "square.stack.3d.up",
                description: Text("The Routine Library screen (dev spec §5, mockup frame 5) hasn't been built yet.")
            )
            .navigationTitle("Library")
        }
    }
}

#Preview {
    ContentView()
}
