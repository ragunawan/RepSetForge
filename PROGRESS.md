# RepSetForge — PROGRESS

Current phase: **3 — Timers + Live Activity** (code complete; gate is on-device only)

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
