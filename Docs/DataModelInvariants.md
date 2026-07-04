# Data Model Invariants

Rules the SwiftData models and progression services depend on but don't
state anywhere in one place. Written down here because they're easy to
violate silently — the compiler won't catch a broken invariant like "gold
is never negative" or "an undone quest's XP must fully disappear."

## Model relationships

- `Quest` owns `Exercise` (cascade delete) owns `ExerciseSet` (cascade
  delete). Deleting a `Quest` always deletes its exercises and their sets;
  there is no independent lifetime for either.
- `Exercise.quest` and `ExerciseSet.exercise` are the inverse (to-one) sides
  and are Optional, as SwiftData requires for any relationship's "many"
  side's inverse.
- **CloudKit constraint, not a local-SwiftData one**: to-many relationships
  (`Quest.exercises`, `Exercise.sets`) must be Optional *at the stored
  property level*, not just have a default value — a stricter rule than
  ordinary attributes. Both are implemented as a private Optional backing
  property (`exercisesStorage`/`setsStorage`) behind a public non-optional
  computed `var` of the same name, so the rest of the codebase never
  touches the underlying Optional. See `Quest.swift`/`Exercise.swift`.
- Every other CloudKit-backed attribute (all 12 `@Model` classes) must be
  Optional or have a default value; `Achievement.key` additionally lost its
  `@Attribute(.unique)` since CloudKit doesn't support unique constraints —
  uniqueness there is enforced at the application level instead, by
  `PersistenceController.seedCoreDataIfNeeded()` checking existing keys
  before inserting.
- `PlayerCharacter` and `RPGEncounterState` are singletons: exactly one row
  each, seeded once at first launch. Nothing enforces this at the schema
  level — it's an invariant every call site upholds by fetching `.first`
  rather than by any uniqueness constraint.
- `MuscleProgress` and `Achievement` are seeded once per catalog entry
  (`MuscleGroup.allCases`, `AchievementService.definitions`) and never
  duplicated — seeding always checks what already exists first.

## Quest status and completion

- `QuestStatus` is `planned` → `active` → `completed`, but only
  `completed` is a real stored decision. `planned` vs. `active` is
  **derived from the date**, not chosen: `QuestScheduler.status(for:)`
  returns `.planned` if the quest's date is in the future, `.active`
  otherwise. A quest scheduled for tomorrow that's still active status
  today will read as `.planned` in any code that recomputes it from the
  date, even if its stored `statusRaw` happens to say `.active`.
- `completedDate` is the single source of truth for "when did this
  actually happen" — used for streak calculations, chronological replay
  order in `ProgressionRebuildService`, and chart/calendar bucketing. It's
  `nil` for anything not completed. Completing a quest sets it to `.now`;
  undoing a completion sets it back to `nil`.
- A quest can be completed with **zero sets marked complete** — the
  "Complete Quest" button is only disabled when `quest.exercises.isEmpty`,
  not on set-completion state. `ProgressionService.questXP` simply sums to
  zero in that case, which is a valid, real outcome (a session logged but
  not actually performed), not an error state.
- Completing a quest is a **snapshot at that moment**: `quest.totalXP` is
  set once, from the sets completed as of that call. Nothing keeps it in
  sync afterward — the current UI simply doesn't allow editing a completed
  quest's reps/weight/sets at all (`ExerciseLoggingView`/`QuestDetailView`
  render them as plain read-only text once `quest.status == .completed`;
  only quest-level journal fields, notes and perceived effort, stay
  editable post-completion). But the underlying data has no such
  guarantee: if a completed quest's sets are ever mutated by any means
  other than the read-only UI (tests exercise this directly, and it's the
  exact scenario a future "edit completed quest" feature would introduce),
  `quest.totalXP` becomes stale until `ProgressionRebuildService.rebuild(context:)`
  recomputes it from the exercises as they exist now. Any code path that
  edits a completed quest's sets **must** trigger a rebuild afterward, or
  the displayed reward silently drifts from the actual logged content.

## XP distribution

- `ProgressionService.setXP` dispatches per `ExerciseType`:
  - `.strength`/`.bodyweight`/`.assisted`: `reps × 2 + weight(lb)/10`,
    rounded. Weight is normalized to pounds first via `WeightUnit.convert`,
    so the same lift earns identical XP regardless of which unit it was
    logged in.
  - `.duration`: `seconds / 2`, rounded.
  - `.distance`: `miles × 20`, rounded.
  - `.cardio`: distance formula + duration formula, summed.
- Only **completed** sets contribute XP (`Exercise.completedSets` filters
  on `.completed`); an exercise or quest with sets logged but not checked
  off contributes zero, not partial credit.
- Muscle XP split: the exercise's primary muscle gets 100% of the
  exercise's XP; each secondary muscle gets 40%, rounded independently
  (not scaled down further if there are multiple secondaries — three
  secondaries each get their own full 40%, this is deliberately generous,
  not a shared pool).
- Leveling is `nextLevelXP = level × 100`, applied via a `while` loop
  (`levelUpIfNeeded`) so a large XP gain can cross **multiple** level
  thresholds in one call, carrying over the remainder each time — not just
  the first threshold reached. This applies identically to character level
  and each muscle's level, independently.
- `PlayerCharacter.title` is a pure function of level
  (`ProgressionService.title(for:)`) recomputed every time `levelUpIfNeeded`
  runs — it is never hand-set independently of level, so it can't drift out
  of sync with it.

## Rebuild-from-history, not patch-in-place

`ProgressionRebuildService.rebuild(context:)` is the one and only place
derived progression (character/muscle level & XP, gold, completed-quest
count, achievements, personal records, skill XP, equipment drops) gets
recomputed, and it always recomputes **everything from zero**, then
replays every completed quest in chronological order (`completedDate`
ascending). This is deliberate: patching individual totals in place when a
quest is edited or undone risks double-counting or leaving stale XP/gold/
achievements behind that no code path would ever notice or clean up.

Concretely, every call:
1. Resets character level/XP/gold/completed-count and every muscle's
   level/XP to baseline (level 1, 0 XP).
2. Locks every achievement back to `unlocked = false, unlockedDate = nil`.
3. Deletes every `PersonalRecord` row outright (they get regenerated from
   scratch by replay, never patched).
4. Resets every `SkillProgress`'s XP/unlock state, but **not** its
   `equipped` flag — that's the player's own standing choice, and survives
   an unrelated quest's rebuild. If replay determines a skill no longer
   re-unlocks (the quest that unlocked it was edited/undone), the orphaned
   `equipped` flag is explicitly cleared afterward rather than left
   dangling on a now-locked skill.
5. Deletes every quest-drop/PR-drop `OwnedEquipment` row (matched by
   `purchaseSource`), regenerated from scratch by replay. Starter gear
   (`purchaseSource == "starter"`) and shop purchases are untouched — only
   the two deterministic-drop sources are subject to replay.
6. Replays every `completed` quest in `completedDate` order, awarding XP,
   gold, achievements, personal records, skill XP, and equipment-drop
   milestones exactly as `QuestDetailView.completeQuest()` does for a live
   completion — same functions, same order, so a rebuilt state is always
   indistinguishable from one built by real-time completions in that order.

This is called after **any** change to completed-quest history: undoing a
completion, editing a completed quest's sets, or importing quests from a
backup export. `ProgressionImportService` in particular only ever inserts
new `Quest` rows (deduped by `Quest.id`) and then calls `rebuild` — it never
tries to merge scalar totals field by field, for the same reason.

## Determinism (gold, equipment drops)

- Gold (`GoldService`) is pure arithmetic with no randomness at all:
  `1 gold/completed set + questXP/10 + 25/personal record`. Replaying the
  same history always produces the same total.
- Equipment drops (`EquipmentDropService`) look random but aren't: the item
  granted at a given milestone count is chosen by a custom FNV-1a hash
  (`stableHash`) over a seed string like `"quest-3"` or `"pr-6"` — never
  Swift's built-in `String.hashValue`, which is randomized per process
  launch and would pick a *different* item for the same milestone on every
  relaunch. Quest-milestone and PR-milestone seeds are prefixed
  differently specifically so the two milestone types never collide on the
  same hash input even at the same numeric count.
- Achievement unlocking is idempotent by construction: `unlock(_:)` guards
  on `!achievement.unlocked` before flipping it, so calling
  `checkAchievements` twice with the same state is a no-op the second time
  — critically, `unlockedDate` is never overwritten by a later call, even
  if conditions are still met and the call passes a different `at:` date.

## Schema versioning

`PersistenceController.schema` is built from `RepSetForgeSchemaV1`
(`Persistence/RepSetForgeSchema.swift`), not a flat model list, so it
carries an explicit version identifier `RepSetForgeMigrationPlan` can
track. There is only one version today (no migration stages yet) — see
that file's doc comment for the exact steps to follow when a future schema
change needs a real migration, and `PersistenceMigrationTests` for the
round-trip test pattern that migration must be verified against before
shipping.
