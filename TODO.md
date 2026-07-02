# Setbound TODO

Prioritized backlog for features and polish beyond the current MVP roadmap.

## P0 - Finish And Verify MVP

- [ ] Build and test the current app on the target simulator.
- [ ] Complete the manual acceptance checklist in `IMPLEMENTATION.md`.
- [ ] Verify the end-to-end flow: create quest, add exercises, log sets, complete quest, award XP, unlock achievements, and show history.
- [ ] Confirm SwiftData first-launch seeding works on a clean install and with `--preview-data`.

## P1 - Core Workout Tracking Improvements

- [ ] Exercise templates: save common exercises with default muscle groups, notes, and set schemes.
- [ ] Quest templates: create reusable workout plans such as Push Day, Pull Day, Leg Day, and Core Trial.
- [ ] Duplicate quest: start from a previous completed quest without re-entering every exercise.
- [ ] Edit or undo completed quests with XP recalculation and achievement consistency checks.
- [ ] Rest timer between sets, with configurable default durations per exercise.
- [ ] Add support for bodyweight, assisted, distance, duration, and cardio exercise types.
- [ ] Add timed exercise XP formula for planks, runs, cycling, rowing, and circuits.
- [ ] Add personal records for max weight, max reps, best volume, longest duration, and fastest pace.

## P1 - Progression And RPG Systems

- [ ] Level-up summary that clearly lists character and muscle group level changes.
- [ ] Better achievement coverage for streaks, volume, balanced training, first PR, and consistency milestones.
- [ ] Streak protection rules so rest days and late-night workouts behave predictably.
- [ ] Character titles and badges that reflect training style, not only level.
- [ ] Build analysis insights in `CharacterProgressView`, such as push/pull balance and neglected muscle groups.
- [ ] Daily or weekly quests generated from recent training history.

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
- [ ] iCloud sync once the local SwiftData model is stable.
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
- [ ] Add UI tests for the core quest logging flow.
- [ ] Add snapshot or preview coverage for major SwiftUI states.
- [ ] Add a lightweight fixture factory for tests and previews.
- [ ] Document data model invariants, especially quest completion and XP distribution rules.
