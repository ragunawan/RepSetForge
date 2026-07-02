# Setbound MVP

A pixel-art RPG-themed workout tracker for iOS. Workouts are "quests," exercises are "skills," and completing sets earns XP to level up your character and muscle groups.

**Tagline:** "Turn every workout into a quest and every rep into XP."

## Project Status

Scaffolding in progress. See `IMPLEMENTATION.md` for detailed task breakdown and verification steps.

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
│   │   ├── PlayerCharacter.swift   # @Model: level, XP, title, streak, quest count
│   │   ├── MuscleProgress.swift    # @Model: level, XP per muscle group
│   │   └── Achievement.swift       # @Model: id, name, unlocked, date
│   ├── Services/
│   │   ├── ProgressionService.swift # XP calc, leveling formula
│   │   └── AchievementService.swift # Achievement definitions & logic
│   ├── Persistence/
│   │   └── PersistenceController.swift # ModelContainer, seeding
│   ├── Views/
│   │   ├── QuestDashboardView.swift      # Home screen
│   │   ├── QuestListView.swift           # Browse/new quest
│   │   ├── QuestDetailView.swift         # Edit quest, add exercises
│   │   ├── ExerciseLoggingView.swift     # Log sets/reps/weight
│   │   ├── CharacterProgressView.swift   # Levels, titles, streaks
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
│       └── AppIcon.appiconset/
│           └── AppIcon.png
├── SetboundTests/
│   ├── ProgressionServiceTests.swift     # XP calc, leveling
│   ├── AchievementServiceTests.swift     # Unlock logic
│   └── IntegrationTests.swift            # Quest completion → XP distribution
├── Setbound.xcodeproj/
│   └── project.pbxproj
├── generate_project.py                   # Xcode project file generator
├── IMPLEMENTATION.md                     # Task breakdown & verification
└── CLAUDE.md                             # Claude Code guidance
```

## MVP Acceptance Criteria

- [x] App scaffolded and named "Setbound"
- [ ] SwiftData models created (Quest, Exercise, ExerciseSet, PlayerCharacter, MuscleProgress, Achievement)
- [ ] XP & leveling services implemented
- [ ] Core persistence & seeding working
- [ ] Main screens built (Dashboard, Quest List, Quest Detail, Exercise Logging, Character, History, Achievements, Completion)
- [ ] Pixel-art theme & components created
- [ ] Pixel-art styling verified across main screens, empty states, and reward moments
- [ ] Lightweight animations added for set completion, XP gain, level-ups, achievements, and quest completion
- [ ] Unit tests written & passing
- [ ] App builds and runs without errors
- [ ] Workout logging flow tested end-to-end
- [ ] Reduce Motion behavior verified for animated effects
- [ ] All acceptance criteria from task spec verified

See `IMPLEMENTATION.md` for detailed verification steps.

## Key Design Decisions

1. **XP Formula:** `base = reps × 2; bonus = weight / 10; total = base + bonus` per set
2. **XP Distribution:** primary muscle 100%, secondary muscles 40%, overall player 100%
3. **Leveling:** `nextLevelXP = currentLevel × 100` (level 1→2 = 100 XP, 2→3 = 200 XP, etc.)
4. **Pixel Art:** SwiftUI shapes, typography, borders, segmented XP bars, and SF Symbols in pixel-styled frames; no custom asset packs required for MVP
5. **Animations:** Quick, lightweight feedback for sets, XP gain, level-ups, achievements, and quest completion; respect Reduce Motion
6. **Persistence:** SwiftData with local-only fallback (no CloudKit for MVP)

## Known TODOs

See `TODO.md` for the prioritized backlog. Current highlights:

- Real pixel-art muscle group icons and app icon polish
- Pixel-art visual QA and animation polish across core flows
- Cardio/timed exercise XP formula and additional exercise types
- Exercise and quest templates, plus duplicate previous quest
- Undo/edit completed quest with XP recalculation
- Personal records, analytics, and training balance insights
- Export/import progress, HealthKit, Shortcuts, and Apple Watch support

---

**Next:** Finish the MVP roadmap in `IMPLEMENTATION.md`, then use `TODO.md` for post-MVP feature planning.
