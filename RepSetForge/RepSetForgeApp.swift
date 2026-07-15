import SwiftData
import SwiftUI
import UIKit

@main
struct RepSetForgeApp: App {
    private let container = PersistenceController.makeContainer()
    @StateObject private var store = AppStore()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
                .task { await bootstrap() }
        }
    }

    private var preferredScheme: ColorScheme? {
        nil
    }

    @MainActor private func bootstrap() async {
        let context = container.mainContext
        if CommandLine.arguments.contains("--reset-demo-data") {
            PersistenceController.resetAll(context: context)
        } else {
            PersistenceController.ensureDefaults(context: context)
        }
        if CommandLine.arguments.contains("--demo-data") {
            PersistenceController.seedDemoData(context: context)
        }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        store.restoreIfNeeded(from: sessions)
    }

    private func configureAppearance() {
        let titleColor = RSTheme.adaptiveUIColor(
            light: UIColor(red: 0.071, green: 0.086, blue: 0.110, alpha: 1),
            dark: UIColor(red: 0.984, green: 0.988, blue: 0.996, alpha: 1)
        )
        let secondaryColor = RSTheme.adaptiveUIColor(
            light: UIColor(red: 0.286, green: 0.337, blue: 0.408, alpha: 1),
            dark: UIColor(red: 0.745, green: 0.776, blue: 0.824, alpha: 1)
        )
        let backgroundColor = RSTheme.adaptiveUIColor(
            light: UIColor(red: 0.965, green: 0.973, blue: 0.984, alpha: 1),
            dark: UIColor(red: 0.051, green: 0.059, blue: 0.071, alpha: 1)
        )

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = backgroundColor
        nav.titleTextAttributes = [.foregroundColor: titleColor]
        nav.largeTitleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = titleColor

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = backgroundColor.withAlphaComponent(0.92)
        tab.stackedLayoutAppearance.normal.iconColor = secondaryColor
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UITableView.appearance().backgroundColor = backgroundColor
        UICollectionView.appearance().backgroundColor = backgroundColor
    }
}
