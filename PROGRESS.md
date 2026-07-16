# RepSetForge — PROGRESS

Current phase: **8 — Settings/polish/submission** (all phases 0–8 code complete on 2026-07-16; every build/test/device gate pending on-Mac verification)

## Phase 7 completed
- P7.1 InvalidationChain: §6 four-step chain (PR recompute via PRRebuilder wholesale-replace + isPR cascade; ladder implicit-live; rollups computed-on-demand; Health re-write via healthKitUUID) + deleteSession w/ HKWorkout propagation — done
- P7.2 LibraryView + RoutineBuilderView: create/archive, drag reorder, superset grouping via context menu (singleton groups dissolve), target steppers, RuleEditorView bound to ProgressionRule — done
- P7.3 HistoryView: month-grouped list, swipe-delete → chain, SessionDetailView edit → chain on Done — done
- P7.4 ProgressTabView: weekly volume rollups computed live from SetEntry (12-week bar chart), insight sentence, 2-week unlock state — done

## Phase 8 completed
- P8.1 CSVCodec: spec schema, RFC-4180 quoting, tolerant import (skips bad rows, keeps good) + round-trip tests — done
- P8.2 SettingsView: units/rest/RPE toggle/plate bar weight/bodyweight log/CSV export+share/iCloud line/Delete-All (typed DELETE + HKWorkout purge) — done
- P8.3 Submission artifacts: Docs/submission/review-notes.md (Health rationale, privacy label, test script), screenshot-list.md; usage strings already in Info.plist from Phase 0 — done
- P8.4 Settings wired to Home profile button — done

## Phase 5 completed
- P5.1 ExercisePickerView: search (canonical-key), ALL/FAV/RECENT filters, favorite toggle, first-run "Create your first exercise" (DB ships empty) — done
- P5.2 CreateExerciseView: name+muscles+equipment form, live "Similar exists" rows via ExerciseDeduplicator with use-instead action — done

## Phase 6 completed
- P6.1 BodyChartMath (pure): period aggregation (W daily/M 10-slot/Y 12-slot means), BF% interpolation ≤14d (never leading/trailing, never long gaps), deltas, span labels + tests — done
- P6.2 HealthKitExporter: lazy auth at first completion, healthKitUUID guard (edit = delete+re-save), delete propagation, graceful when denied — done
- P6.3 HomeView 4 modules: resume banner, week strip, recommended-next (least-recently-performed), Body dual-axis module w/ W/M/Y + swipe/arrow paging + locked/no-BF states — done
- P6.4 SummaryView: duration/sets/reps/volume, PR spotlight, Health line — done
- P6.5 RootView: tabs+FAB+active pill, fullScreenCover workout, §1 restore branching UI, finish→Health export→summary; App attaches CloudKit container (ephemeral fallback) — done

## Phase 4 completed
- P4.1 LadderEngine (pure): rung generation (every rep low→high), qualify rule (weight==, reps>=, RPE<=max or missing, working/failure only), chronological replay w/ multi-rung skip + level-up regen; promptTarget == regenerate().current by definition — done
- P4.2 LadderEngineTests: property tests — regenerable from history (edit regresses, input-order independent), prompt==ladder head, RPE gating, warmup exclusion, level-up — done
- P4.3 ProgressionPanel: rule rows + ladder list (done dim 55% / current signal-dim bg / level-up annotation, per-level e1RM, completion dates) fed by engine from live session — done

## Phase 3 completed
- P3.1 WorkoutActivityAttributes moved to app Services/ and shared to widget target via pbxproj exception set (VERIFY membership in Xcode) — done
- P3.2 SkipRestIntent/ExtendRestIntent (LiveActivityIntent, in-process via RestIntentBridge) — done
- P3.3 LiveActivityController: start/update/end (.after(4s) on finish, .immediate on discard), foreground re-assert, time-sensitive rest-complete notification — done
- P3.4 Full lock-screen + Dynamic Island surfaces (compact/minimal/expanded), all OS-driven ticking, Skip/+30s buttons resting-only, widgetURL deep link — done
- P3.5 VM wiring: rest transitions → activity update + notification; page change/set completion → update; intents → RestTimerManager — done

## Completed
- P2.1 RestLedger (pure): completed intervals + wall-clock current rest; WORK+REST≡SESSION by construction; overtime/extend/skip; tests incl. invariant sweep — done
- P2.2 GhostResolver (pure): row-above → prev-session inheritance, per-field fill, touched semantics + tests — done
- P2.3 RestTimerManager: @Observable wall-clock wrapper over ledger (Phase 3 adds Live Activity + notification) — done
- P2.4 WorkoutViewModel: telemetry aggregates, chart-collapse map, completion flow (commit ghosts→completedAt→PR check→rest start→auto-append last row), applyTarget, add/delete set — done
- P2.5 ActiveWorkoutView + TelemetryHeader: TabView(.page) carousel; SESSION/WORK/REST all OS-driven Text(timerInterval:) with ledger offsets (no per-second state); progress bar — done
- P2.6 ExerciseFocusPage: full-bleed identity/chart/prompt/table/add-set/finish; CoachingPromptBanner (ladder binding = Phase 4) — done
- P2.7 SetTableView: 3 Dynamic-Type tiers in one view (grid / AX1 shed-rest / AX2+ stacked row per §7a C1), type badge menu w/ subscripts, stepper accessory (2.5kg/1rep/0.5RPE), optimistic completion + haptics + reduce-motion — done
- P2.8 ChartSection: Swift Charts bars+line+%1RM rule, collapse-on-first-set w/ 200ms fade, per-page state — done
- P2.9 BottomPill: rest countdown replaces pager (OS-driven ProgressView(timerInterval:)), +30s/Skip, index/PROG/minimize — done
- P2.10 ExerciseIndexSheet (read-only, jump+reorder) + ProgressionPanel shell (engine = Phase 4) — done
- P1.1 TrainingModels.swift: all §2 @Model classes (Exercise…UserProfile) with CloudKit-safe shapes (all relationships optional, defaults everywhere, no .unique); enums via raw-value shadows; SetEntry.e1RM computed — done
- P1.2 ModelContainerFactory: .private(iCloud.dev.gnwn.RepSetForge) prod config + in-memory ephemeral for tests/previews — done
- P1.3 StrengthMath: Epley e1RM (reps 1–12, reps=1→w), canonicalNameKey, volumeKg + tests — done
- P1.4 ExerciseDeduplicator: Levenshtein ≤2 OR token subset over canonical keys + tests — done
- P1.5 SessionRestorePolicy: <4h silent / ≥4h sheet / ≥12h-or-midnight suggest finish-as-is; finishAsIsEnd = last set timestamp + tests — done
- P1.6 PRRebuilder: pure rebuild of all 4 PR kinds + isPR flags from SetSnapshot history (order-independent, warmups excluded) + fixture tests incl. regression-on-delete — done
- P1.7 ActiveSessionStore: @Observable singleton, adopt-unfinished-on-configure, debounced ≤500ms autosave, finish/finishAsIs/discard — done
- P0.1 Scripts/generate_design_tokens.py + generated RepSetForge/Design/DesignTokens.swift from Docs/repsetforge-tokens.json (adaptive light/dark colors, mono type scale w/ tracking, spacing, radius, motion, touch targets) — done
- P0.2 App scaffold: RepSetForgeApp.swift, RootView.swift (empty screen, token colors, mono default, dark+light previews) — done
- P0.3 Info.plist with verbatim §8b usage strings (NSHealthUpdate/ShareUsageDescription), NSSupportsLiveActivities — done
- P0.4 Entitlements: app (HealthKit, CloudKit container iCloud.dev.gnwn.RepSetForge, aps-environment) + widget (app group group.dev.gnwn.RepSetForge) — done
- P0.5 Widget extension scaffold: WidgetBundle + Live Activity stub (WorkoutActivityAttributes defined; full surfaces = Phase 3) — done
- P0.6 project.pbxproj (objectVersion 77, synchronized folders, 3 targets: app / widget appex / unit tests) + shared scheme — done

## Outstanding before v1.0 ships (needs a Mac / device)
1. `xcodebuild build` + `xcodebuild test` — fix any compile errors (all code written without a Swift toolchain available)
2. Snapshot tests at large/xxxLarge/AX1/AX3 × light/dark (suite not yet written — needs simulator)
3. On-device gates: Live Activity (Phase 3), Fitness-app export/edit/delete (Phase 6)
4. Superset paged rendering (§3 resolved model — group = one page) not yet implemented; plate-calc long-press popover pending; prev-session ghost feed passes [] (needs history query wiring in ActiveWorkoutView)
5. CSV import UI (codec + tests done; file-picker flow pending); plate calc config editor; theme picker
6. CloudKit prod schema deploy + TestFlight round with Health denied

## Gate status
- Phase 2 gate (two-taps demo; snapshots at 4 sizes × 2 modes): **snapshot suite not yet written (needs simulator); two-tap flow implemented (✓ commits ghosts, no modals).** Open items: superset pages (§3 resolved model), plate-calc long-press, prev-session ghost feed (needs history query), rest field per RoutineItem.
- Phase 1 gate (unit tests: e1RM, dedup fuzzy-match, restore branching, PR rebuild from fixture): **suites written, NOT RUN — requires `xcodebuild test` on a Mac.**
- Phase 0 gate ("builds, empty screen renders both modes with token colors"): **NOT YET VERIFIED — no macOS/xcodebuild in this environment.** Structure complete; must run `xcodebuild -scheme RepSetForge build` on a Mac. All builds/gates require on-Mac verification until CI exists.

## Decisions
- D1 Bundle id `dev.gnwn.RepSetForge`, CloudKit container `iCloud.dev.gnwn.RepSetForge`, app group `group.dev.gnwn.RepSetForge` (spec silent; derived from owner domain gnwn.dev).
- D2 Docs live in `Docs/` (capital D); goal text says `docs/` — paths in scripts use `Docs/`.
- D3 DesignTokens: colors as UIColor dynamic providers (trait-based light/dark); numeric type styles add `.monospacedDigit()`; tracking exported in points (em × size).
- D4 pbxproj uses Xcode 16 synchronized root groups so new files auto-join targets (Info.plist excluded via exception sets).
- D5 Test target is hosted (TEST_HOST = app) so @testable import works with app-only types.
- D6 Warmup sets never qualify for PRs (spec silent; prototype-consistent smallest choice).
- D7 repsAtWeight PRs kept per distinct weight bucket; first set at a new weight seeds the bucket without counting as a PR.
- D8 Enum-typed model fields stored as raw-value String shadows (typeRaw/statusRaw/kindRaw) for CloudKit/SwiftData safety; typed accessors on top.
- D9 PRRebuilder core is pure (SetSnapshot values in, records + isPR ids out); SwiftData adapter applies results in Phase 6/7 invalidation chain.

## Next
- Phase 2 — Focus view + set row (the product): carousel, telemetry header from one rest ledger, ghost inheritance, completion flow, chart collapse, coaching prompt, AX stacked row. Port logic from Docs/repsetforge-prototype.jsx.
