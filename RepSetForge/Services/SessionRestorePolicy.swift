import Foundation

enum RestoreAction: Equatable {
  case none
  case silentResume
  case prompt(autoSuggestFinishAsIs: Bool, finishAsIsEndedAt: Date?)
}

enum SessionRestorePolicy {
  static func action(for session: WorkoutSession?, now: Date = .now, calendar: Calendar = .current) -> RestoreAction {
    guard let session, session.status == .active, session.endedAt == nil else {
      return .none
    }

    let duration = now.timeIntervalSince(session.startedAt)
    let crossesMidnight = !calendar.isDate(session.startedAt, inSameDayAs: now)
    let lastCompletedAt = session.exercises?
      .flatMap { $0.sets ?? [] }
      .compactMap(\.completedAt)
      .max()

    if duration < 4 * 60 * 60, !crossesMidnight {
      return .silentResume
    }

    let shouldAutoSuggestFinish = duration >= 12 * 60 * 60 || crossesMidnight
    return .prompt(autoSuggestFinishAsIs: shouldAutoSuggestFinish, finishAsIsEndedAt: lastCompletedAt)
  }
}
