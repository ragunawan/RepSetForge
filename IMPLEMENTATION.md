# Setbound MVP — Implementation Roadmap

This file breaks down the MVP into 8 sequential tasks with clear verification steps. Work through them in order.

---

## Task 1: Write SwiftData Models

**Files to create:**
- `Setbound/Models/MuscleGroup.swift` — enum (chest, back, legs, shoulders, arms, core, cardio)
- `Setbound/Models/QuestStatus.swift` — enum (planned, active, completed)
- `Setbound/Models/ExerciseSet.swift` — @Model (setNumber, reps, weight, completed, exercise relationship)
- `Setbound/Models/Exercise.swift` — @Model (name, primary/secondary muscle groups, notes, sets, quest relationship)
- `Setbound/Models/Quest.swift` — @Model (name, date, status, exercises, totalXP, completedDate)
- `Setbound/Models/PlayerCharacter.swift` — @Model (level, currentXP, totalXP, title, completedQuestCount, createdDate)
- `Setbound/Models/MuscleProgress.swift` — @Model (muscleGroupRaw, level, currentXP, totalXP)
- `Setbound/Models/Achievement.swift` — @Model (id, name, description, unlocked, unlockedDate)

**Verification:**
- All files compile without errors
- Models have proper SwiftData relationships (Quest ↔ Exercise ↔ ExerciseSet, PlayerCharacter owns MuscleProgress)
- Enums properly convert to/from String for storage

---

## Task 2: Write ProgressionService and AchievementService

**ProgressionService.swift:**
- `setXP(reps: Int, weight: Double) → Int` — XP for one set
  - Base = reps × 2
  - Bonus = weight / 10
  - Total = base + bonus
- `questXP(exercises: [Exercise]) → Int` — total from quest
- `distributeXP(questXP: Int, exercises: [Exercise], to character: PlayerCharacter, and muscles: [MuscleProgress])`
  - Exercise's primary muscle: 100% of exercise XP
  - Exercise's secondary muscles: 40% of exercise XP
  - Overall player: 100% of total quest XP
- `levelUpIfNeeded(character: PlayerCharacter)` and `levelUpIfNeeded(muscle: MuscleProgress)`
  - nextLevelXP = currentLevel × 100
  - When XP ≥ nextLevelXP, level up and carry over excess XP
- Character titles based on level: "Novice Adventurer" (1), "Iron Trainee" (5), "Dungeon Athlete" (10), "Strength Knight" (15), "Elite Champion" (20), "Mythic Hero" (25+)

**AchievementService.swift:**
- Define all achievements (First Quest, 10 Quests, First Level Up, 7-Day Streak, 100 Sets, etc.)
- `checkAchievements(character: PlayerCharacter, muscles: [MuscleProgress], context: ModelContext) → [Achievement]`
  - Returns newly unlocked achievements to display in completion screen

**Verification:**
- XP calculation tests pass (see Task 8)
- Character title correctly reflects level
- Achievement checks work as expected

---

## Task 3: Write PersistenceController

**PersistenceController.swift:**
- Singleton with `ModelContainer` and `modelContext`
- `static let shared = PersistenceController()`
- Seed core data on first launch:
  - 1 PlayerCharacter (level 1, 0 XP)
  - 7 MuscleProgress entries (one per MuscleGroup, all level 1, 0 XP)
  - All Achievement definitions (unlocked: false)
- Optional: if `CommandLine.arguments.contains("--preview-data")`, also seed 3 sample quests with exercises
- Provide `previewContainer` for SwiftUI previews

**Sample quests (optional seeding):**
1. "Upper Body Strength" — Bench Press, Pull-Ups, Shoulder Press, Rows
2. "Leg Day Dungeon" — Squat, Romanian Deadlift, Lunges, Calf Raises
3. "Core Trial" — Plank, Hanging Knee Raise, Russian Twist

**Verification:**
- App launches and creates an empty database successfully
- Preview data option works and pre-fills sample quests
- No crashes on first run

---

## Task 4: Write SetboundTheme and Pixel-Art Components

**SetboundTheme.swift:**
- Color palette: navy, gold, silver, green, light, dark mode support
- Typography: system font + monospaced for XP numbers
- Spacing constants (padding, corner radius)
- Pixel-art visual spec: consistent border weights, squared corners, blocky fills, restrained shadows, and icon sizing

**Components to write:**
- `PixelQuestCard.swift` — card for quest preview (name, status, XP, exercise count)
- `PixelXPBar.swift` — segmented/blocky XP progress bar
- `PixelBadge.swift` — medal/badge shape for achievements
- `PixelStatPanel.swift` — character stat tile (Level 8 · Iron Trainee · 340/800 XP)
- `PixelButton.swift` — chunky bordered button for quest actions
- `PixelAchievementCard.swift` — achievement display (locked/unlocked state)
- `PixelDivider.swift` — decorative line
- `QuestCompletionRewardRow.swift` — "+420 XP · Chest +180" summary row

All components use SwiftUI shapes (RoundedRectangle, borders) and SF Symbols, **no external assets required**.

**Pixel-art requirements:**
- Quest cards, stat panels, badges, XP bars, primary buttons, and completion rewards must share one cohesive retro RPG style.
- XP bars should animate in discrete/block-like steps instead of smooth liquid fills.
- Muscle and achievement icons may use SF Symbols for MVP, but they should sit inside pixel-styled frames so placeholders still feel intentional.
- Empty states should use the same pixel-panel treatment as populated states.
- Light and dark mode should preserve the same RPG tone without losing contrast.

**Animation requirements:**
- Set completion should provide fast visual feedback, such as a brief checkmark, pulse, or XP tick.
- Quest completion should include a short celebration sequence that highlights total XP, muscle XP, level-ups, and achievements in order.
- Level-up and achievement unlock moments should feel distinct from ordinary XP gain.
- Animations must be lightweight, interruptible, and no longer than needed for workout flow.
- Respect Reduce Motion by replacing motion-heavy effects with opacity, scale, or static state changes.

**Verification:**
- All components compile and render in previews
- Theme colors work in light and dark mode
- Pixel-art styling is visible on every main surface, not only one-off components
- Animations play for set completion, quest completion, level-up, and achievement unlock states
- Reduce Motion path avoids large movement while preserving clear state feedback
- Visual QA screenshots are captured for Dashboard, Quest Detail, Character, History, Achievements, and Completion
- No crashes when used in views

---

## Task 5: Write Main App Screens

**SetboundApp.swift:**
- `@main` entry point
- Initialize `PersistenceController.shared` into environment
- Parse `--tab <index>` launch argument to select default tab

**ContentView.swift:**
- TabView with 4 tabs:
  1. Quest Board (home/dashboard)
  2. Character Progress
  3. Quest History
  4. Achievements

**Screen files to create:**

1. **QuestDashboardView.swift** — Home screen
   - Display character level, title, XP progress
   - Show today's active quest or "Begin a new quest"
   - Quick button to start new quest
   - Completed quest streak (if implemented)

2. **QuestListView.swift** — Quest list and creation
   - List of all quests (planned, active, completed)
   - "New Quest" button → QuestDetailView (new mode)
   - Tap quest → QuestDetailView (edit mode)

3. **QuestDetailView.swift** — Quest editor
   - Quest name, date
   - List of exercises
   - Add/remove exercises
   - "Complete Quest" button (if status == .active)
   - When completed, save totalXP and push to QuestCompletionView

4. **ExerciseLoggingView.swift** — Log sets for an exercise
   - Exercise name, muscle groups, notes
   - List of sets (set number, reps, weight, completed toggle)
   - Add new set button
   - Done/save button

5. **CharacterProgressView.swift** — Character sheet
   - Overall level, title, total XP
   - Total completed quests
   - Muscle group levels grid (Chest L7, Back L6, Legs L4, etc.)
   - Optional insight: "Your build is push-dominant..."

6. **QuestHistoryView.swift** — Past quests
   - Chronological list of completed quests
   - Show date, total XP, exercise count
   - Tap to view details (read-only)

7. **AchievementsView.swift** — Milestone display
   - Grid of achievement cards
   - Show locked vs. unlocked with date
   - Sorted by unlock date

8. **QuestCompletionView.swift** — Celebratory summary after quest
   - "Quest Complete: [Name]"
   - Total XP earned
   - Muscle group XP breakdown
   - Level-ups (if any)
   - Newly unlocked achievements (if any)
   - Confetti/celebratory messaging (optional animation)

**Verification:**
- All screens compile without errors
- Tab navigation works
- Can create a new quest, add exercises, log sets, complete a quest
- Quest completion screen appears after completing a quest

---

## Task 6: Wire Up Progression Logic

After screens are created, integrate ProgressionService and AchievementService:

1. In **QuestDetailView**, when user taps "Complete Quest":
   - Mark quest status as `.completed`
   - Call `ProgressionService.questXP(exercises:)` to calculate total
   - Call `ProgressionService.distributeXP(...)` to award XP to character and muscles
   - Check for level-ups with `ProgressionService.levelUpIfNeeded(...)`
   - Check for new achievements with `AchievementService.checkAchievements(...)`
   - Navigate to **QuestCompletionView** with results
   - Save to ModelContext

2. In **QuestCompletionView**, display the results from above

3. In **CharacterProgressView**, display character and muscle levels from ModelContext

**Verification:**
- Completing a quest displays earned XP correctly
- Character level increases when XP threshold is crossed
- Muscle group levels increase independently
- Achievements unlock and show in completion screen

---

## Task 7: Generate Xcode Project

**generate_project.py:**
- Adapt EggSpend's pattern for Setbound
- UUIDs follow same scheme (AA + type + sequence)
- Include all files from Tasks 1–5
- Add Models, Services, Persistence, Views, Components groups
- Include SetboundTests target with test files

**Setbound.xcodeproj:**
- Shared scheme named "Setbound"
- Set iOS target to 17.0+
- Entitlements (no CloudKit for MVP)

**Verification:**
- Run `python3 generate_project.py`
- `xcodebuild build -project Setbound.xcodeproj -scheme Setbound -destination 'platform=iOS Simulator,name=iPhone 16'` succeeds

---

## Task 8: Write Tests and Build

**Test files:**

1. **ProgressionServiceTests.swift**
   - `testSetXP()` — verify formula
   - `testQuestXP()` — sum of exercises
   - `testLevelUp()` — character levels correctly
   - `testMuscleGroupXPDistribution()` — primary 100%, secondary 40%
   - `testLevelUpIfNeeded()` — excess XP carries over

2. **AchievementServiceTests.swift**
   - `testAchievementUnlock()` — achievements unlock on correct conditions
   - `testAchievementDates()` — dates are set

3. **IntegrationTests.swift** (optional)
   - End-to-end: create quest, add exercises, log sets, complete, verify XP distribution

**Verification:**
```bash
xcodebuild test -project Setbound.xcodeproj -scheme Setbound \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

- All tests pass
- Code coverage > 70% for services

---

## Task 9: Manual Testing & Verification

Run the app in simulator and verify all acceptance criteria:

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

**Steps:**
1. Build and launch app
2. Create "Test Quest" with "Bench Press" (chest) exercise
3. Add 3 sets: (5 reps, 185 lbs), (5 reps, 185 lbs), (3 reps, 185 lbs)
4. Mark all sets complete
5. Complete quest
6. Verify:
   - Completion screen appears with XP summary
   - Character XP increased
   - Chest muscle level increased
   - Quest appears in History tab
   - Set completion feedback is immediate and unobtrusive
   - Completion animation highlights XP, level changes, and achievements clearly
   - Pixel-art styling is consistent with Dashboard, Character, History, and Achievements tabs
7. Enable Reduce Motion in simulator/device accessibility settings and repeat quest completion
8. Verify:
   - Motion-heavy effects are reduced or replaced
   - XP, level-up, and achievement state changes remain obvious
7. Repeat with a "Leg Day" quest to verify muscle levels and titles

---

## Summary

| Task | File Count | Status |
|------|-----------|--------|
| 1. Models | 8 | Done |
| 2. Services | 2 | Done |
| 3. Persistence | 1 | Done |
| 4. Theme & Components | 9 | Done |
| 5. Main Screens | 8 | Done |
| 6. Wire Progression | — | Done |
| 7. Generate Project | 1 | Done |
| 8. Tests | 3 | Done |
| 9. Manual Testing | — | Done |

**Total source files:** ~42

---

**Start with Task 1.** Each task depends on the previous one.
