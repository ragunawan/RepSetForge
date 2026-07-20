import Foundation
import SwiftData
import Observation

/// Singleton owner of the one active WorkoutSession (§1: only one at a time).
/// Every mutation calls `touch()`, which persists the draft within 500 ms
/// (perf contract §8). Restore branching on launch via SessionRestorePolicy.
@Observable
@MainActor
final class ActiveSessionStore {
    private(set) var session: WorkoutSession?
    /// Read access for history queries (ghost feed, ladder history).
    private(set) var context: ModelContext?
    private var saveTask: Task<Void, Never>?

    var isActive: Bool { session != nil }

    func configure(context: ModelContext) {
        self.context = context
        // Adopt an unfinished session left by a previous launch, newest first.
        let active = SessionStatus.active.rawValue
        var fd = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == active },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        fd.fetchLimit = 1
        session = try? context.fetch(fd).first
    }

    /// Restore action for an adopted unfinished session, nil if none.
    func restoreAction(now: Date = .now) -> SessionRestoreAction? {
        guard let session else { return nil }
        return SessionRestorePolicy.action(startedAt: session.startedAt, now: now)
    }

    func start(name: String, routine: Routine? = nil) {
        guard session == nil, let context else { return }
        let s = WorkoutSession(name: name, routine: routine)
        context.insert(s)
        session = s
        touch()
    }

    func finish(endedAt: Date = .now) {
        guard let session else { return }
        session.endedAt = endedAt
        session.status = .completed
        self.session = nil
        saveNow()
    }

    func finishAsIs() {
        guard let session else { return }
        let lastSet = (session.exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .compactMap(\.completedAt)
            .max()
        finish(endedAt: SessionRestorePolicy.finishAsIsEnd(
            startedAt: session.startedAt, lastSetCompletedAt: lastSet))
    }

    func discard() {
        guard let session, let context else { return }
        context.delete(session)
        self.session = nil
        saveNow()
    }

    /// Call after every mutation: debounced persist, ≤500 ms after last change.
    func touch() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        try? context?.save()
    }
}
