import Foundation
import SwiftData

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var archivedAt: Date?
    var lastPerformedAt: Date?

    // CloudKit requires to-many relationships to be Optional at the stored-property
    // level; `items` exposes a non-optional array to callers (see CLAUDE.md).
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    private var _items: [RoutineItem]? = []
    var items: [RoutineItem] {
        get { _items ?? [] }
        set { _items = newValue }
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
