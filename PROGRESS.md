# RepSetForge — PROGRESS

Current phase: **1 — Data core** (code complete; tests written, not yet run — no macOS toolchain here)

## Completed
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
