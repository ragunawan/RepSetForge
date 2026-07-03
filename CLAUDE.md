# CLAUDE.md — Setbound MVP

Guidance for Claude Code when working on Setbound.

## Project Focus

Work on the Setbound codebase in `/Users/ai/Documents/Dev/Setbound`.

Setbound is an iOS app where workouts are "quests" and logging sets earns XP to level up your character and muscle groups.

**Do not** mix this with sibling projects (EggSpend, FitBoard, etc.) unless explicitly asked.

## Project Overview

- **Repository name:** Setbound
- **Xcode project:** Setbound.xcodeproj
- **App target:** Setbound (shared scheme)
- **Test target:** SetboundTests
- **Entry point:** SetboundApp.swift in Setbound/ folder
- **Swift version:** Swift 6, iOS 17.0+
- **Stack:** SwiftUI + SwiftData (local-only, no CloudKit for MVP)

## Key Files

- `README.md` — Project overview and quick start
- `TODO.md` — canonical, prioritized backlog; use this to decide what to work on next
- `generate_project.py` — Xcode project file generator (adapt EggSpend pattern)
- `Setbound/Models/` — @Model classes (Quest, Exercise, ExerciseSet, PlayerCharacter, MuscleProgress, Achievement) plus the passive-combat RPG layer (RPGClass, RPGMonster, RPGBoss, RPGSkill, RPGEquipment, RPGEncounterState, RPGProgressionSnapshot — struct/enum-based, not persisted)
- `Setbound/Services/` — ProgressionService (XP calc, leveling), AchievementService (unlock logic), and the RPG combat layer (MonsterSpawnService, BossMilestoneService, RPGEncounterViewModel, RPGMonsterRegistry, RPGBossRegistry, RPGEquipmentRegistry, RPGSkillRegistry)
- `Setbound/Persistence/` — PersistenceController (ModelContainer, seeding)
- `Setbound/Views/` — Screen views (Dashboard, QuestList, QuestDetail, ExerciseLogging, Character, History, Achievements, Completion)
- `Setbound/Views/Components/` — Pixel-art UI components (PixelQuestCard, PixelXPBar, PixelBadge, PixelStatPanel, PixelButton, PixelAchievementCard, PixelDivider, QuestCompletionRewardRow)
- `Docs/ART_GENERATION_README.md` / `ArtSource/RPG/` — manual chibi-art import pipeline for RPG sprites (see `scripts/import_rpg_art.py`)

## Development Workflow

1. Phase 1 MVP (core quest/XP/leveling loop) is complete. Work from **TODO.md**, top to bottom within each priority tier (P0 before P1 before P2, etc.). Do not skip ahead within a tier without reason.
2. Before committing, build the app:
   ```bash
   xcodebuild build -project Setbound.xcodeproj -scheme Setbound \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
3. Run tests:
   ```bash
   xcodebuild test -project Setbound.xcodeproj -scheme Setbound \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

## Common Commands

**Build:**
```bash
xcodebuild build -project Setbound.xcodeproj -scheme Setbound \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Test:**
```bash
xcodebuild test -project Setbound.xcodeproj -scheme Setbound \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Open in Xcode:**
```bash
open Setbound.xcodeproj
```

**Generate Xcode project file (after changes to file structure):**
```bash
python3 generate_project.py
```

## Naming Conventions

Use these names consistently:

- **Repository/folder:** Setbound
- **Xcode project:** Setbound.xcodeproj
- **App target/product/scheme:** Setbound
- **Test target:** SetboundTests
- **App entry point:** SetboundApp

In UI, refer to:
- Workouts as **"Quests"**
- Exercises as **"Skills"** or leave as "Exercises" (not "Encounters" in UI)
- Muscle groups as **"(Chest, Back, Legs, etc.)"**
- Character progression as **"Level" and "XP"**

## Design Decisions

### XP & Leveling Formula

**Per-set XP:**
```
base = reps × 2
bonus = weight / 10
setXP = base + bonus
```

Bodyweight exercises have weight = 0 (no bonus).

**Quest XP = sum of exercise XPs from completed sets only.**

**XP distribution on quest completion:**
- **Primary muscle:** 100% of exercise XP
- **Secondary muscles:** 40% of exercise XP
- **Overall player:** 100% of total quest XP

**Leveling:**
```
nextLevelXP = currentLevel × 100
```
Example: Level 1→2 requires 100 XP, 2→3 requires 200 XP, 3→4 requires 300 XP.

When XP exceeds the threshold, level up immediately and carry over excess XP.

### Character Titles

By level:
- 1–4: "Novice Adventurer"
- 5–9: "Iron Trainee"
- 10–14: "Dungeon Athlete"
- 15–19: "Strength Knight"
- 20–24: "Elite Champion"
- 25+: "Mythic Hero"

### Pixel-Art Theme

Use SwiftUI shapes, typography, SF Symbols, and borders — **no custom asset packs required for MVP.**

- Color palette: navy, gold, silver, green, light/dark mode aware
- Squared corners, chunky borders, retro panel styling
- XP bars with segmented/block-like appearance
- Badges shaped like RPG medals
- Icons from SF Symbols (placeholders for future custom pixel art)
- Pixel styling should appear across cards, panels, buttons, empty states, achievements, and completion rewards
- Treat pixel-art polish as part of the product feel, not as isolated decoration

**TODO:** Replace SF Symbol placeholders with hand-drawn pixel-art muscle group icons before shipping.

### Animation Feel

Animations should make progress feel rewarding while keeping workout logging fast.

- Set completion: immediate, subtle feedback such as a checkmark, pulse, or XP tick
- XP gain: brief segmented bar movement or number tick
- Level-up: distinct celebratory state change, separate from ordinary XP gain
- Achievement unlock: noticeable but short badge reveal
- Quest completion: short reward sequence for total XP, muscle XP, level-ups, and achievements
- Respect Reduce Motion by avoiding large movement and using opacity, scale, or static state changes instead
- Avoid long, blocking, or looping animations in the logging flow

### SwiftData Models

All models use `@Model` and local SwiftData only (no CloudKit for MVP).

**Relationships:**
- Quest owns Exercises (cascade delete)
- Exercise owns ExerciseSets (cascade delete)
- PlayerCharacter is a singleton (one per app)
- MuscleProgress is seeded at app startup (one per MuscleGroup)
- Achievement is seeded with all definitions at startup

## Testing Requirements

Write unit tests for:
1. XP calculation (setXP formula)
2. Leveling logic (level-up conditions, excess XP carry-over)
3. Muscle group XP distribution (primary 100%, secondary 40%)
4. Achievement unlocking (conditions and dates)

Optional: integration tests for end-to-end quest completion flow.

## Known TODOs & Limitations

See `TODO.md` for the prioritized backlog — it is the single canonical home for feature ideas and known gaps, including scope beyond Phase 1 MVP (gold/shop economy, onboarding, quest scheduling, weight units, per-skill XP). Keep this section as a pointer only; do not duplicate backlog items here.

Current limitation highlights:
- [ ] The RPG combat layer (monsters/bosses/skills/equipment) has no gold, no ownable/purchasable equipment, and no per-skill XP yet — see TODO.md P1 "Onboarding And RPG Economy"
- [ ] RPG art is mid-migration: procedural sprites were removed in favor of a manual chibi-art import pipeline; import is in progress (29/407 required PNGs imported as of this writing) — see TODO.md P0
- [ ] Real pixel-art muscle group icons and app icon polish
- [ ] Cardio/timed exercise XP support and additional exercise types
- [ ] Edit/undo completed quests with full reward recalculation (XP, gold, PRs, achievements, skills)
- [ ] No first-run onboarding flow, quest scheduling/backdating, or weight-unit (lbs/kg) support
- [ ] Export/import progress
- [ ] Apple Watch support, HealthKit, Shortcuts, and social features are post-MVP
- [ ] Detailed "build analysis" insights in CharacterProgressView

## Acceptance Criteria (Phase 1 MVP)

Phase 1 MVP is complete. The app satisfies:

1. ✓ App builds successfully
2. ✓ App is named "Setbound" in visible UI
3. ✓ User can create a quest/workout
4. ✓ User can add exercises to the quest
5. ✓ User can log sets, reps, and weight
6. ✓ User can complete a quest
7. ✓ Completing a quest awards XP
8. ✓ Overall character XP and level update correctly
9. ✓ Muscle group XP and levels update correctly
10. ✓ Completed quests appear in history
11. ✓ Quest completion screen shows earned XP and level-ups
12. ✓ Basic achievements can unlock
13. ✓ UI clearly communicates a pixel art RPG theme
14. ✓ Pixel-art styling is consistent across core screens, empty states, and reward moments
15. ✓ Set completion, XP gain, level-up, achievement, and quest completion animations polish the feel without blocking logging
16. ✓ Reduce Motion is respected for animated effects
17. ✓ Workout tracking remains fast, practical, and readable

This is a deliberately smaller scope than the original RPG-economy brief (gold, shop, inventory, per-skill XP, onboarding, quest scheduling, etc.). That remaining scope lives in `TODO.md` as post-MVP backlog, not as unmet MVP criteria.

## Code Style

- Follow existing Swift conventions (same as EggSpend if familiar)
- Keep domain logic in models/services, not in views
- Use `Decimal` for financial calculations (not applicable here, but maintain precision with large numbers if needed)
- Keep UI changes aligned with SetboundTheme.swift before adding one-off styling
- Keep animations brief, meaningful, and accessible; workout logging must remain fast
- Comment only the non-obvious: formulas, constraints, workarounds

## Launch Arguments

For testing, the app supports:

```bash
# Seed sample quests and character progression
--preview-data

# Open to a specific tab (0=Quest Board, 1=Character, 2=History, 3=Achievements)
--tab 2
```

These are parsed in SetboundApp.swift.

---

**Start here:** Phase 1 MVP is done. Read `TODO.md` and work top-down within the highest open priority tier.
