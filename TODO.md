# SetCraft TODO

Prioritized backlog for features and polish beyond Phase 1 MVP (see `CLAUDE.md` → Acceptance Criteria). This is also the canonical home for scope from the original RPG-economy brief — gold, shop, onboarding, per-skill XP, quest scheduling, and more — that goes beyond Phase 1 MVP and isn't built yet.

## P0 - Finish And Verify Phase 1 MVP

- [x] Build and test the current app on the target simulator. (iPhone 16 unavailable in this environment; built/tested against iPhone 17 — build and all 25 tests pass.)
- [x] Complete the manual acceptance checklist (see `CLAUDE.md` → Acceptance Criteria). (Verified visually via screenshots: app name, pixel RPG theme, tab navigation, empty/seeded states. Items requiring live tap interaction were verified via `IntegrationTests.testQuestCompletionFlow()` instead — no UI-automation tooling, e.g. idb/XCUITest, is available in this environment. Recommend a manual pass in Xcode for the Reduce Motion and animation-feel checks specifically.)
- [x] Verify the end-to-end flow: create quest, add exercises, log sets, complete quest, award XP, unlock achievements, and show history. (Confirmed via passing `IntegrationTests.testQuestCompletionFlow()`.)
- [x] Confirm SwiftData first-launch seeding works on a clean install and with `--preview-data`. (Verified both: clean install shows Level 1/0 XP/no active quest with no crash; `--preview-data` seeds "Upper Body Strength" sample quest correctly.)
- [x] **Finish the manual chibi RPG art import.** All 407 required PNGs are now imported (`python3 scripts/import_rpg_art.py` reports 0 missing). Verified every `spriteAsset`/`rpg_bg_*`/`rpg_equip_*`/`rpg_skill_*` reference in code resolves to an imageset in `Assets.xcassets/RPG` (24 monsters, 5 bosses, 5 hero classes × idle/walk/attack/cast, 9 backgrounds, 8 equipment, 8 skills — all present), build succeeds with a clean asset-catalog link, and the Home scene renders the field background + knight sprite correctly in the simulator.

## P1 - Core Workout Tracking Improvements

- [x] Exercise templates: save common exercises with default muscle groups, notes, and set schemes. (Added `ExerciseTemplate` SwiftData model and `ExerciseTemplateService` for building an `Exercise` + prefilled `ExerciseSet`s from a template's default scheme, and vice versa. `AddExerciseSheet` (QuestDetailView.swift) gained a "Load Template" picker, a "Default Set Scheme" section with a "Save as Template" toggle, and a "Manage Templates" sheet for deleting saved templates. Covered by `ExerciseTemplateServiceTests`; build and all 29 tests pass. Not manually tap-tested in the simulator — no UI-automation tooling available in this environment, see other TODO notes.)
- [ ] Quest templates: create reusable workout plans such as Push Day, Pull Day, Leg Day, and Core Trial.
- [ ] Duplicate quest: start from a previous completed quest without re-entering every exercise.
- [ ] Quest scheduling: allow creating a quest for today, a future date, or a past date (backdating a workout logged after the fact).
- [ ] Edit or undo completed quests with full reward recalculation (XP, gold, muscle/skill levels, PRs, achievements) and no duplicate rewards — prefer rebuilding derived progression from completed-quest history over patching old totals in place.
- [ ] Rest timer between sets, with configurable default durations per exercise; must not slow down set logging.
- [ ] Add support for bodyweight, assisted, distance, duration, and cardio exercise types.
- [ ] Add timed exercise XP formula for planks, runs, cycling, rowing, and circuits.
- [ ] Add personal records for max weight, max reps, best volume, longest duration, and fastest pace (also the basis for PR bonus gold once the economy below exists).
- [ ] Weight units: support pounds and kilograms on `ExerciseSet`, selected during onboarding, applied consistently through logging and history; keep unit formatting isolated so kg support doesn't confuse historical entries.

## P1 - Onboarding And RPG Economy

Full-economy scope from the original RPG brief: gold, ownable/purchasable equipment, and skills that level from real training instead of just character level. `RPGSkill` and `RPGEquipment` already exist as static, level/class-gated flavor data (`SetCraft/Models/RPGSkill.swift`, `RPGEquipment.swift`) — extend them rather than replacing them.

- [ ] First-run onboarding flow: introduce SetCraft's concept, seed default player/muscle/skill/achievement/equipment state exactly once, and let the user choose pounds or kilograms.
- [ ] Add `gold` to `PlayerCharacter` and award it deterministically: small amount per completed set, larger amount per completed quest, bonus on PRs (e.g. totalXP / 10 gold per quest, +25 gold per PR).
- [ ] Turn `RPGEquipment` into an owned/persisted model (owned + equipped booleans, purchase source) instead of pure static data.
- [ ] Build an Equipment/Shop screen: browse purchasable items, buy with gold, equip/unequip per slot, insufficient-gold and already-owned states, level/rarity gating.
- [ ] Turn `RPGSkill` progression into real XP: primary muscle-group XP grants 100% related skill XP, secondary muscle-group XP grants 40%, PRs grant skill XP bonuses — instead of skills unlocking purely from character level.
- [ ] Deterministic, occasional equipment drops from completed quests / PR milestones (e.g. every 3 completed quests) — must be idempotent on rebuild/replay, not random per-tap.
- [ ] Add a Gear/Shop tab to `ContentView` once the shop screen exists; update the `--tab` launch-argument indices and their documentation in `CLAUDE.md` / `README.md` accordingly.
- [ ] Equipped skill loadout: let the user choose which unlocked skill per category (attack/defense/magic) drives passive battles, instead of always auto-selecting the highest-level one.

## P1 - Progression And RPG Systems

- [ ] Level-up summary that clearly lists character and muscle group level changes.
- [ ] Better achievement coverage for streaks, volume, balanced training, first PR, and consistency milestones.
- [ ] Streak protection rules so rest days and late-night workouts behave predictably. (Base consecutive-day streak calculation already exists in `RPGProgressionSnapshot.streak` — this item is about edge cases, not the base feature.)
- [ ] Character titles and badges that reflect training style, not only level.
- [ ] Build analysis insights in `CharacterProgressView`, such as push/pull balance and neglected muscle groups.
- [ ] Daily or weekly quests generated from recent training history.
- [ ] Expand the monster/boss pool and add more background scenes as level ranges grow (see `RPGMonsterRegistry`, `RPGBossRegistry`).

## P2 - History, Analytics, And Recovery

- [ ] Calendar view for completed quests.
- [ ] Weekly and monthly XP, volume, and consistency charts.
- [ ] Muscle group heatmap showing recent training load and recovery balance.
- [ ] Quest search and filters by date, muscle group, exercise, status, and XP.
- [ ] Notes and perceived effort on quests and individual exercises.
- [ ] Deload or recovery recommendations based on recent volume and streak patterns.

## P2 - UX And Visual Polish

- [ ] Replace SF Symbol muscle placeholders with custom pixel-art muscle icons.
- [ ] Replace generated app icon with a hand-drawn pixel-art icon before shipping.
- [ ] Define a pixel-art visual spec: palette, border weights, corner radius, shadows, icon grid size, and typography usage.
- [ ] Apply pixel-art polish consistently across quest cards, stat panels, badges, XP bars, buttons, empty states, and completion rewards.
- [ ] Add lightweight set-complete, XP-gain, level-up, achievement-unlock, and quest-complete animations.
- [ ] Ensure animations respect Reduce Motion and never block fast workout logging.
- [ ] Add a visual QA checklist with simulator screenshots for Dashboard, Quest Detail, Character, History, Achievements, and Completion.
- [ ] Improve empty states for first launch, no history, and locked achievements.
- [ ] Add accessibility pass: Dynamic Type, VoiceOver labels, contrast, and large tap targets.
- [ ] Add haptics for set completion, level up, achievement unlock, and quest completion.

## P2 - Data Portability And Integrations

- [ ] Export progress to JSON or CSV.
- [ ] Import progress from a previous export with conflict handling.
- [ ] HealthKit integration for workout sessions, active energy, heart rate, and body metrics.
- [ ] Shortcuts/App Intents for starting a quest, logging a set, and viewing current level.
- [ ] iCloud sync once the local SwiftData model is stable. (The original RPG-economy brief asked for iCloud-backed persistence as a baseline requirement; deferred here since Phase 1 MVP is explicitly local-only per `CLAUDE.md`.)
- [ ] Privacy settings and clear local-data explanation.

## P3 - Platform Expansion

- [ ] Apple Watch companion for fast set logging and timers.
- [ ] Widgets for streak, active quest, and current level.
- [ ] Live Activity for active workouts and rest timers.
- [ ] iPad layout with denser dashboards and side-by-side quest editing.
- [ ] Multiplayer or guild features: shared challenges, friend leaderboards, and party quests.

## Technical Debt And Quality

- [ ] Add migration tests before changing SwiftData model schemas.
- [ ] Expand service tests for XP recalculation, completed quest edits, streak edge cases, and achievement idempotency.
- [ ] Add tests for gold/reward determinism, equipment ownership rules, and skill XP mapping once the RPG economy above is built.
- [ ] Add UI tests for the core quest logging flow.
- [ ] Add snapshot or preview coverage for major SwiftUI states.
- [ ] Add a lightweight fixture factory for tests and previews.
- [ ] Document data model invariants, especially quest completion and XP distribution rules.
