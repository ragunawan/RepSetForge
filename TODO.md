# TODO — RepSetForge

Canonical, prioritized backlog. Structured around the dev spec's build order (`Docs/repsetforge-dev-spec.md` §9). Work top to bottom within a tier; don't skip ahead without reason. Check items off as they land.

## P0 — v1.0 build order (dev spec §9)

### 1. Data model + session persistence/restore
- [x] SwiftData `@Model` types: `Exercise`, `Routine`, `RoutineItem`, `ProgressionRule`, `WorkoutSession`, `SessionExercise`, `SetEntry`, `PRRecord`, `BodyMetric` (dev spec §2)
- [x] `PersistenceController` — `ModelContainer` with CloudKit private-database config + automatic local fallback
- [x] `RepSetForgeSchema` — versioned schema (`RepSetForgeSchemaV1`) + migration plan scaffold
- [x] `ExerciseDedupService` — canonical-name key + fuzzy match (Levenshtein ≤ 2, token subset)
- [x] `RepSetForgeTheme` — token translation from the hi-fi mockup's CSS custom properties
- [x] `WorkoutSession` singleton draft persistence: autosave is implicit (SwiftData writes on every mutation via the shared `ModelContext`, no explicit save calls needed). Restore-on-launch rules (dev spec §1) are wired in `ContentView`: sessions < 4h old resume silently through the existing FAB/resume-banner path; sessions ≥ 4h old route through a new `UnfinishedSessionSheet` (Resume / Finish as-is / Discard, destructive-confirmed) instead, checked once per app-process launch via `.task(id: activeSession?.id)`; sessions ≥ 12h old or that have crossed midnight since `startedAt` get the same sheet but with "Finish as-is" promoted to the primary button and a warning line. "Finish as-is" commits with `endedAt` = the last completed set's timestamp (falls back to `startedAt` if no sets were logged), not `.now`. Staleness/finish-as-is logic lives in `WorkoutSessionRestoreService` (pure, unit-tested with fixed reference dates — `WorkoutSessionRestoreServiceTests`) rather than inline in the view.
- [x] `RootView` navigation shell wired to real state: `TabView` (Home · History · Progress · Library) + FAB, `StartWorkoutSheet`, `ActiveWorkoutSheet` (`ActiveWorkoutView`) as `.fullScreenCover` with `interactiveDismissDisabled` + minimize-not-dismiss swipe behavior
- [x] Finish requires: Finish button → confirmation sheet with mini-summary → commit (`FinishWorkoutConfirmationSheet`); Cancel workout behind the ⋯ overflow with a destructive confirmation — both live in `ExerciseIndexSheet`/`ActiveWorkoutView` per dev spec §1

### 2. Exercise Focus view + set row (the product lives or dies here) + read-only Index sheet
- [x] Exercise Focus screen (dev spec §3, mockup frame 2b): telemetry header, exercise identity row, in-context chart with collapse-on-first-set, coaching prompt banner, set table, bottom pill/pager. Simplifications to revisit: chart is e1RM-trend-only (no volume bars, no %1RM overlay, no date-range toggle), "SET n/total" counts all sets across the whole session rather than tracking planned-vs-completed against routine targets (no routines yet), rest duration is a hardcoded 90s default (no `RoutineItem.restSeconds` to read from yet).
- [x] Set row component: ghost-text inheritance, PR check on commit, RPE chip row, set-type menu, swipe-to-delete — full behavior contract in dev spec §3. Not done: inline numpad accessory (uses the system decimal/number pad instead) and the long-press plate calculator.
- [ ] Superset handling: one page per group, intra-superset auto-advance, group-level rest timer
- [x] Read-only Exercise Index sheet (mockup frame 2, replaces old list view — navigation/orientation only, no set entry). Reorder is still TODO.
- [ ] Progression panel (mockup frame 2c): rule editor rows, generated ladder, per-session qualifying checkmarks — **double progression (`.ladder`) only**; don't add other `ProgressionRuleType` cases yet. The bottom pill's PROG button is currently a disabled stub.
- [x] PR engine (`PersonalRecordService`): compare against `PRRecord` per kind on set commit, inline gold PR badge, no modal. Covers `.bestWeight`/`.bestE1RM`/`.bestVolume`; `.repsAtWeight` still needs a per-weight-keyed record shape (see the service's doc comment) — not implemented.

### 3. Rest timer + Live Activity + Dynamic Island
- [x] `RestTimerManager` — wall-clock `Date` math, not a running timer (survives backgrounding); start/extend/skip
- [x] Rest pill UI (in-app, `RestTimerPill`) with overtime state (counts up, warning color)
- [ ] ActivityKit Live Activity: lock screen, Dynamic Island compact/minimal/expanded, all per dev spec §4 — requires adding a Widget Extension target (not yet in `generate_project.py`)
- [ ] Local notification at rest completion when backgrounded

### 4. Exercise picker + dedup + create-exercise flow
- [ ] Exercise Selection screen (mockup frame 3): searchable, Recents/Favorites/All sections, muscle+equipment chip filters, inline history preview on row tap. `AddExerciseSheet` is a **minimal stand-in** for this (plain list + create form) built just to unblock the Exercise Focus flow — replace it, don't build alongside it.
- [x] Create-exercise flow: name + muscle groups + equipment, one screen, "Similar exists" row wired to `ExerciseDedupService` — done inside `AddExerciseSheet`; needs to move into the real picker above.
- [ ] First-run empty state: "Create your first exercise" leads the picker

### 5. Home, Summary, routine-update prompt, HealthKit export (phone-only path)
- [x] Home screen (`HomeView`, mockup frame 1): resume-workout banner, recommended-next card, week-at-a-glance strip (`HomeStatsService`: sessions/volume/sets/PRs/streak/sparkline), Body module. Simplified: Body module shows the latest `BodyMetric` entry + delta from the previous one (`LogBodyMetricSheet`) rather than the full dual-axis weight/body-fat chart with W/M/Y range paging. Recommended-next is still always a placeholder — routines exist now (step 6), but the actual "least-recently-performed routine, tie-broken by lowest muscle-group weekly set count" ranking (dev spec §5) isn't implemented yet.
- [x] First-run placeholder modules per Home card (dev spec §5) — same layout skeleton, dashed border, states its own unlock condition. Progress/History's own placeholder states are separate work (step 7).
- [x] Workout Summary screen (`WorkoutSummaryView`, mockup frame 4): duration/sets/reps/volume, PR callouts, vs.-last-session deltas (prefers matching by `routine`, falls back to matching by name per dev spec §5), muscles-trained chips
- [ ] Post-workout routine-update diff sheet
- [ ] HealthKit export, phone-only path (dev spec §4b): `HKWorkoutBuilder`, permission requested at first workout completion (not onboarding), duplicate-write guard via `WorkoutSession.healthKitUUID`

### 6. Routine builder + library + double-progression ladder
- [x] Routine Library screen (`RoutineLibraryView`, mockup frame 5): routines/exercises segmented list, empty state
- [x] Routine Builder screen (`RoutineBuilderView`, mockup frame 9): reorderable items (drag + `EditButton`), save validation (non-empty name + ≥1 exercise). Not done: superset grouping (shared `groupID`), the progression-rule editor rows. Cancel doesn't roll back live edits to an *existing* routine's items (reorder/target-stepper edits and deletes apply immediately) — see the doc comment on the view; a new routine's Cancel is clean since nothing's inserted until Save.
- [x] `StartWorkoutSheet` now offers "start from a routine", pre-populating `SessionExercise`s + empty `SetEntry`s from each `RoutineItem`'s `targetSets`, and tags each `SessionExercise.routineItem` for the progression panel to use
- [x] Progression ladder engine (`ProgressionLadderService`): generates levels from `ProgressionRule` + a base weight (the most recent working-set weight logged for that exercise), level-completion logic (≥ `qualifyingSetsRequired` matching sets in one session at RPE ≤ max), the level-up entry past the top of the rep range. `ProgressionPanelView` (mockup frame 2c) displays it; the bottom pill's PROG button now opens it when the session came from a routine (disabled stub otherwise, e.g. ad-hoc workouts). New `RoutineItem`s get a default `ProgressionRule()` since the rule *editor* UI isn't built — tap-to-edit rows on the rule fields are still TODO.

### 7. History, Progress, PR engine backfill
- [x] History screen (`HistoryView`, mockup frame 7): List view (default) + a Monday-first Calendar grid marking completed-session days. Not done: "planned" (dashed) future sessions — no scheduling feature exists (that's separate TODO scope) — and the muscle/routine filter chips.
- [x] Progress screen (`ProgressScreenView`, mockup frame 8): weekly volume sparkline + insight, frequency/consistency (avg sessions/week, streak, PRs this period), muscle distribution vs. target, 4W/3M/1Y range toggle (`ProgressStatsService`, reuses `HomeStatsService`'s weekly-volume/streak helpers). The muscle-distribution target is a **hardcoded 12 sets/week** (matching the mockup's own example) — no Settings screen yet to make it configurable (step 8). Empty state instead of true per-card "locked" states (insufficient-data thresholds like "<4 points" aren't implemented per-card); the per-exercise "trend locked" card (e.g. "Log 3 more deadlift sessions") isn't built either.
- [x] Exercise Detail screen (`ExerciseDetailView`, mockup frame 6): best/e1RM/volume stats, e1RM trend chart with insight sentence, PR timeline, recent sessions. Shares `ExerciseHistoryService` with `ExerciseFocusView`'s in-context chart (refactored out of that view rather than duplicated). No 4W/3M/1Y range toggle — same simplification as the Focus screen's chart.
- [ ] Historical edit invalidation chain (dev spec §5): editing/deleting a past session → PR recompute → ladder recompute → weekly rollup invalidation → HealthKit re-write, one background transaction. Can't be built yet anyway — there's no way to edit a completed session's sets at all.

### 8. Settings, CSV, first-run placeholders, light mode, accessibility audit
- [x] Settings screen (`SettingsView`, mockup frame 10), opened from Home's profile button. Wired for real: default rest duration (`ExerciseFocusView` reads `AppSettingsKeys.defaultRestSeconds` instead of a hardcoded 90s), RPE visibility (`SetRowView` hides the RPE column app-wide when off), theme light/dark/system (applied via `.preferredColorScheme` at `ContentView`'s root), bodyweight entry (links to `LogBodyMetricSheet`), Delete all data (real deletion across every model type, gated behind typing "DELETE" in an alert `TextField`). Stored-but-not-wired: units kg/lb (the toggle exists; no display call site converts yet — that's a much larger change touching every weight `Text` in the app). Not built at all: plate calculator config (no plate-calc UI exists to configure — see `SetRowView`'s note), CSV import/export, and a real CloudKit account/container status check (`iCloud sync` shows a best-effort `FileManager.ubiquityIdentityToken` check, not an actual sync-state round-trip).
- [ ] Light mode pass across all screens (tokens already support it — verify contrast ≥ 4.5:1, dev spec §7)
- [x] Accessibility pass on the set row (dev spec §7/§7a): `SetRowView` now branches to a fully stacked AX2+ layout (WEIGHT/REPS fields ≥48pt tall, full-width ≥52pt Complete button) at `.accessibility2` and above; 44×44 minimum tap targets on the type badge, RPE chip, and complete button via `.frame` + `.contentShape(Rectangle())` around unchanged smaller visual glyphs; VoiceOver via `.accessibilityElement(children: .combine)`, a built-up `accessibilityLabelText` ("Bench press, set 2 of 4, ... completed"), and a custom "Complete set" `.accessibilityAction`; haptics (`UIImpactFeedbackGenerator` on set complete, `UINotificationFeedbackGenerator` on PR in `ExerciseFocusView.handleCompletion`); `.accessibilityReduceMotion` disables the two `withAnimation` chart-collapse calls. Not done: the narrower Tier 2/AX1 refinement (rest folded into badge, shortened Prev text) — this jumps straight from compact to fully stacked; snapshot testing at large/xxxLarge/AX1/AX3 (no simulator/device available in this environment); contrast verification (needs the light-mode pass below).

### 9. App Store submission package (dev spec §8b)
- [ ] Privacy nutrition label (Health & Fitness + User Content, no tracking)
- [ ] Privacy policy URL, hosted before submission
- [ ] Usage strings (`NSHealthUpdateUsageDescription` / `NSHealthShareUsageDescription`) — concrete, not generic
- [ ] App Review notes + 60-second demo path
- [ ] Screenshots (6.9"/6.5", dark mode primary, showing Health integration)
- [ ] TestFlight external beta round; CloudKit production container schema deploy; Delete All Data verified against production CloudKit; permission-denied end-to-end pass

## P1 — v1.1

- [ ] Apple Watch companion app (dev spec §4c): mirrored `HKWorkoutSession`, live HR/kcal telemetry, Watch-owned Health writes, three-page UI (Now/Rest/Vitals) — requires adding a watchOS target back to `generate_project.py`
- [ ] Additional progression methodologies as new `ProgressionRule.type` cases: 5/3/1 (percentage-of-training-max waves + AMRAP), percentage/wave periodization, RIR-based autoregulation

## Known gaps / not yet designed

- `Docs/repsetforge-hifi.html` references a `gymchalk-tokens.json` design-token file that was never provided — `RepSetForgeTheme.swift` approximates it from the mockup's inline CSS custom properties. Reconcile if the real file ever shows up.
- No CI configured yet (no `.github/workflows`) — build/test currently must be run manually via `xcodebuild` on macOS.
