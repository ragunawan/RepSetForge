# RepSetForge Progress

Current phase: Phase 8 - Settings, CSV, polish, submission prep

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
- P4.1 Ladder engine - done, double-progression level generation derives from SetEntry history, supports historical regression, and remains rebuildable.
- P4.2 Focus prompt ladder source - done, coaching prompt and tap-to-apply target use the current ladder level as the single source of truth.
- P4.3 PROG panel - done, bottom PROG opens a tokenized rule + ladder sheet with current/completed level states.
- Phase 4 gate 2026-07-16 - done, `test_sim CODE_SIGNING_ALLOWED=NO` green (23/23) including ladder regeneration property coverage and prompt == ladder head.
- P5.1 Exercise picker + first-run create flow - done, production root now starts with an empty exercise DB placeholder, picker supports debounced search, recents/favorites/all sections, AND-combined muscle/equipment chips, inline history preview with explicit Add to workout, and one-screen custom exercise creation with dedup "Similar exists" gating.
- Phase 5 gate 2026-07-15 - done, `build_sim CODE_SIGNING_ALLOWED=NO` green; `test_sim CODE_SIGNING_ALLOWED=NO` green (23/23).
- P6.1 Root tab shell + Home placeholders - done, RootView now hosts Home/History/Progress/Library tabs with FAB-driven active workout cover; Home renders resume banner plus week/recommendation/body modules in stable positions with first-run placeholders and dual-line body chart sketch.
- P6.2 Body chart period paging - done, Home Body module now uses BodyMetric W/M/Y period paging, swipe/arrows, weight aggregation, and 14-day body-fat interpolation; `build_sim CODE_SIGNING_ALLOWED=NO` green.
- P6.3 Summary + HealthKit finish path - done, Focus finish now completes the SwiftData session, shows Summary deltas/PR spotlight/routine prompt, exports phone-only HealthKit workouts through HKWorkoutBuilder with healthKitUUID replacement guard and delete helper; `test_sim CODE_SIGNING_ALLOWED=NO` green (23/23).
- P7.1 History calendar/list + historical PR invalidation - done, History tab now renders completed-session month grid, composed text/PR filters, empty state, session rows, and edit/delete sheet wired through `HistoricalSessionInvalidator`; `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- P7.2 Routine library/builder - done, Library tab now lists routines and opens a SwiftData-backed builder with move ordering, target/rest/note editing, per-item ladder rule editing, and save validation for non-empty name + ≥1 exercise; `build_sim CODE_SIGNING_ALLOWED=NO` green; `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- P7.3 Progress charts - done, Progress tab now renders derived chart cards for volume, e1RM, and PRs with per-card locked states under 4 points and insight sentences from the same completed-session query; `build_sim CODE_SIGNING_ALLOWED=NO` green; `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- Phase 7 gate 2026-07-15 - done for simulator scope, Library/Builder + History + Progress all build and tests pass with `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- P8.1 Settings sheet - done, Home gear opens Settings with units/default rest/RPE/plate/body metric/Health auto-save/theme/iCloud status controls plus typed Delete All Data that purges SwiftData records and best-effort app-created HKWorkouts; `build_sim CODE_SIGNING_ALLOWED=NO` green; `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- P8.2 CSV import/export - done, Settings exports completed SetEntry history to `date,exercise,set_type,weight_kg,reps,rpe` CSV and imports the same schema into completed SwiftData sessions with exercise dedup + PR rebuild; `build_sim CODE_SIGNING_ALLOWED=NO` green; `test_sim CODE_SIGNING_ALLOWED=NO` green (24/24).
- P8.3 App Store text artifacts - done, `docs/app-store-submission.md` now contains privacy-label text, privacy-policy requirements, verified Health usage strings, review notes, demo path, Health-denied path, screenshot list, and release checklist.
- P8.4 Accessibility audit artifact - done, `docs/accessibility-audit.md` records completed simulator checks for Dynamic Type tiering/VoiceOver/reduce-motion and separates pending device/manual verification.

Decisions:
- Phase 0 render check used a temporary app-only simulator install after the full unsigned app+widget product hit an install-time embedded-extension placeholder check; the committed project still builds app + widget extension together.
- XCTest uses an in-memory SwiftData container so hosted tests do not require CloudKit entitlements while normal app runs use the private CloudKit database.
- Phase 2 render gate uses SwiftUI `ImageRenderer` smoke snapshots in XCTest for the required type-size/color-scheme matrix until a pixel-baseline snapshot harness is introduced.
- Phase 2 plate calculator uses the spec default 20 kg bar and common kg plate set locally until Settings owns configurable plate inventory.
- Phase 3 simulator verification covers build/tests only; the phase gate remains open because the plan requires on-device lock-screen/background Live Activity behavior.
- Phase 4 Focus uses the default double-progression rule until Phase 8 routine builder/library binds editable `ProgressionRule` rows to routine items.
- Phase 5 keeps existing FocusWorkoutStore sample data as an explicit test/preview default, while production RootView injects an empty exercise list to satisfy the empty-shipped-DB first-run flow.
- Phase 6 Health export uses a fixed 82 kg bodyweight estimate until Settings/Health bodyweight read owns the canonical current bodyweight input.
- Phase 7 historical edit currently recomputes PR records/flags and HealthKit rewrite/delete; ladder and weekly rollup recomputation hooks remain pending with the Progress/routine-builder slices.
- Phase 7 routine builder currently edits routine templates only; starting a workout from a saved routine and post-workout template diff adoption remain pending integration points.
- Phase 7 Progress uses rebuildable completed-session aggregates directly rather than stored weekly rollup models; storing derived rollups remains intentionally avoided until a cache invalidation layer is added.
- Phase 8 Settings preferences are persisted first; threading units/RPE/default rest/plate inventory/theme through all Focus surfaces remains a follow-up.

Open:
- Phase 3 gate pending: on-device lock phone mid-rest, countdown ticks, Skip works from lock screen, activity survives backgrounding.
- Phase 6 pending: on-device workout appears in Fitness app; edit session updates HKWorkout via healthKitUUID; delete session removes HKWorkout.
- Phase 8 pending: hosted privacy policy URL, CloudKit production schema deploy, TestFlight Health-denied path, AX5/device tap-target audit, rest announcements, haptic verification, and contrast measurement.
