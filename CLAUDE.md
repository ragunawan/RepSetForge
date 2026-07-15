# CLAUDE.md — RepSetForge

Guidance for Claude Code when working on RepSetForge.

## Project Focus

RepSetForge is an iOS strength-training logger: routines, sets/reps/weight/RPE logging, rest timers, double-progression ladders, PR tracking, and Apple Health export. This is a from-scratch rebuild (July 2026) — the previous RPG/quest-XP concept has been fully retired. There is no gamification layer in this codebase; do not reintroduce quests, XP, or leveling.

**Do not** mix this with sibling projects (EggSpend, FitBoard, etc.) unless explicitly asked.

## Source of Truth

The product spec lives in `Docs/`:
- `Docs/repsetforge-dev-spec.md` — the canonical developer implementation spec: architecture, data model, screen behavior contracts, accessibility, performance/reliability rules, App Store submission checklist, and the build order.
- `Docs/repsetforge-hifi.html` — hi-fi screen mockups and component states (open in a browser). Companion to the dev spec; token values referenced there as `gymchalk-tokens.json` were not provided and are approximated in `RepSetForgeTheme.swift` from the mockup's inline CSS custom properties — reconcile if a real tokens file ever arrives.

Read the dev spec before making architectural or data-model changes. This CLAUDE.md summarizes it for quick reference; the dev spec wins on any conflict.

## Project Overview

- **Repository name:** RepSetForge
- **Xcode project:** RepSetForge.xcodeproj
- **App target:** RepSetForge (shared scheme)
- **Test target:** RepSetForgeTests
- **UI test target:** RepSetForgeUITests
- **Entry point:** RepSetForgeApp.swift in RepSetForge/ folder
- **Swift version:** Swift 6, iOS 17.0+
- **Stack:** SwiftUI + SwiftData, CloudKit-backed (private per-user iCloud sync) with automatic local fallback when no iCloud account is available. WidgetKit/ActivityKit for Live Activities (v1.0, once built), watchOS companion (v1.1, deferred — see TODO.md).
- **Monetization:** none. Free app, no IAP/paywall, no gating scaffolding.
- **Exercise database:** ships empty. Users create their own exercises; canonical-name dedup (see below) is load-bearing because every name is user-typed.

## Key Files

- `README.md` — project overview and quick start
- `TODO.md` — canonical, prioritized backlog, structured around the dev spec's "Build order" (§9); use this to decide what to work on next
- `generate_project.py` — Xcode project file generator
- `RepSetForge/Models/` — `@Model` classes: `Exercise`, `Routine`, `RoutineItem`, `ProgressionRule`, `WorkoutSession`, `SessionExercise`, `SetEntry`, `PRRecord`, `BodyMetric`, plus supporting enums (`MuscleGroup`, `Equipment`, `SetType`, `ProgressionRuleType`, `WorkoutSessionStatus`, `PRKind`)
- `RepSetForge/Services/` — `ExerciseDedupService` (canonical-name key + fuzzy match). More services land per TODO.md's build order (progression ladder engine, PR engine, rest timer manager, HealthKit export, Live Activity, CSV import/export, etc.)
- `RepSetForge/Persistence/` — `PersistenceController` (ModelContainer, CloudKit config), `RepSetForgeSchema` (`RepSetForgeSchemaV1`/`RepSetForgeMigrationPlan`)
- `RepSetForge/Views/` — screen views (Home, Library, History, Progress land per TODO.md; `RootView`/`ContentView` is the current minimal tab shell)
- `RepSetForge/Views/Components/` — reusable UI components (empty for now — populate as screens are built)
- `RepSetForge/RepSetForgeTheme.swift` — design tokens translated from the hi-fi mockup's CSS custom properties (surfaces, signal/pr/warn/destructive colors, radii, monospace type)

## Development Workflow

1. Work from **TODO.md**, top to bottom within each priority tier. TODO.md mirrors the dev spec's build order (§9) — data model first, then the Exercise Focus logging screen (the product lives or dies here), then rest timer/Live Activity, then the rest.
2. Before committing, build the app:
   ```bash
   xcodebuild build -project RepSetForge.xcodeproj -scheme RepSetForge \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
3. Run tests:
   ```bash
   xcodebuild test -project RepSetForge.xcodeproj -scheme RepSetForge \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

   Note: `xcodebuild` requires macOS + Xcode. If you're working in a Linux remote environment with no Swift/Xcode toolchain available, you cannot run these — say so explicitly rather than claiming a build passed. Review Swift syntax carefully by hand and flag anything you couldn't verify.

## Common Commands

**Build:**
```bash
xcodebuild build -project RepSetForge.xcodeproj -scheme RepSetForge \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Test:**
```bash
xcodebuild test -project RepSetForge.xcodeproj -scheme RepSetForge \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Open in Xcode:**
```bash
open RepSetForge.xcodeproj
```

**Generate Xcode project file (after changes to file structure):**
```bash
python3 generate_project.py
```

## Naming Conventions

- **Repository/folder:** RepSetForge
- **Xcode project:** RepSetForge.xcodeproj
- **App target/product/scheme:** RepSetForge
- **Test target:** RepSetForgeTests
- **UI test target:** RepSetForgeUITests
- **App entry point:** RepSetForgeApp
- **Bundle ID:** dev.gnwn.RepSetForge (see dev spec §8b for entitlement/usage-string requirements once HealthKit lands)

Weights are stored in kg as `Decimal`; unit conversion (kg/lb) is presentation-only (Settings, dev spec §6).

## Data Model (dev spec §2)

```
Exercise        id, name, muscleGroups[], secondaryMuscles[], equipment, isFavorite,
                isCustom, notes(pinned), createdAt, canonicalNameKey (dedup)
Routine         id, name, orderedItems[RoutineItem], archivedAt?, lastPerformedAt
RoutineItem     exerciseRef, order, groupID? (superset/circuit), targetSets,
                targetRepsLow/High, targetRPE?, restSeconds, note, progressionRule?
ProgressionRule type(.ladder), repRangeLow, repRangeHigh, maxQualifyingRPE, qualifyingSetsRequired, incrementKg
WorkoutSession  id, name, routineRef?, startedAt, endedAt?, notes, status(.active/.completed)
SessionExercise sessionRef, exerciseRef, order, groupID?, note
SetEntry        id, sessionExerciseRef, index, type(.warmup/.working/.drop/.failure/.bodyweight),
                weightKg?, reps?, rpe?, completedAt?, isPR:Bool (denormalized)
PRRecord        exerciseRef, kind(.bestWeight/.bestE1RM/.bestVolume/.repsAtWeight),
                value, setRef, achievedAt
BodyMetric      date, bodyweightKg, bodyFatPct?
```

- e1RM: Epley `w × (1 + r/30)`, computed property on `SetEntry`, capped at reps ≤ 12 for validity.
- `canonicalNameKey` = lowercased, punctuation-stripped name. `ExerciseDedupService` fuzzy-matches (Levenshtein ≤ 2 or token subset) against existing keys on custom-exercise creation — this is what powers the "Similar exists" row in the create-exercise flow. See dev spec §2 and the Exercise Selection screen (mockup frame 3).
- `ProgressionRule.type` is an enum so future progression methodologies (5/3/1, percentage waves, RIR autoregulation — dev spec §9 item 11, v1.1) land as new cases without a data-model migration. Only `.ladder` (double progression) is implemented for v1.0; don't add the other cases until they have real logic behind them.
- SwiftData/CloudKit requirement: every attribute must be Optional or have a default value, and to-many relationships must be Optional at the stored-property level specifically — use the private-optional-backing pattern (see `Routine.items` / `WorkoutSession.sessionExercises` for the reference implementation) even though the public accessor is non-optional.

## Design Decisions

See the dev spec for the full detail — this is a pointer, not a duplicate:
- **§1** — app architecture & navigation (`RootView` → `TabView` (Home/History/Progress/Library) + FAB, `ActiveWorkoutSheet` full-screen cover, restore-UX rules for an unfinished session)
- **§3** — the Active Workout / Exercise Focus screen (the core logging surface — one exercise per page, full-bleed, no cards; read-only Exercise Index sheet for navigation; set row behavior contract; superset handling)
- **§4 / §4b / §4c** — rest timer, Live Activity/Dynamic Island (v1.0), Apple Health export (v1.0, phone-only path first), Apple Watch companion (v1.1, deferred)
- **§7 / §7a** — accessibility (ship-blocking checklist, Dynamic Type tiers, the AX2+ stacked set row)
- **§8 / §8b** — performance/reliability contracts, App Store submission package
- **§9** — build order (this is what TODO.md is structured around)

### Visual Theme

Dark-primary, monospaced-throughout design (`Docs/repsetforge-hifi.html` "Direction A"). Signal green (`#30E585` dark / `#1FA968` light) for completion/actions/progression; gold (`#F5C542` dark / `#B8860B` light) for PRs only — never reuse gold for anything else. Warning orange for overtime/under-target states, red only for destructive actions. `RepSetForgeTheme.swift` holds the token translation from the mockup's CSS custom properties; keep new UI aligned with it rather than hardcoding colors/radii inline.

### Animation & Accessibility Baseline

- Set completion tap → visual response < 50ms (optimistic UI; persistence async, per dev spec §8).
- Respect Reduce Motion: springs → fades, no parallax.
- Dynamic Type to AX5; the six-column set table collapses to the AX2+ stacked set row per §7a — any new set-row feature must land in all three Dynamic Type tiers or it doesn't merge.
- Completed state is never color-only (icon + dim, per §7).

## Testing Requirements

Write unit tests for:
1. e1RM calculation (Epley formula, reps > 12 cap behavior)
2. `ExerciseDedupService` canonical-key generation and fuzzy matching (Levenshtein ≤ 2, token subset)
3. Progression ladder generation and level-completion logic, once the ladder engine lands (TODO.md build order step 6)
4. PR detection logic, once the PR engine lands (build order step 7)
5. Historical-edit invalidation chain (PR recompute → ladder recompute → weekly rollup invalidation → Health re-write), once editing past sessions lands — see dev spec §5 "Historical edit invalidation chain"

UI tests (RepSetForgeUITests target) should cover the core logging flow end to end through the real UI once it exists (start a workout, log a set, finish) — not yet meaningful with only a data-model foundation in place. `xcodebuild test` runs both test targets together via the shared scheme.

## Known Limitations (current state)

This is a freshly rebuilt foundation, not a feature-complete app. Current state:
- [x] SwiftData models + CloudKit-ready schema (dev spec §2)
- [x] `PersistenceController` with CloudKit config + local fallback
- [x] `ExerciseDedupService` (canonical key + fuzzy match)
- [x] `RepSetForgeTheme.swift` token translation
- [x] Minimal `RootView` tab shell (placeholder screens only — no real logging UI yet)
- [ ] Everything else in the dev spec's build order §9 — see TODO.md for the prioritized list, starting with the Exercise Focus logging screen (step 2)

## Acceptance Criteria

Not yet applicable — no MVP has shipped under this concept. TODO.md's build order stands in for acceptance criteria until v1.0 (dev spec §9, steps 1–9) is complete and ready for App Store submission (§8b).

## Code Style

- Follow existing Swift conventions
- Keep domain logic in models/services, not in views
- Use `Decimal` for weights (kg) and other precision-sensitive numeric values — never `Double` for a value a user will compare against a PR
- Keep UI changes aligned with `RepSetForgeTheme.swift` before adding one-off styling
- Comment only the non-obvious: formulas, constraints, workarounds

---

**Start here:** Read `Docs/repsetforge-dev-spec.md` in full before touching the Exercise Focus screen or the progression ladder — the behavior contracts there are detailed and load-bearing. Then read `TODO.md` and work top-down within the highest open priority tier.
