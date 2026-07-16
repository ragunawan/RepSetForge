# RepSetForge Progress

Current phase: Phase 2 - Active Workout Loop

Completed:
- Phase 0 started - PROGRESS.md created.
- P0.1 Xcode project scaffold - done, app + widget extension targets created.
- P0.2 DesignTokens.swift generation - done from docs/repsetforge-tokens.json.
- Phase 0 gate 2026-07-15 - done, `build_sim CODE_SIGNING_ALLOWED=NO` green; empty token-colored app screen rendered in light and dark on iPhone 17 simulator.
- P1.1 SwiftData model layer - done, Exercise/Routine/RoutineItem/ProgressionRule/WorkoutSession/SessionExercise/SetEntry/PRRecord/BodyMetric/UserProfile added with optional CloudKit-safe relationships.
- P1.2 CloudKit ModelContainer wiring - done, private database configuration added with XCTest in-memory fallback.
- P1.3 data-core services - done, e1RM, canonical-name dedup, restore policy, PR rebuild implemented.
- Phase 1 gate 2026-07-15 - done, `test_sim CODE_SIGNING_ALLOWED=NO` green (11/11); final `build_sim CODE_SIGNING_ALLOWED=NO` green.

Decisions:
- Phase 0 render check used a temporary app-only simulator install after the full unsigned app+widget product hit an install-time embedded-extension placeholder check; the committed project still builds app + widget extension together.
- XCTest uses an in-memory SwiftData container so hosted tests do not require CloudKit entitlements while normal app runs use the private CloudKit database.

Open:
- Phase 2 gate: two-taps-per-unchanged-set demo; snapshot tests at 4 type sizes x 2 modes.
