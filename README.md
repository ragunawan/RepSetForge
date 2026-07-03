# Setbound

A pixel-art RPG-themed workout tracker for iOS. Workouts are "quests," exercises earn XP, and completing sets levels up your character and individual muscle groups.

**Tagline:** "Turn every workout into a quest and every rep into XP."

## Project Status

Phase 1 MVP is complete: quest/exercise/set logging, XP and leveling, muscle-group progression, achievements, quest history, and a passive pixel-art RPG combat layer (monsters, bosses, skills, equipment) all work end to end. See `CLAUDE.md` for the Phase 1 acceptance criteria and `TODO.md` for what's next — including the larger RPG-economy scope (gold, shop, per-skill XP, onboarding) from the original project brief.

RPG art is currently mid-migration: procedural sprite generation was retired in favor of a manual chibi-art import pipeline (`scripts/import_rpg_art.py`). Import is in progress (29 of 407 required PNGs imported as of this writing). See `TODO.md` P0.

## Quick Start

```bash
# Generate Xcode project
python3 generate_project.py

# Build
xcodebuild build -project Setbound.xcodeproj -scheme Setbound -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests
xcodebuild test -project Setbound.xcodeproj -scheme Setbound -destination 'platform=iOS Simulator,name=iPhone 16'

# Open in Xcode
open Setbound.xcodeproj
```

**Launch arguments:**
- `--preview-data` seeds sample quests and character progression
- `--tab <0|1|2|3>` starts on a specific tab (0=Quest Board, 1=Character, 2=History, 3=Achievements)

## Directory Structure

```
Setbound/
├── Setbound/                      # Main app target
│   ├── SetboundApp.swift          # Entry point
│   ├── ContentView.swift           # Tab navigation
│   ├── SetboundTheme.swift         # Colors, fonts, styles
│   ├── Models/
│   │   ├── MuscleGroup.swift       # Enum: chest, back, legs, shoulders, arms, core, cardio
│   │   ├── QuestStatus.swift       # Enum: planned, active, completed
│   │   ├── ExerciseSet.swift       # @Model: reps, weight, completed
│   │   ├── Exercise.swift          # @Model: name, muscle groups, sets
│   │   ├── Quest.swift             # @Model: name, status, exercises, date
│   │   ├── PlayerCharacter.swift   # @Model: level, XP, title, quest count
│   │   ├── MuscleProgress.swift    # @Model: level, XP per muscle group
│   │   ├── Achievement.swift       # @Model: id, name, unlocked, date
│   │   ├── RPGClass.swift          # Hero class enum + sprite frame lookup
│   │   ├── RPGMonster.swift        # Monster definition + asset-name lookup
│   │   ├── RPGBoss.swift           # Boss definition + asset-name lookup
│   │   ├── RPGSkill.swift          # Passive-battle ability (attack/defense/magic)
│   │   ├── RPGEquipment.swift      # Level/class-gated gear flavor data
│   │   ├── RPGEncounterState.swift # Passive-battle encounter state
│   │   └── RPGProgressionSnapshot.swift # Read-only training-progress snapshot (incl. streak calc)
│   ├── Services/
│   │   ├── ProgressionService.swift    # XP calc, leveling formula
│   │   ├── AchievementService.swift    # Achievement definitions & logic
│   │   ├── MonsterSpawnService.swift   # Monster/background selection by level
│   │   ├── BossMilestoneService.swift  # Boss-fight milestone triggers
│   │   ├── RPGEncounterViewModel.swift # Drives the passive home-screen battle
│   │   ├── RPGMonsterRegistry.swift    # Monster ids and level bands
│   │   ├── RPGBossRegistry.swift       # Boss ids and backgrounds
│   │   ├── RPGEquipmentRegistry.swift  # Equipment definitions
│   │   └── RPGSkillRegistry.swift      # Skill definitions
│   ├── Persistence/
│   │   └── PersistenceController.swift # ModelContainer, seeding
│   ├── Views/
│   │   ├── QuestDashboardView.swift      # Home screen (incl. RPG combat scene)
│   │   ├── QuestListView.swift           # Browse/new quest
│   │   ├── QuestDetailView.swift         # Edit quest, add exercises
│   │   ├── ExerciseLoggingView.swift     # Log sets/reps/weight
│   │   ├── CharacterProgressView.swift   # Levels, titles
│   │   ├── QuestHistoryView.swift        # Past quests
│   │   ├── AchievementsView.swift        # Milestone list
│   │   ├── QuestCompletionView.swift     # Celebratory summary
│   │   └── Components/
│   │       ├── PixelQuestCard.swift
│   │       ├── PixelXPBar.swift
│   │       ├── PixelBadge.swift
│   │       ├── PixelStatPanel.swift
│   │       ├── PixelButton.swift
│   │       ├── PixelAchievementCard.swift
│   │       ├── PixelDivider.swift
│   │       └── QuestCompletionRewardRow.swift
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       │   └── AppIcon.png
│       └── RPG/                          # Imported chibi art (currently empty — see TODO.md P0)
├── SetboundTests/
│   ├── ProgressionServiceTests.swift     # XP calc, leveling
│   ├── AchievementServiceTests.swift     # Unlock logic
│   └── IntegrationTests.swift            # Quest completion → XP distribution
├── Setbound.xcodeproj/
│   └── project.pbxproj
├── ArtSource/RPG/                        # Hand-made RPG art source + import manifest
├── Docs/ART_GENERATION_README.md         # RPG art import pipeline spec
├── scripts/import_rpg_art.py             # Validates and imports RPG art
├── generate_project.py                   # Xcode project file generator
├── TODO.md                               # Canonical, prioritized backlog
└── CLAUDE.md                             # Claude Code guidance
```

## Phase 1 MVP — Complete

- [x] App scaffolded and named "Setbound"
- [x] SwiftData models created (Quest, Exercise, ExerciseSet, PlayerCharacter, MuscleProgress, Achievement)
- [x] XP & leveling services implemented
- [x] Core persistence & seeding working
- [x] Main screens built (Dashboard, Quest List, Quest Detail, Exercise Logging, Character, History, Achievements, Completion)
- [x] Pixel-art theme & components created
- [x] Pixel-art styling verified across main screens, empty states, and reward moments
- [x] Lightweight animations added for set completion, XP gain, level-ups, achievements, and quest completion
- [x] Unit tests written & passing
- [x] App builds and runs without errors
- [x] Workout logging flow tested end-to-end
- [x] Reduce Motion behavior verified for animated effects
- [x] Passive pixel-art RPG combat layer added to the Home scene (monsters, bosses, skills, equipment as flavor data)

See `CLAUDE.md` → Acceptance Criteria for the full checklist and `TODO.md` for everything beyond Phase 1 (RPG gold/shop economy, onboarding, quest scheduling, weight units, and more).

## Key Design Decisions

1. **XP Formula:** `base = reps × 2; bonus = weight / 10; total = base + bonus` per set
2. **XP Distribution:** primary muscle 100%, secondary muscles 40%, overall player 100%
3. **Leveling:** `nextLevelXP = currentLevel × 100` (level 1→2 = 100 XP, 2→3 = 200 XP, etc.)
4. **Pixel Art:** SwiftUI shapes, typography, borders, segmented XP bars, and SF Symbols in pixel-styled frames for core UI; the RPG combat layer (monsters/bosses/heroes/equipment/backgrounds) uses imported hand-made chibi art instead of SF Symbols — see `Docs/ART_GENERATION_README.md`
5. **Animations:** Quick, lightweight feedback for sets, XP gain, level-ups, achievements, and quest completion; respect Reduce Motion
6. **Persistence:** SwiftData, local-only (no CloudKit) for Phase 1 MVP; iCloud sync is tracked as post-MVP in `TODO.md`

## Known TODOs

See `TODO.md` for the prioritized backlog — it is the single source of truth. Current highlights:

- Finish importing RPG art (29/407 required PNGs imported as of this writing)
- Gold currency, ownable/purchasable equipment, a shop, and per-skill XP tied to real training
- First-run onboarding flow and pounds/kilograms unit support
- Exercise and quest templates, quest scheduling/backdating, and duplicate previous quest
- Undo/edit completed quest with full reward recalculation
- Personal records, analytics, and training balance insights
- Export/import progress, HealthKit, Shortcuts, and Apple Watch support

---

**Next:** Work through `TODO.md` starting with the highest open priority tier (P0 before P1, etc.).
