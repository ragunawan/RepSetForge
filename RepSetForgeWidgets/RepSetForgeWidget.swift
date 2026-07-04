import SwiftUI
import WidgetKit

struct RepSetForgeWidget: Widget {
    let kind = "RepSetForgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RepSetForgeWidgetProvider()) { entry in
            RepSetForgeWidgetView(entry: entry)
        }
        .configurationDisplayName("RepSetForge")
        .description("Your streak, active quest, and current level.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
