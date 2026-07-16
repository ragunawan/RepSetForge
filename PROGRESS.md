# RepSetForge Progress

Current phase: Phase 3 - Rest Timer + Live Activity + Dynamic Island

Completed:
- Phase 0 started - PROGRESS.md created.
- P0.1 Xcode project scaffold - done, app + widget extension targets created.
- P0.2 DesignTokens.swift generation - done from docs/repsetforge-tokens.json.
- Phase 0 gate 2026-07-15 - done, `build_sim CODE_SIGNING_ALLOWED=NO` green; empty token-colored app screen rendered in light and dark on iPhone 17 simulator.
- P1.1 SwiftData model layer - done, Exercise/Routine/RoutineItem/ProgressionRule/WorkoutSession/SessionExercise/SetEntry/PRRecord/BodyMetric/UserProfile added with optional CloudKit-safe relationships.
- P1.2 CloudKit ModelContainer wiring - done, private database configuration added with XCTest in-memory fallback.
- P1.3 data-core services - done, e1RM, canonical-name dedup, restore policy, PR rebuild implemented.
- Phase 1 gate 2026-07-15 - done, `test_sim CODE_SIGNING_ALLOWED=NO` green (11/11); final `build_sim CODE_SIGNING_ALLOWED=NO` green.
- P2.1 Focus workout loop scaffold - done, `FocusWorkoutStore` + `FocusWorkoutView` added with carousel, telemetry header, ghost inheritance, optimistic completion, chart collapse, inline PR badge, bottom rest pill, read-only index sheet, AX stacked row path.
- P2.2 Phase 2 interaction/render coverage - done, `test_sim CODE_SIGNING_ALLOWED=NO` green (17/17) including two-taps-per-unchanged-set path, rest ledger invariant, chart collapse, PR commit, and large/xxxLarge/AX1/AX3 x light/dark render checks; final `build_sim CODE_SIGNING_ALLOWED=NO` green.
- P2.3 Active-session draft persistence - done, `FocusWorkoutStore` now binds to SwiftData `ModelContext`, creates/restores an active `WorkoutSession`, autosaves mutations, and reloads completed `SetEntry` data.
- P2.4 Inline set input affordances - done, set rows now support inline decimal/numeric keyboard entry, long-press weight plate calculator, and inline RPE chip selection.
- P2.5 PR rebuild on commit - done, SwiftData draft persistence rebuilds `PRRecord` from committed `SetEntry` history and mirrors derived `isPR` flags back to the optimistic row state.
- Phase 2 gate 2026-07-15 - done, `test_sim CODE_SIGNING_ALLOWED=NO` green (19/19); final `build_sim CODE_SIGNING_ALLOWED=NO` green via test build.
- P3.1 RestTimerManager semantics - done, rest remains wall-clock `Date` math with skip/+30s extension, cumulative ledger invariants preserved, and rest completion notification scheduled/cancelled from the single in-app source of truth.
- P3.2 ActivityKit payload + app updates - done, shared attributes/state added, Focus store starts/reasserts/updates Live Activity on set completion, rest start/extend/skip, and page changes; ActivityKit failures are best-effort and do not affect logging.
- P3.3 Live Activity/Dynamic Island views - done, lock screen/banner plus compact/minimal/expanded Dynamic Island implemented with OS-driven timer text, Skip/+30s `LiveActivityIntent`s, widget URL deep link, and tokenized styling.

Decisions:
- Phase 0 render check used a temporary app-only simulator install after the full unsigned app+widget product hit an install-time embedded-extension placeholder check; the committed project still builds app + widget extension together.
- XCTest uses an in-memory SwiftData container so hosted tests do not require CloudKit entitlements while normal app runs use the private CloudKit database.
- Phase 2 render gate uses SwiftUI `ImageRenderer` smoke snapshots in XCTest for the required type-size/color-scheme matrix until a pixel-baseline snapshot harness is introduced.
- Phase 2 plate calculator uses the spec default 20 kg bar and common kg plate set locally until Settings owns configurable plate inventory.
- Phase 3 simulator verification covers build/tests only; the phase gate remains open because the plan requires on-device lock-screen/background Live Activity behavior.

Open:
- Phase 3 gate pending: on-device lock phone mid-rest, countdown ticks, Skip works from lock screen, activity survives backgrounding.
