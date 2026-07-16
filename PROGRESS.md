# RepSetForge — PROGRESS

Current phase: **0 — Skeleton** (complete pending on-Mac build verification)

## Completed
- P0.1 Scripts/generate_design_tokens.py + generated RepSetForge/Design/DesignTokens.swift from Docs/repsetforge-tokens.json (adaptive light/dark colors, mono type scale w/ tracking, spacing, radius, motion, touch targets) — done
- P0.2 App scaffold: RepSetForgeApp.swift, RootView.swift (empty screen, token colors, mono default, dark+light previews) — done
- P0.3 Info.plist with verbatim §8b usage strings (NSHealthUpdate/ShareUsageDescription), NSSupportsLiveActivities — done
- P0.4 Entitlements: app (HealthKit, CloudKit container iCloud.dev.gnwn.RepSetForge, aps-environment) + widget (app group group.dev.gnwn.RepSetForge) — done
- P0.5 Widget extension scaffold: WidgetBundle + Live Activity stub (WorkoutActivityAttributes defined; full surfaces = Phase 3) — done
- P0.6 project.pbxproj (objectVersion 77, synchronized folders, 3 targets: app / widget appex / unit tests) + shared scheme — done

## Gate status
- Phase 0 gate ("builds, empty screen renders both modes with token colors"): **NOT YET VERIFIED — no macOS/xcodebuild in this environment.** Structure complete; must run `xcodebuild -scheme RepSetForge build` on a Mac. All builds/gates require on-Mac verification until CI exists.

## Decisions
- D1 Bundle id `dev.gnwn.RepSetForge`, CloudKit container `iCloud.dev.gnwn.RepSetForge`, app group `group.dev.gnwn.RepSetForge` (spec silent; derived from owner domain gnwn.dev).
- D2 Docs live in `Docs/` (capital D); goal text says `docs/` — paths in scripts use `Docs/`.
- D3 DesignTokens: colors as UIColor dynamic providers (trait-based light/dark); numeric type styles add `.monospacedDigit()`; tracking exported in points (em × size).
- D4 pbxproj uses Xcode 16 synchronized root groups so new files auto-join targets (Info.plist excluded via exception sets).
- D5 Test target is hosted (TEST_HOST = app) so @testable import works with app-only types.

## Next
- Phase 1 — Data core: SwiftData models per §2, ModelConfiguration(cloudKitDatabase:), session restore policy (§1), canonical-name dedup, e1RM/StrengthMath, PR rebuild. Gate: unit tests.
