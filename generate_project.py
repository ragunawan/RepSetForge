#!/usr/bin/env python3
"""Generates RepSetForge.xcodeproj/project.pbxproj"""

import os

# ── UUID scheme: AA + type_hex + 18 zeros + 2-digit sequence ──────────────
# type 0=project, 1=file refs, 2=build files, 3=groups
# type 4=targets, 5=config lists, 6=build configs, 7=build phases, 9=deps

def u(type_hex, seq):
    return f"AA0{type_hex}000000000000000000{seq:02X}"

# ── UUIDs ──────────────────────────────────────────────────────────────────
PROJECT = u(0, 0x01)

# File references
FR = {
    "RepSetForgeApp":            u(1, 0x01),
    "ContentView":             u(1, 0x02),
    "RepSetForgeTheme":          u(1, 0x03),
    "MuscleGroup":             u(1, 0x04),
    "QuestStatus":             u(1, 0x05),
    "ExerciseSet":             u(1, 0x06),
    "Exercise":                u(1, 0x07),
    "Quest":                   u(1, 0x08),
    "PlayerCharacter":         u(1, 0x09),
    "MuscleProgress":          u(1, 0x0A),
    "Achievement":             u(1, 0x0B),
    "ProgressionService":      u(1, 0x0C),
    "AchievementService":      u(1, 0x0D),
    "PersistenceController":   u(1, 0x0E),
    "QuestDashboardView":      u(1, 0x0F),
    "QuestListView":           u(1, 0x10),
    "QuestDetailView":         u(1, 0x11),
    "ExerciseLoggingView":     u(1, 0x12),
    "CharacterProgressView":   u(1, 0x13),
    "QuestHistoryView":        u(1, 0x14),
    "AchievementsView":        u(1, 0x15),
    "QuestCompletionView":     u(1, 0x16),
    "PixelQuestCard":          u(1, 0x17),
    "PixelXPBar":              u(1, 0x18),
    "PixelBadge":              u(1, 0x19),
    "PixelStatPanel":          u(1, 0x1A),
    "PixelButton":             u(1, 0x1B),
    "PixelAchievementCard":    u(1, 0x1C),
    "PixelDivider":            u(1, 0x1D),
    "QuestCompletionRewardRow": u(1, 0x1E),
    "Assets":                  u(1, 0x1F),
    "PROD_APP":                u(1, 0x20),  # RepSetForge.app
    "PROD_TEST":               u(1, 0x21),  # RepSetForgeTests.xctest
    "TEST_Progression":        u(1, 0x22),
    "TEST_Achievement":        u(1, 0x23),
    "TEST_Integration":        u(1, 0x24),
    "RPGClass":                u(1, 0x25),
    "RPGEquipment":            u(1, 0x26),
    "RPGSkill":                u(1, 0x27),
    "RPGMonster":              u(1, 0x28),
    "RPGBoss":                 u(1, 0x29),
    "RPGProgressionSnapshot":  u(1, 0x2A),
    "RPGEncounterState":       u(1, 0x2B),
    "RPGMonsterRegistry":      u(1, 0x2C),
    "RPGBossRegistry":         u(1, 0x2D),
    "RPGEquipmentRegistry":    u(1, 0x2E),
    "RPGSkillRegistry":        u(1, 0x2F),
    "MonsterSpawnService":     u(1, 0x30),
    "BossMilestoneService":    u(1, 0x31),
    "RPGEncounterViewModel":   u(1, 0x32),
    "RPGSpriteView":           u(1, 0x33),
    "RPGSceneView":            u(1, 0x34),
    "TEST_RPGSpawn":           u(1, 0x35),
    "TEST_RPGBoss":            u(1, 0x36),
    "ExerciseTemplate":        u(1, 0x37),
    "ExerciseTemplateService": u(1, 0x38),
    "TEST_ExerciseTemplate":   u(1, 0x39),
    "QuestTemplate":           u(1, 0x3A),
    "QuestTemplateService":    u(1, 0x3B),
    "TEST_QuestTemplate":      u(1, 0x3C),
    "QuestDuplicationService": u(1, 0x3D),
    "TEST_QuestDuplication":   u(1, 0x3E),
    "QuestScheduler":          u(1, 0x3F),
    "TEST_QuestScheduler":     u(1, 0x40),
    "ProgressionRebuildService": u(1, 0x41),
    "TEST_ProgressionRebuild": u(1, 0x42),
    "ExerciseType":            u(1, 0x43),
    "TEST_ExerciseType":       u(1, 0x44),
    "PersonalRecordType":      u(1, 0x45),
    "PersonalRecord":          u(1, 0x46),
    "PersonalRecordService":   u(1, 0x47),
    "TEST_PersonalRecord":     u(1, 0x48),
    "WeightUnit":              u(1, 0x49),
    "TEST_WeightUnit":         u(1, 0x4A),
    "OnboardingView":          u(1, 0x4B),
    "GoldService":             u(1, 0x4C),
    "TEST_GoldService":        u(1, 0x4D),
    "OwnedEquipment":          u(1, 0x4E),
    "RPGEquipmentService":     u(1, 0x4F),
    "TEST_RPGEquipment":       u(1, 0x50),
    "EquipmentShopView":       u(1, 0x51),
    "SkillProgress":           u(1, 0x52),
    "SkillProgressionService": u(1, 0x53),
    "TEST_SkillProgression":   u(1, 0x54),
    "EquipmentDropService":    u(1, 0x55),
    "TEST_EquipmentDrop":      u(1, 0x56),
    "TrainingStyle":           u(1, 0x57),
    "TrainingStyleService":    u(1, 0x58),
    "TEST_TrainingStyle":      u(1, 0x59),
    "TrainingInsightsService": u(1, 0x5A),
    "TEST_TrainingInsights":   u(1, 0x5B),
    "SuggestedQuestService":   u(1, 0x5C),
    "TEST_SuggestedQuest":     u(1, 0x5D),
    "QuestCalendarService":    u(1, 0x5E),
    "TEST_QuestCalendar":      u(1, 0x5F),
    "QuestCalendarView":       u(1, 0x60),
    "TrainingChartsService":   u(1, 0x61),
    "TEST_TrainingCharts":     u(1, 0x62),
    "TrainingChartsView":      u(1, 0x63),
    "MuscleRecoveryService":   u(1, 0x64),
    "TEST_MuscleRecovery":     u(1, 0x65),
    "QuestFilterService":      u(1, 0x66),
    "TEST_QuestFilter":        u(1, 0x67),
    "PerceivedEffortPicker":   u(1, 0x68),
    "TEST_QuestJournal":       u(1, 0x69),
    "RecoveryRecommendationService": u(1, 0x6A),
    "TEST_RecoveryRecommendation":   u(1, 0x6B),
    "ExerciseNameSuggestionService": u(1, 0x6C),
    "TEST_ExerciseNameSuggestion":   u(1, 0x6D),
    "ExerciseMetricsService":        u(1, 0x6E),
    "TEST_ExerciseMetrics":          u(1, 0x6F),
    "ExerciseMetricsView":           u(1, 0x70),
    "ProgressExportService":         u(1, 0x71),
    "TEST_ProgressExport":           u(1, 0x72),
    "ProgressImportService":         u(1, 0x73),
    "TEST_ProgressImport":           u(1, 0x74),
    "HealthKitService":              u(1, 0x75),
    "TEST_HealthKitService":         u(1, 0x76),
    "AppIntentService":              u(1, 0x77),
    "TEST_AppIntentService":         u(1, 0x78),
    "RepSetForgeShortcuts":          u(1, 0x79),
    "PrivacyDataService":            u(1, 0x7A),
    "TEST_PrivacyDataService":       u(1, 0x7B),
    "RepSetForgeSchema":             u(1, 0x7C),
    "TEST_PersistenceMigration":     u(1, 0x7D),
    "PROD_UITEST":                   u(1, 0x7E),  # RepSetForgeUITests.xctest
    "UITEST_QuestLogging":           u(1, 0x7F),
    "Fixtures":                      u(1, 0x80),
    "TEST_Fixtures":                 u(1, 0x81),
    "RepSetForgeWatchApp":           u(1, 0x82),
    "WatchQuestView":                u(1, 0x83),
    "WatchExerciseView":             u(1, 0x84),
    "WatchTheme":                    u(1, 0x85),
    "PROD_WATCH":                    u(1, 0x86),  # RepSetForge Watch App.app
    "WatchEntitlements":             u(1, 0x87),
    "WatchAssets":                   u(1, 0x99),
    "SharedStore":                   u(1, 0x88),
    "StreakService":                 u(1, 0x89),
    "TEST_StreakService":            u(1, 0x8A),
    "RepSetForgeWidgetEntry":        u(1, 0x8B),
    "RepSetForgeWidgetProvider":     u(1, 0x8C),
    "RepSetForgeWidgetView":         u(1, 0x8D),
    "RepSetForgeWidget":             u(1, 0x8E),
    "RepSetForgeWidgetBundle":       u(1, 0x8F),
    "PROD_WIDGET":                   u(1, 0x90),  # RepSetForgeWidgets.appex
    "WidgetEntitlements":            u(1, 0x91),
    "WidgetInfoPlist":               u(1, 0x92),
    "RepSetForgeActivityAttributes": u(1, 0x93),
    "LiveActivityService":           u(1, 0x94),
    "RepSetForgeLiveActivity":       u(1, 0x95),
    "LeaderboardService":            u(1, 0x96),
    "LeaderboardView":               u(1, 0x97),
    "TEST_LeaderboardService":       u(1, 0x98),
}

# ── watchOS companion app ──────────────────────────────────────────────────
# The watch app shares the @Model classes, their supporting enums, the
# versioned schema, AchievementService (a dependency of Fixtures), and
# Fixtures itself with the phone app target — same source files, compiled a
# second time into a second target. It deliberately does NOT share
# RepSetForgeTheme.swift (built on UIColor, unavailable on watchOS) or
# PersistenceController.swift (its seeding logic must run on the phone only
# — see RepSetForgeWatchApp.swift's doc comment for why).
WATCH_APP_SOURCES = [
    ("RepSetForgeWatchApp", "RepSetForge Watch App/RepSetForgeWatchApp.swift"),
    ("WatchQuestView", "RepSetForge Watch App/WatchQuestView.swift"),
    ("WatchExerciseView", "RepSetForge Watch App/WatchExerciseView.swift"),
    ("WatchTheme", "RepSetForge Watch App/WatchTheme.swift"),
]

WATCH_SHARED_KEYS = [
    "Quest", "Exercise", "ExerciseSet", "ExerciseTemplate", "QuestTemplate",
    "PlayerCharacter", "MuscleProgress", "Achievement", "PersonalRecord",
    "RPGEncounterState", "OwnedEquipment", "SkillProgress",
    "QuestStatus", "MuscleGroup", "ExerciseType", "WeightUnit", "PersonalRecordType", "RPGClass",
    "RepSetForgeSchema", "Fixtures", "AchievementService",
]

# A file reference can be compiled into more than one target, but each
# target's Sources phase needs its own PBXBuildFile entry pointing at that
# same reference — these are the watch target's second set, in a UUID range
# that can't collide with the per-FR-key `BF` dict below.
BF_WATCH_SHARED = {k: u(2, 0xA0 + i) for i, k in enumerate(WATCH_SHARED_KEYS)}
BF_EMBED_WATCH = u(2, 0xF0)  # the "Embed Watch Content" copy-files entry, distinct from PROD_WATCH's own file reference

# ── Widget/Live Activity extension ─────────────────────────────────────────
# Reads the App Group–shared store directly (see SharedStore.swift) rather
# than syncing via CloudKit itself, since a widget's timeline provider runs
# under a strict execution budget — a CloudKit round-trip could time out.
WIDGET_APP_SOURCES = [
    ("RepSetForgeWidgetEntry", "RepSetForgeWidgets/RepSetForgeWidgetEntry.swift"),
    ("RepSetForgeWidgetProvider", "RepSetForgeWidgets/RepSetForgeWidgetProvider.swift"),
    ("RepSetForgeWidgetView", "RepSetForgeWidgets/RepSetForgeWidgetView.swift"),
    ("RepSetForgeWidget", "RepSetForgeWidgets/RepSetForgeWidget.swift"),
    ("RepSetForgeWidgetBundle", "RepSetForgeWidgets/RepSetForgeWidgetBundle.swift"),
    ("RepSetForgeLiveActivity", "RepSetForgeWidgets/RepSetForgeLiveActivity.swift"),
]

WIDGET_SHARED_KEYS = [
    "Quest", "Exercise", "ExerciseSet", "ExerciseTemplate", "QuestTemplate",
    "PlayerCharacter", "MuscleProgress", "Achievement", "PersonalRecord",
    "RPGEncounterState", "OwnedEquipment", "SkillProgress",
    "QuestStatus", "MuscleGroup", "ExerciseType", "WeightUnit", "PersonalRecordType", "RPGClass",
    "RepSetForgeSchema", "SharedStore", "StreakService", "RepSetForgeActivityAttributes",
]

BF_WIDGET_SHARED = {k: u(2, 0xC8 + i) for i, k in enumerate(WIDGET_SHARED_KEYS)}
BF_EMBED_WIDGET = u(2, 0xF1)  # the "Embed Foundation Extensions"/PlugIns copy-files entry

# Build files
BF = {k: u(2, i + 1) for i, k in enumerate(FR.keys()) if not k.startswith("PROD_")}

# Groups
GR = {
    "Root":       u(3, 0x01),
    "Products":   u(3, 0x02),
    "RepSetForge":   u(3, 0x03),
    "Models":     u(3, 0x04),
    "Views":      u(3, 0x05),
    "Components": u(3, 0x06),
    "Services":   u(3, 0x07),
    "Persistence": u(3, 0x08),
    "Tests":      u(3, 0x09),
    "UITests":    u(3, 0x0A),
    "Testing":    u(3, 0x0B),
    "WatchApp":   u(3, 0x0C),
    "WidgetApp":  u(3, 0x0D),
}

# Targets
TG_APP    = u(4, 0x01)
TG_TEST   = u(4, 0x02)
TG_UITEST = u(4, 0x03)
TG_WATCH  = u(4, 0x04)
TG_WIDGET = u(4, 0x05)

# Config lists
CL_PROJECT = u(5, 0x01)
CL_APP     = u(5, 0x02)
CL_TEST    = u(5, 0x03)
CL_UITEST  = u(5, 0x04)
CL_WATCH   = u(5, 0x05)
CL_WIDGET  = u(5, 0x06)

# Build configurations
BC_PROJ_DBG   = u(6, 0x01)
BC_PROJ_REL   = u(6, 0x02)
BC_APP_DBG    = u(6, 0x03)
BC_APP_REL    = u(6, 0x04)
BC_TEST_DBG   = u(6, 0x05)
BC_TEST_REL   = u(6, 0x06)
BC_UITEST_DBG = u(6, 0x07)
BC_UITEST_REL = u(6, 0x08)
BC_WATCH_DBG  = u(6, 0x09)
BC_WATCH_REL  = u(6, 0x0A)
BC_WIDGET_DBG = u(6, 0x0B)
BC_WIDGET_REL = u(6, 0x0C)

# Build phases
BP_APP_SRC    = u(7, 0x01)
BP_APP_RES    = u(7, 0x02)
BP_APP_FRM    = u(7, 0x03)
BP_TEST_SRC   = u(7, 0x04)
BP_TEST_FRM   = u(7, 0x05)
BP_UITEST_SRC = u(7, 0x06)
BP_UITEST_FRM = u(7, 0x07)
BP_WATCH_SRC  = u(7, 0x08)
BP_WATCH_FRM  = u(7, 0x09)
BP_WATCH_RES  = u(7, 0x0E)
BP_EMBED_WATCH = u(7, 0x0A)  # "Embed Watch Content" copy-files phase, on the iOS app target
BP_WIDGET_SRC = u(7, 0x0B)
BP_WIDGET_FRM = u(7, 0x0C)
BP_EMBED_WIDGET = u(7, 0x0D)  # PlugIns copy-files phase, on the iOS app target

# Dependencies / proxy
TD_TEST   = u(9, 0x01)
CI_TEST   = u(9, 0x02)
TD_UITEST = u(9, 0x03)
CI_UITEST = u(9, 0x04)
TD_WATCH  = u(9, 0x05)
CI_WATCH  = u(9, 0x06)
TD_WIDGET = u(9, 0x07)
CI_WIDGET = u(9, 0x08)

# ── App source files (path relative to RepSetForge/ folder) ──────────────────
APP_SOURCES = [
    ("RepSetForgeApp",          "RepSetForgeApp.swift"),
    ("ContentView",           "ContentView.swift"),
    ("RepSetForgeTheme",        "RepSetForgeTheme.swift"),
    ("MuscleGroup",           "Models/MuscleGroup.swift"),
    ("WeightUnit",            "Models/WeightUnit.swift"),
    ("QuestStatus",           "Models/QuestStatus.swift"),
    ("ExerciseType",          "Models/ExerciseType.swift"),
    ("ExerciseSet",           "Models/ExerciseSet.swift"),
    ("Exercise",              "Models/Exercise.swift"),
    ("ExerciseTemplate",      "Models/ExerciseTemplate.swift"),
    ("Quest",                 "Models/Quest.swift"),
    ("QuestTemplate",         "Models/QuestTemplate.swift"),
    ("PlayerCharacter",       "Models/PlayerCharacter.swift"),
    ("MuscleProgress",        "Models/MuscleProgress.swift"),
    ("Achievement",           "Models/Achievement.swift"),
    ("PersonalRecordType",    "Models/PersonalRecordType.swift"),
    ("TrainingStyle",         "Models/TrainingStyle.swift"),
    ("PersonalRecord",        "Models/PersonalRecord.swift"),
    ("ProgressionService",    "Services/ProgressionService.swift"),
    ("AchievementService",    "Services/AchievementService.swift"),
    ("ExerciseTemplateService", "Services/ExerciseTemplateService.swift"),
    ("QuestTemplateService",  "Services/QuestTemplateService.swift"),
    ("QuestDuplicationService", "Services/QuestDuplicationService.swift"),
    ("QuestScheduler",        "Services/QuestScheduler.swift"),
    ("ProgressionRebuildService", "Services/ProgressionRebuildService.swift"),
    ("PersonalRecordService", "Services/PersonalRecordService.swift"),
    ("TrainingStyleService",  "Services/TrainingStyleService.swift"),
    ("TrainingInsightsService", "Services/TrainingInsightsService.swift"),
    ("SuggestedQuestService", "Services/SuggestedQuestService.swift"),
    ("QuestCalendarService", "Services/QuestCalendarService.swift"),
    ("TrainingChartsService", "Services/TrainingChartsService.swift"),
    ("MuscleRecoveryService", "Services/MuscleRecoveryService.swift"),
    ("QuestFilterService", "Services/QuestFilterService.swift"),
    ("RecoveryRecommendationService", "Services/RecoveryRecommendationService.swift"),
    ("ExerciseNameSuggestionService", "Services/ExerciseNameSuggestionService.swift"),
    ("ExerciseMetricsService", "Services/ExerciseMetricsService.swift"),
    ("ProgressExportService", "Services/ProgressExportService.swift"),
    ("ProgressImportService", "Services/ProgressImportService.swift"),
    ("HealthKitService", "Services/HealthKitService.swift"),
    ("AppIntentService", "Services/AppIntentService.swift"),
    ("RepSetForgeShortcuts", "Services/RepSetForgeShortcuts.swift"),
    ("PrivacyDataService", "Services/PrivacyDataService.swift"),
    ("RepSetForgeActivityAttributes", "Services/RepSetForgeActivityAttributes.swift"),
    ("LiveActivityService", "Services/LiveActivityService.swift"),
    ("LeaderboardService", "Services/LeaderboardService.swift"),
    ("GoldService",           "Services/GoldService.swift"),
    ("PersistenceController", "Persistence/PersistenceController.swift"),
    ("RepSetForgeSchema", "Persistence/RepSetForgeSchema.swift"),
    ("SharedStore", "Persistence/SharedStore.swift"),
    ("StreakService", "Services/StreakService.swift"),
    ("Fixtures", "Testing/Fixtures.swift"),
    ("OnboardingView",        "Views/OnboardingView.swift"),
    ("EquipmentShopView",     "Views/EquipmentShopView.swift"),
    ("QuestDashboardView",    "Views/QuestDashboardView.swift"),
    ("QuestListView",         "Views/QuestListView.swift"),
    ("QuestDetailView",       "Views/QuestDetailView.swift"),
    ("ExerciseLoggingView",   "Views/ExerciseLoggingView.swift"),
    ("CharacterProgressView", "Views/CharacterProgressView.swift"),
    ("QuestHistoryView",      "Views/QuestHistoryView.swift"),
    ("ExerciseMetricsView",   "Views/ExerciseMetricsView.swift"),
    ("QuestCalendarView",     "Views/QuestCalendarView.swift"),
    ("TrainingChartsView",    "Views/TrainingChartsView.swift"),
    ("AchievementsView",      "Views/AchievementsView.swift"),
    ("LeaderboardView",       "Views/LeaderboardView.swift"),
    ("QuestCompletionView",   "Views/QuestCompletionView.swift"),
    ("PixelQuestCard",        "Views/Components/PixelQuestCard.swift"),
    ("PixelXPBar",            "Views/Components/PixelXPBar.swift"),
    ("PixelBadge",            "Views/Components/PixelBadge.swift"),
    ("PixelStatPanel",        "Views/Components/PixelStatPanel.swift"),
    ("PixelButton",           "Views/Components/PixelButton.swift"),
    ("PixelAchievementCard",  "Views/Components/PixelAchievementCard.swift"),
    ("PixelDivider",          "Views/Components/PixelDivider.swift"),
    ("QuestCompletionRewardRow", "Views/Components/QuestCompletionRewardRow.swift"),
    ("RPGClass",              "Models/RPGClass.swift"),
    ("RPGEquipment",          "Models/RPGEquipment.swift"),
    ("OwnedEquipment",        "Models/OwnedEquipment.swift"),
    ("RPGSkill",              "Models/RPGSkill.swift"),
    ("SkillProgress",         "Models/SkillProgress.swift"),
    ("RPGMonster",            "Models/RPGMonster.swift"),
    ("RPGBoss",               "Models/RPGBoss.swift"),
    ("RPGProgressionSnapshot", "Models/RPGProgressionSnapshot.swift"),
    ("RPGEncounterState",     "Models/RPGEncounterState.swift"),
    ("RPGMonsterRegistry",    "Services/RPGMonsterRegistry.swift"),
    ("RPGBossRegistry",       "Services/RPGBossRegistry.swift"),
    ("RPGEquipmentRegistry",  "Services/RPGEquipmentRegistry.swift"),
    ("RPGEquipmentService",   "Services/RPGEquipmentService.swift"),
    ("RPGSkillRegistry",      "Services/RPGSkillRegistry.swift"),
    ("SkillProgressionService", "Services/SkillProgressionService.swift"),
    ("EquipmentDropService",  "Services/EquipmentDropService.swift"),
    ("MonsterSpawnService",   "Services/MonsterSpawnService.swift"),
    ("BossMilestoneService",  "Services/BossMilestoneService.swift"),
    ("RPGEncounterViewModel", "Services/RPGEncounterViewModel.swift"),
    ("PerceivedEffortPicker", "Views/Components/PerceivedEffortPicker.swift"),
    ("RPGSpriteView",         "Views/Components/RPGSpriteView.swift"),
    ("RPGSceneView",          "Views/Components/RPGSceneView.swift"),
]

TEST_SOURCES = [
    ("TEST_Progression", "RepSetForgeTests/ProgressionServiceTests.swift"),
    ("TEST_Achievement", "RepSetForgeTests/AchievementServiceTests.swift"),
    ("TEST_Integration", "RepSetForgeTests/IntegrationTests.swift"),
    ("TEST_RPGSpawn",    "RepSetForgeTests/RPGSpawnServiceTests.swift"),
    ("TEST_RPGBoss",     "RepSetForgeTests/RPGBossMilestoneTests.swift"),
    ("TEST_ExerciseTemplate", "RepSetForgeTests/ExerciseTemplateServiceTests.swift"),
    ("TEST_QuestTemplate", "RepSetForgeTests/QuestTemplateServiceTests.swift"),
    ("TEST_QuestDuplication", "RepSetForgeTests/QuestDuplicationServiceTests.swift"),
    ("TEST_QuestScheduler", "RepSetForgeTests/QuestSchedulerTests.swift"),
    ("TEST_ProgressionRebuild", "RepSetForgeTests/ProgressionRebuildServiceTests.swift"),
    ("TEST_ExerciseType", "RepSetForgeTests/ExerciseTypeTests.swift"),
    ("TEST_PersonalRecord", "RepSetForgeTests/PersonalRecordServiceTests.swift"),
    ("TEST_WeightUnit", "RepSetForgeTests/WeightUnitTests.swift"),
    ("TEST_GoldService", "RepSetForgeTests/GoldServiceTests.swift"),
    ("TEST_RPGEquipment", "RepSetForgeTests/RPGEquipmentServiceTests.swift"),
    ("TEST_SkillProgression", "RepSetForgeTests/SkillProgressionServiceTests.swift"),
    ("TEST_EquipmentDrop", "RepSetForgeTests/EquipmentDropServiceTests.swift"),
    ("TEST_TrainingStyle", "RepSetForgeTests/TrainingStyleServiceTests.swift"),
    ("TEST_TrainingInsights", "RepSetForgeTests/TrainingInsightsServiceTests.swift"),
    ("TEST_SuggestedQuest", "RepSetForgeTests/SuggestedQuestServiceTests.swift"),
    ("TEST_QuestCalendar", "RepSetForgeTests/QuestCalendarServiceTests.swift"),
    ("TEST_TrainingCharts", "RepSetForgeTests/TrainingChartsServiceTests.swift"),
    ("TEST_MuscleRecovery", "RepSetForgeTests/MuscleRecoveryServiceTests.swift"),
    ("TEST_QuestFilter", "RepSetForgeTests/QuestFilterServiceTests.swift"),
    ("TEST_QuestJournal", "RepSetForgeTests/QuestJournalTests.swift"),
    ("TEST_RecoveryRecommendation", "RepSetForgeTests/RecoveryRecommendationServiceTests.swift"),
    ("TEST_ExerciseNameSuggestion", "RepSetForgeTests/ExerciseNameSuggestionServiceTests.swift"),
    ("TEST_ExerciseMetrics", "RepSetForgeTests/ExerciseMetricsServiceTests.swift"),
    ("TEST_ProgressExport", "RepSetForgeTests/ProgressExportServiceTests.swift"),
    ("TEST_ProgressImport", "RepSetForgeTests/ProgressImportServiceTests.swift"),
    ("TEST_HealthKitService", "RepSetForgeTests/HealthKitServiceTests.swift"),
    ("TEST_AppIntentService", "RepSetForgeTests/AppIntentServiceTests.swift"),
    ("TEST_PrivacyDataService", "RepSetForgeTests/PrivacyDataServiceTests.swift"),
    ("TEST_PersistenceMigration", "RepSetForgeTests/PersistenceMigrationTests.swift"),
    ("TEST_Fixtures", "RepSetForgeTests/FixturesTests.swift"),
    ("TEST_StreakService", "RepSetForgeTests/StreakServiceTests.swift"),
    ("TEST_LeaderboardService", "RepSetForgeTests/LeaderboardServiceTests.swift"),
]

UI_TEST_SOURCES = [
    ("UITEST_QuestLogging", "RepSetForgeUITests/QuestLoggingUITests.swift"),
]

def pbxproj():
    lines = []
    a = lines.append

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 77;")
    a("\tobjects = {")
    a("")

    # ── PBXBuildFile ────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXBuildFile section */")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    a(f"\t\t{BF['Assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FR['Assets']} /* Assets.xcassets */; }};")
    a(f"\t\t{BF['WatchAssets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FR['WatchAssets']} /* Assets.xcassets */; }};")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    for key, path in WATCH_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    app_sources_by_key = dict(APP_SOURCES)
    for key in WATCH_SHARED_KEYS:
        filename = app_sources_by_key[key].split("/")[-1]
        a(f"\t\t{BF_WATCH_SHARED[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    a(f"\t\t{BF_EMBED_WATCH} /* RepSetForge Watch App.app in Embed Watch Content */ = {{isa = PBXBuildFile; fileRef = {FR['PROD_WATCH']} /* RepSetForge Watch App.app */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    for key, path in WIDGET_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    for key in WIDGET_SHARED_KEYS:
        filename = app_sources_by_key[key].split("/")[-1]
        a(f"\t\t{BF_WIDGET_SHARED[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    a(f"\t\t{BF_EMBED_WIDGET} /* RepSetForgeWidgets.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {FR['PROD_WIDGET']} /* RepSetForgeWidgets.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    a("\t\t/* End PBXBuildFile section */")
    a("")

    # ── PBXContainerItemProxy ───────────────────────────────────────────────
    a("\t\t/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{CI_TEST} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_APP};")
    a(f"\t\t\tremoteInfo = RepSetForge;")
    a(f"\t\t}};")
    a(f"\t\t{CI_UITEST} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_APP};")
    a(f"\t\t\tremoteInfo = RepSetForge;")
    a(f"\t\t}};")
    a(f"\t\t{CI_WATCH} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_WATCH};")
    a(f"\t\t\tremoteInfo = \"RepSetForge Watch App\";")
    a(f"\t\t}};")
    a(f"\t\t{CI_WIDGET} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_WIDGET};")
    a(f"\t\t\tremoteInfo = RepSetForgeWidgets;")
    a(f"\t\t}};")
    a("\t\t/* End PBXContainerItemProxy section */")
    a("")

    # ── PBXFileReference ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXFileReference section */")
    a(f"\t\t{FR['PROD_APP']} /* RepSetForge.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RepSetForge.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_TEST']} /* RepSetForgeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RepSetForgeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RepSetForgeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_WATCH']} /* RepSetForge Watch App.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"RepSetForge Watch App.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_WIDGET']} /* RepSetForgeWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = wrapper.app-extension; includeInIndex = 0; path = RepSetForgeWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['Assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    for key, path in WATCH_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['WatchEntitlements']} /* RepSetForge Watch App.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"RepSetForge Watch App.entitlements\"; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['WatchAssets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    for key, path in WIDGET_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['WidgetEntitlements']} /* RepSetForgeWidgets.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = RepSetForgeWidgets.entitlements; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['WidgetInfoPlist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    a("\t\t/* End PBXFileReference section */")
    a("")

    # ── PBXFrameworksBuildPhase ─────────────────────────────────────────────
    a("\t\t/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{BP_APP_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_UITEST_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_TEST_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_WATCH_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_WIDGET_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXFrameworksBuildPhase section */")
    a("")

    # ── PBXCopyFilesBuildPhase ──────────────────────────────────────────────
    # "Embed Watch Content" on the iOS app target — bundles the watch app's
    # .app product inside RepSetForge.app so a single install carries both.
    a("\t\t/* Begin PBXCopyFilesBuildPhase section */")
    a(f"\t\t{BP_EMBED_WATCH} /* Embed Watch Content */ = {{")
    a(f"\t\t\tisa = PBXCopyFilesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tdstPath = \"$(CONTENTS_FOLDER_PATH)/Watch\";")
    a(f"\t\t\tdstSubfolderSpec = 16;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t\t{BF_EMBED_WATCH} /* RepSetForge Watch App.app in Embed Watch Content */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = \"Embed Watch Content\";")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_EMBED_WIDGET} /* Embed Foundation Extensions */ = {{")
    a(f"\t\t\tisa = PBXCopyFilesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tdstPath = \"\";")
    a(f"\t\t\tdstSubfolderSpec = 13;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t\t{BF_EMBED_WIDGET} /* RepSetForgeWidgets.appex in Embed Foundation Extensions */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = \"Embed Foundation Extensions\";")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXCopyFilesBuildPhase section */")
    a("")

    # ── PBXGroup ─────────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXGroup section */")

    # Root group
    a(f"\t\t{GR['Root']} = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{GR['RepSetForge']} /* RepSetForge */,")
    a(f"\t\t\t\t{GR['Tests']} /* RepSetForgeTests */,")
    a(f"\t\t\t\t{GR['UITests']} /* RepSetForgeUITests */,")
    a(f"\t\t\t\t{GR['WatchApp']} /* RepSetForge Watch App */,")
    a(f"\t\t\t\t{GR['WidgetApp']} /* RepSetForgeWidgets */,")
    a(f"\t\t\t\t{GR['Products']} /* Products */,")
    a(f"\t\t\t);")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # Products group
    a(f"\t\t{GR['Products']} /* Products */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['PROD_APP']} /* RepSetForge.app */,")
    a(f"\t\t\t\t{FR['PROD_TEST']} /* RepSetForgeTests.xctest */,")
    a(f"\t\t\t\t{FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */,")
    a(f"\t\t\t\t{FR['PROD_WATCH']} /* RepSetForge Watch App.app */,")
    a(f"\t\t\t\t{FR['PROD_WIDGET']} /* RepSetForgeWidgets.appex */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = Products;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # RepSetForge group (main app folder)
    a(f"\t\t{GR['RepSetForge']} /* RepSetForge */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['RepSetForgeApp']} /* RepSetForgeApp.swift */,")
    a(f"\t\t\t\t{FR['ContentView']} /* ContentView.swift */,")
    a(f"\t\t\t\t{FR['RepSetForgeTheme']} /* RepSetForgeTheme.swift */,")
    a(f"\t\t\t\t{GR['Models']} /* Models */,")
    a(f"\t\t\t\t{GR['Services']} /* Services */,")
    a(f"\t\t\t\t{GR['Persistence']} /* Persistence */,")
    a(f"\t\t\t\t{GR['Views']} /* Views */,")
    a(f"\t\t\t\t{GR['Testing']} /* Testing */,")
    a(f"\t\t\t\t{FR['Assets']} /* Assets.xcassets */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForge;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    def simple_group(grp_key, grp_path, file_keys):
        a(f"\t\t{GR[grp_key]} /* {grp_key} */ = {{")
        a(f"\t\t\tisa = PBXGroup;")
        a(f"\t\t\tchildren = (")
        for fk in file_keys:
            fn = FR[fk]
            filename = dict(APP_SOURCES)[fk].split("/")[-1]
            a(f"\t\t\t\t{fn} /* {filename} */,")
        a(f"\t\t\t);")
        a(f"\t\t\tpath = {grp_path};")
        a(f"\t\t\tsourceTree = \"<group>\";")
        a(f"\t\t}};")

    simple_group("Models", "Models", ["MuscleGroup", "WeightUnit", "QuestStatus", "ExerciseType", "ExerciseSet", "Exercise", "ExerciseTemplate", "Quest", "QuestTemplate", "PlayerCharacter", "MuscleProgress", "Achievement", "PersonalRecordType", "PersonalRecord", "TrainingStyle",
                                       "RPGClass", "RPGEquipment", "OwnedEquipment", "RPGSkill", "SkillProgress", "RPGMonster", "RPGBoss", "RPGProgressionSnapshot", "RPGEncounterState"])
    simple_group("Services", "Services", ["ProgressionService", "AchievementService", "ExerciseTemplateService", "QuestTemplateService", "QuestDuplicationService", "QuestScheduler", "ProgressionRebuildService", "PersonalRecordService", "GoldService", "TrainingStyleService", "TrainingInsightsService", "SuggestedQuestService", "QuestCalendarService", "TrainingChartsService", "MuscleRecoveryService", "QuestFilterService", "RecoveryRecommendationService", "ExerciseNameSuggestionService", "ExerciseMetricsService", "ProgressExportService", "ProgressImportService", "HealthKitService", "AppIntentService", "RepSetForgeShortcuts", "PrivacyDataService", "StreakService", "RepSetForgeActivityAttributes", "LiveActivityService", "LeaderboardService",
                                           "RPGMonsterRegistry", "RPGBossRegistry", "RPGEquipmentRegistry", "RPGEquipmentService", "RPGSkillRegistry", "SkillProgressionService", "EquipmentDropService",
                                           "MonsterSpawnService", "BossMilestoneService", "RPGEncounterViewModel"])
    simple_group("Persistence", "Persistence", ["PersistenceController", "RepSetForgeSchema", "SharedStore"])
    simple_group("Testing", "Testing", ["Fixtures"])

    # Views group
    a(f"\t\t{GR['Views']} /* Views */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key in ["OnboardingView", "EquipmentShopView", "QuestDashboardView", "QuestListView", "QuestDetailView", "ExerciseLoggingView",
                "CharacterProgressView", "QuestHistoryView", "AchievementsView", "QuestCompletionView", "QuestCalendarView", "TrainingChartsView", "ExerciseMetricsView", "LeaderboardView"]:
        filename = dict(APP_SOURCES)[key].split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t\t{GR['Components']} /* Components */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = Views;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    simple_group("Components", "Components", ["PixelQuestCard", "PixelXPBar", "PixelBadge", "PixelStatPanel",
                                               "PixelButton", "PixelAchievementCard", "PixelDivider", "QuestCompletionRewardRow",
                                               "PerceivedEffortPicker", "RPGSpriteView", "RPGSceneView"])

    # Tests group
    a(f"\t\t{GR['Tests']} /* RepSetForgeTests */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForgeTests;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # UITests group
    a(f"\t\t{GR['UITests']} /* RepSetForgeUITests */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForgeUITests;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # WatchApp group
    a(f"\t\t{GR['WatchApp']} /* RepSetForge Watch App */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in WATCH_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t\t{FR['WatchEntitlements']} /* RepSetForge Watch App.entitlements */,")
    a(f"\t\t\t\t{FR['WatchAssets']} /* Assets.xcassets */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = \"RepSetForge Watch App\";")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # WidgetApp group
    a(f"\t\t{GR['WidgetApp']} /* RepSetForgeWidgets */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in WIDGET_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t\t{FR['WidgetEntitlements']} /* RepSetForgeWidgets.entitlements */,")
    a(f"\t\t\t\t{FR['WidgetInfoPlist']} /* Info.plist */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForgeWidgets;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a("\t\t/* End PBXGroup section */")
    a("")

    # ── PBXNativeTarget ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXNativeTarget section */")
    a(f"\t\t{TG_APP} /* RepSetForge */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_APP} /* Build configuration list for PBXNativeTarget \"RepSetForge\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_APP_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_APP_FRM} /* Frameworks */,")
    a(f"\t\t\t\t{BP_APP_RES} /* Resources */,")
    a(f"\t\t\t\t{BP_EMBED_WATCH} /* Embed Watch Content */,")
    a(f"\t\t\t\t{BP_EMBED_WIDGET} /* Embed Foundation Extensions */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_WATCH} /* PBXTargetDependency */,")
    a(f"\t\t\t\t{TD_WIDGET} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForge;")
    a(f"\t\t\tproductName = RepSetForge;")
    a(f"\t\t\tproductReference = {FR['PROD_APP']} /* RepSetForge.app */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_TEST} /* RepSetForgeTests */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_TEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeTests\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_TEST_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_TEST_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_TEST} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForgeTests;")
    a(f"\t\t\tproductName = RepSetForgeTests;")
    a(f"\t\t\tproductReference = {FR['PROD_TEST']} /* RepSetForgeTests.xctest */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_UITEST} /* RepSetForgeUITests */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_UITEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeUITests\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_UITEST_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_UITEST_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_UITEST} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForgeUITests;")
    a(f"\t\t\tproductName = RepSetForgeUITests;")
    a(f"\t\t\tproductReference = {FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_WATCH} /* RepSetForge Watch App */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_WATCH} /* Build configuration list for PBXNativeTarget \"RepSetForge Watch App\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_WATCH_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_WATCH_FRM} /* Frameworks */,")
    a(f"\t\t\t\t{BP_WATCH_RES} /* Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t);")
    a(f"\t\t\tname = \"RepSetForge Watch App\";")
    a(f"\t\t\tproductName = \"RepSetForge Watch App\";")
    a(f"\t\t\tproductReference = {FR['PROD_WATCH']} /* RepSetForge Watch App.app */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_WIDGET} /* RepSetForgeWidgets */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_WIDGET} /* Build configuration list for PBXNativeTarget \"RepSetForgeWidgets\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_WIDGET_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_WIDGET_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForgeWidgets;")
    a(f"\t\t\tproductName = RepSetForgeWidgets;")
    a(f"\t\t\tproductReference = {FR['PROD_WIDGET']} /* RepSetForgeWidgets.appex */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.app-extension\";")
    a(f"\t\t}};")
    a("\t\t/* End PBXNativeTarget section */")
    a("")

    # ── PBXProject ─────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXProject section */")
    a(f"\t\t{PROJECT} /* Project object */ = {{")
    a(f"\t\t\tisa = PBXProject;")
    a(f"\t\t\tattributes = {{")
    a(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a(f"\t\t\t\tLastSwiftUpdateCheck = 1600;")
    a(f"\t\t\t\tLastUpgradeCheck = 1600;")
    a(f"\t\t\t\tTargetAttributes = {{")
    a(f"\t\t\t\t\t{TG_APP} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_TEST} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t\tTestTargetID = {TG_APP};")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_UITEST} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t\tTestTargetID = {TG_APP};")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_WATCH} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_WIDGET} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t}};")
    a(f"\t\t\t}};")
    a(f"\t\t\tbuildConfigurationList = {CL_PROJECT} /* Build configuration list for PBXProject \"RepSetForge\" */;")
    a(f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a(f"\t\t\tdevelopmentRegion = en;")
    a(f"\t\t\thasScannedForEncodings = 0;")
    a(f"\t\t\tknownRegions = (")
    a(f"\t\t\t\ten,")
    a(f"\t\t\t\tBase,")
    a(f"\t\t\t);")
    a(f"\t\t\tmainGroup = {GR['Root']};")
    a(f"\t\t\tproductRefGroup = {GR['Products']} /* Products */;")
    a(f"\t\t\tprojectDirPath = \"\";")
    a(f"\t\t\tprojectRoot = \"\";")
    a(f"\t\t\ttargets = (")
    a(f"\t\t\t\t{TG_APP} /* RepSetForge */,")
    a(f"\t\t\t\t{TG_TEST} /* RepSetForgeTests */,")
    a(f"\t\t\t\t{TG_UITEST} /* RepSetForgeUITests */,")
    a(f"\t\t\t\t{TG_WATCH} /* RepSetForge Watch App */,")
    a(f"\t\t\t\t{TG_WIDGET} /* RepSetForgeWidgets */,")
    a(f"\t\t\t);")
    a(f"\t\t}};")
    a("\t\t/* End PBXProject section */")
    a("")

    # ── PBXResourcesBuildPhase ──────────────────────────────────────────────
    a("\t\t/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{BP_APP_RES} /* Resources */ = {{")
    a(f"\t\t\tisa = PBXResourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t\t{BF['Assets']} /* Assets.xcassets in Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_WATCH_RES} /* Resources */ = {{")
    a(f"\t\t\tisa = PBXResourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t\t{BF['WatchAssets']} /* Assets.xcassets in Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXResourcesBuildPhase section */")
    a("")

    # ── PBXSourcesBuildPhase ────────────────────────────────────────────────
    a("\t\t/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{BP_APP_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_TEST_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_UITEST_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_WATCH_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in WATCH_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    for key in WATCH_SHARED_KEYS:
        filename = app_sources_by_key[key].split("/")[-1]
        a(f"\t\t\t\t{BF_WATCH_SHARED[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_WIDGET_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in WIDGET_APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    for key in WIDGET_SHARED_KEYS:
        filename = app_sources_by_key[key].split("/")[-1]
        a(f"\t\t\t\t{BF_WIDGET_SHARED[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXSourcesBuildPhase section */")
    a("")

    # ── PBXTargetDependency ─────────────────────────────────────────────────
    a("\t\t/* Begin PBXTargetDependency section */")
    a(f"\t\t{TD_TEST} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_APP} /* RepSetForge */;")
    a(f"\t\t\ttargetProxy = {CI_TEST} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a(f"\t\t{TD_UITEST} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_APP} /* RepSetForge */;")
    a(f"\t\t\ttargetProxy = {CI_UITEST} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a(f"\t\t{TD_WATCH} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_WATCH} /* RepSetForge Watch App */;")
    a(f"\t\t\ttargetProxy = {CI_WATCH} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a(f"\t\t{TD_WIDGET} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_WIDGET} /* RepSetForgeWidgets */;")
    a(f"\t\t\ttargetProxy = {CI_WIDGET} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a("\t\t/* End PBXTargetDependency section */")
    a("")

    # ── XCBuildConfiguration ────────────────────────────────────────────────
    a("\t\t/* Begin XCBuildConfiguration section */")

    def project_config(uuid, name):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        a(f"\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        a(f"\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
        a(f"\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
        a(f"\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        a(f"\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        a(f"\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
        a(f"\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
        a(f"\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_COMMA = YES;")
        a(f"\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
        a(f"\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
        a(f"\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
        a(f"\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
        a(f"\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;")
        a(f"\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
        a(f"\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
        a(f"\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
        a(f"\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
        a(f"\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
        a(f"\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
        a(f"\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
        a(f"\t\t\t\tCOPY_PHASE_STRIP = NO;")
        debug_only = name == "Debug"
        a(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = {'dwarf' if debug_only else 'dwarf-with-dsym'};")
        a(f"\t\t\t\tENABLE_NS_ASSERTIONS = {'YES' if debug_only else 'NO'};")
        a(f"\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        a(f"\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
        a(f"\t\t\t\tGCC_DYNAMIC_NO_PIC = {'NO' if debug_only else 'YES'};")
        a(f"\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
        a(f"\t\t\t\tGCC_OPTIMIZATION_LEVEL = {'0' if debug_only else 's'};")
        a(f"\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
        if debug_only:
            a(f"\t\t\t\t\t\"DEBUG=1\",")
        a(f"\t\t\t\t\t\"$(inherited)\",")
        a(f"\t\t\t\t);")
        a(f"\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
        a(f"\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
        a(f"\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
        a(f"\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
        a(f"\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
        a(f"\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = {'INCLUDE_SOURCE' if debug_only else 'NO'};")
        a(f"\t\t\t\tMTL_FAST_MATH = YES;")
        a(f"\t\t\t\tONLY_ACTIVE_ARCH = {'YES' if debug_only else 'NO'};")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        if debug_only:
            a(f"\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
            a(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            a(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    project_config(BC_PROJ_DBG, "Debug")
    project_config(BC_PROJ_REL, "Release")

    def app_config(uuid, name):
        debug = name == "Debug"
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        a(f"\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
        a(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = RepSetForge/RepSetForge.entitlements;")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        if debug:
            a(f"\t\t\t\tENABLE_TESTABILITY = YES;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = RepSetForge;")
        a(f"\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;")
        a(f"\t\t\t\tINFOPLIST_KEY_NSHealthShareUsageDescription = \"RepSetForge reads your workout, heart rate, and body metric history from Health to keep your quest log complete.\";")
        a(f"\t\t\t\tINFOPLIST_KEY_NSHealthUpdateUsageDescription = \"RepSetForge saves completed quests to Health as workouts so they show up alongside your other activity.\";")
        a(f"\t\t\t\tINFOPLIST_KEY_NSSupportsLiveActivities = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown\";")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait\";")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    app_config(BC_APP_DBG, "Debug")
    app_config(BC_APP_REL, "Release")

    def test_config(uuid, name):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForgeTests;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/RepSetForge.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RepSetForge\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    test_config(BC_TEST_DBG, "Debug")
    test_config(BC_TEST_REL, "Release")

    def uitest_config(uuid, name):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForgeUITests;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t\tTEST_TARGET_NAME = RepSetForge;")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    uitest_config(BC_UITEST_DBG, "Debug")
    uitest_config(BC_UITEST_REL, "Release")

    def watch_config(uuid, name):
        debug = name == "Debug"
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        a(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"RepSetForge Watch App/RepSetForge Watch App.entitlements\";")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        if debug:
            a(f"\t\t\t\tENABLE_TESTABILITY = YES;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = RepSetForge;")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = \"UIInterfaceOrientationPortrait\";")
        a(f"\t\t\t\tINFOPLIST_KEY_WKCompanionAppBundleIdentifier = dev.gnwn.RepSetForge;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge.watchkitapp;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = watchos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"watchsimulator watchos\";")
        a(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = 4;")
        a(f"\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    watch_config(BC_WATCH_DBG, "Debug")
    watch_config(BC_WATCH_REL, "Release")

    def widget_config(uuid, name):
        debug = name == "Debug"
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = RepSetForgeWidgets/RepSetForgeWidgets.entitlements;")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        if debug:
            a(f"\t\t\t\tENABLE_TESTABILITY = YES;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        a(f"\t\t\t\tINFOPLIST_FILE = RepSetForgeWidgets/Info.plist;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge.RepSetForgeWidgets;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSKIP_INSTALL = YES;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    widget_config(BC_WIDGET_DBG, "Debug")
    widget_config(BC_WIDGET_REL, "Release")

    a("\t\t/* End XCBuildConfiguration section */")
    a("")

    # ── XCConfigurationList ─────────────────────────────────────────────────
    a("\t\t/* Begin XCConfigurationList section */")
    a(f"\t\t{CL_PROJECT} /* Build configuration list for PBXProject \"RepSetForge\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_PROJ_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_PROJ_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_APP} /* Build configuration list for PBXNativeTarget \"RepSetForge\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_APP_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_APP_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_TEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeTests\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_TEST_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_TEST_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_UITEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeUITests\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_UITEST_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_UITEST_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_WATCH} /* Build configuration list for PBXNativeTarget \"RepSetForge Watch App\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_WATCH_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_WATCH_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_WIDGET} /* Build configuration list for PBXNativeTarget \"RepSetForgeWidgets\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_WIDGET_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_WIDGET_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a("\t\t/* End XCConfigurationList section */")
    a("")

    a("\t};")
    a(f"\trootObject = {PROJECT} /* Project object */;")
    a("}")

    return "\n".join(lines)


if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    proj_dir = os.path.join(base, "RepSetForge.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
    content = pbxproj()
    with open(pbxproj_path, "w") as f:
        f.write(content)
    print(f"Generated: {pbxproj_path}")
    print(f"Lines: {len(content.splitlines())}")
