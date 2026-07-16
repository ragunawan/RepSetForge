import AppIntents
import Foundation

/// LiveActivityIntents (§4): run in-process in the app — no launch. They act
/// through RestIntentBridge, which the app wires to the live RestTimerManager.
/// Compiled into BOTH targets so the widget can reference the intent types.
@MainActor
final class RestIntentBridge {
    static let shared = RestIntentBridge()
    var skip: (() -> Void)?
    var extend: ((TimeInterval) -> Void)?
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RestIntentBridge.shared.skip?()
        return .result()
    }
}

struct ExtendRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Extend Rest 30s"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RestIntentBridge.shared.extend?(30)
        return .result()
    }
}
