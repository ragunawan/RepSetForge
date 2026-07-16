# RepSetForge — v1.0 Implementation Plan

Sources of truth (do not re-derive; reference by section):
- `repsetforge-dev-spec.md` — behavior, data model, invariants (§ numbers cited below)
- `repsetforge-tokens.json` — all visual values
- `repsetforge-prototype.jsx` — interaction reference for Focus view + Home
- `repsetforge-hifi.html` — layout reference for all screens

Target: Xcode project, SwiftUI, iOS 17+, SwiftData + CloudKit (private DB), WidgetKit/ActivityKit extension. No third-party dependencies.

---

## Phase 0 — Skeleton (½ day)
Project + targets (app, widget extension), entitlements (HealthKit, CloudKit container, push for ActivityKit), Info.plist usage strings verbatim from §8b, `DesignTokens.swift` generated from tokens.json (colors as adaptive light/dark pairs, type styles, spacing constants), mono font environment default.
**Gate:** builds, empty screen renders in both modes with token colors.

## Phase 1 — Data core (2 days)
SwiftData models per §2 (Exercise, Routine, RoutineItem, ProgressionRule[ladder fields], WorkoutSession, SessionExercise, SetEntry, PRRecord, BodyMetric+bodyFatPct, user profile heightCm) with `ModelConfiguration(cloudKitDatabase:)`. Session singleton with autosave-on-mutation; restore logic per §1 (silent <4h, sheet ≥4h, 12h finish-as-is). Canonical-name dedup (§2). Derived-data rule: PRs/ladders/rollups rebuildable from SetEntry only.
**Gate:** unit tests — e1RM, dedup fuzzy-match, restore branching, PR rebuild from fixture history.

## Phase 2 — Focus view + set row (4 days; the product)
Focus carousel (`TabView(.page)`), full-bleed layout, telemetry header (SESSION/WORK+REST invariant: derive both from one rest ledger), set table with ghost inheritance + stepper input + plate-calc long-press, completion flow (commit→PR check→rest start→haptic→spring), chart with collapse-on-first-set, coaching prompt bound to ladder, superset pages per §3, read-only Index sheet, Dynamic-Type tiers incl. AX stacked row (§7a).
**Gate:** two-taps-per-unchanged-set demo; snapshot tests at 4 type sizes × 2 modes.

## Phase 3 — Timers + Live Activity (2 days)
Wall-clock RestTimerManager, cumulative ledger, ActivityKit per §4: attributes/state, lock screen, DI compact/minimal/expanded, Skip/+30s LiveActivityIntents, dismissal + re-assert rules.
**Gate:** on-device — lock phone mid-rest, countdown ticks, Skip works from lock screen, activity survives backgrounding.

## Phase 4 — Ladder engine + prompt (1.5 days)
Level generation from rule, qualifying-set evaluation, regression on historical edit (§ invalidation chain), PROG panel UI, prompt targets current level (single source of truth).
**Gate:** property tests — ladder always regenerable from SetEntry history; prompt == ladder head.

## Phase 5 — Picker + create-exercise (1 day)
Search/recents/favorites/filters, create flow (name+muscles+equipment), dedup "similar exists" row, first-run "Create your first exercise" state. DB ships empty.

## Phase 6 — Home + Summary + Health (2 days)
Home 4 modules + placeholder states (§ first-run), dual-axis weight/BF% chart with W/M/Y + period paging (port math from prototype), Summary with deltas + PR spotlight, HealthKit export per §4b (permission at first completion, healthKitUUID guard, delete propagation), routine-update prompt.
**Gate:** on-device — workout appears in Fitness app; edit session → HKWorkout updates; delete → gone.

## Phase 7 — Library/Builder, History, Progress (3 days)
Routine builder (drag, superset grouping, targets, rule editor), History calendar/list + historical edit → invalidation chain (§6-resolution), Progress charts + insight sentences + weekly rollups, unlock/empty states.

## Phase 8 — Settings, polish, submission (2 days)
Settings incl. Health toggles + Delete All Data (CloudKit + HKWorkout purge), CSV import/export, light-mode pass, accessibility audit against §7 checklist, §8b package: privacy label, policy URL, review notes, screenshots, **CloudKit prod schema deploy**, TestFlight round with Health-denied path.

Total: ~18 working days solo. Critical path: 0→1→2→3; phases 5/6/7 parallelize partially.

## Risk register
1. CloudKit+SwiftData model constraints (all relationships optional, no unique constraints) — design models for it in Phase 1, not retrofit.
2. ActivityKit on-device-only behavior — Phase 3 gates are device gates.
3. AX stacked row scope creep — it's one modifier + snapshots, per §7a enforcement rule.
4. Health duplicate writes — covered by healthKitUUID; test edit/delete paths explicitly.
