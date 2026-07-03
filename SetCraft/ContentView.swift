import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--tab"), args.count > idx + 1 {
            return Int(args[idx + 1]) ?? 0
        }
        return 0
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            QuestDashboardView()
                .tabItem { Label("Quest Board", systemImage: "shield.lefthalf.filled") }
                .tag(0)

            CharacterProgressView()
                .tabItem { Label("Character", systemImage: "person.fill") }
                .tag(1)

            QuestHistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(2)

            AchievementsView()
                .tabItem { Label("Achievements", systemImage: "medal.fill") }
                .tag(3)
        }
        .tint(.questGold)
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.previewContainer)
}
